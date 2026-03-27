import os
import cv2
import json
import time
import base64
import paho.mqtt.client as mqtt
from ultralytics import YOLO
from lettu_backend.core.config import settings

# =====================================================
#  Load AI Config (from config.py in this package)
# =====================================================
from lettu_vault_ai import config as ai_cfg

# Resolve MQTT settings: config.py overrides take priority, else use .env
MQTT_BROKER = ai_cfg.MQTT_BROKER_OVERRIDE if ai_cfg.MQTT_BROKER_OVERRIDE else settings.MQTT_BROKER
MQTT_PORT   = ai_cfg.MQTT_PORT_OVERRIDE   if ai_cfg.MQTT_PORT_OVERRIDE   else settings.MQTT_PORT
MQTT_TOPIC  = settings.MQTT_TOPIC_AI

# =====================================================
#  MQTT Client Setup
# =====================================================
mqtt_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
PRODUCE_SCAN_REQUESTED = True  # Start true for initial startup check
scan_start_time = time.time()  # Initialize globally

def on_message(client, userdata, msg):
    global PRODUCE_SCAN_REQUESTED, scan_start_time
    try:
        command = msg.payload.decode()
        if command == "TRIGGER_PRODUCE_SCAN":
            print("🚀 [AI] MQTT Command Received: Triggering Produce Scan...")
            PRODUCE_SCAN_REQUESTED = True
            scan_start_time = time.time() # Reset timeout clock
    except Exception as e:
        print(f"❌ [AI] Error processing MQTT command: {e}")

mqtt_client.on_message = on_message

def connect_mqtt():
    print(f"[AI] Attempting to connect to MQTT broker at {MQTT_BROKER}:{MQTT_PORT}")
    while True:
        try:
            mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
            mqtt_client.subscribe("lettuvault/control")
            mqtt_client.loop_start()
            print(f"[AI] Successfully connected to MQTT broker & subscribed to control")
            return True
        except Exception as e:
            print(f"[AI] Connection failed ({e}), retrying in 5s...")
            time.sleep(5)

if not connect_mqtt():
    print("[AI] Could not connect to MQTT Broker. Is it running?")

# =====================================================
#  Send Detection Results
# =====================================================
# =====================================================
#  Send Detection Results
# =====================================================
def send_results_to_backend(summary, confidence, frame, scan_type="condition"):
    """Publishes detection data to MQTT with routing metadata."""
    summary_str = ", ".join([f"{v} {k}" for k, v in summary.items() if v > 0])
    
    # Identify specific produce if this is a produce scan
    produce_type = None
    if scan_type == "produce":
        if summary.get("lettuce", 0) > 0: produce_type = "Lettuce"
        elif summary.get("strawberry", 0) > 0: produce_type = "Strawberry"
        else: produce_type = "Empty / Unknown"

    # Encode frame
    image_b64 = None
    try:
        _, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
        image_b64 = base64.b64encode(buffer).decode('utf-8')
    except Exception as e:
        print(f"⚠️ [AI] Could not encode snapshot: {e}")

    payload = {
        "api_key": settings.X_API_KEY,
        "scan_type": scan_type,
        "worm_count": summary.get("worms", 0),
        "confidence_score": float(confidence),
        "image_b64": image_b64,
        "label": summary_str if summary_str else "No Detections",
        "produce_type": produce_type
    }
    try:
        mqtt_client.publish(MQTT_TOPIC, json.dumps(payload))
        print(f"📤 [PUBLISHER] ({scan_type.upper()}) Detected: {summary_str or 'Nothing'}")
    except Exception as e:
        print(f"❌ [AI] MQTT Publish Error: {e}")

# =====================================================
#  Camera Connection Helper
# =====================================================
CAMERA_MAX_RETRIES = 6         # Try up to 6 times (= ~1 minute of total waiting)
CAMERA_RETRY_INTERVAL = 10    # Seconds between retries

def _open_camera():
    """Attempts to open the camera with retry logic. Returns a cv2.VideoCapture or None."""
    for attempt in range(1, CAMERA_MAX_RETRIES + 1):
        cap = cv2.VideoCapture(ai_cfg.CAMERA_INDEX)
        cap.set(cv2.CAP_PROP_FRAME_WIDTH,  ai_cfg.CAMERA_WIDTH)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, ai_cfg.CAMERA_HEIGHT)

        if cap.isOpened():
            return cap

        cap.release()
        if attempt < CAMERA_MAX_RETRIES:
            print(f"⚠️ [AI] Could not open camera {ai_cfg.CAMERA_INDEX} (Attempt {attempt}/{CAMERA_MAX_RETRIES}). Retrying in {CAMERA_RETRY_INTERVAL}s...")
            time.sleep(CAMERA_RETRY_INTERVAL)
        else:
            print(f"❌ [AI] Failed to open camera after {CAMERA_MAX_RETRIES} attempts. Giving up.")
    return None

# =====================================================
#  Main Camera Loop
# =====================================================
def run_live_camera():
    global PRODUCE_SCAN_REQUESTED, scan_start_time
    # --- Resolve Model Path ---
    if ai_cfg.MODEL_PATH and os.path.exists(ai_cfg.MODEL_PATH):
        model_path = ai_cfg.MODEL_PATH
    else:
        from lettu_backend.core.config import PROJECT_ROOT
        model_path = os.path.join(PROJECT_ROOT, 'ai_system', 'runs', 'lettuce_strawberry_v112', 'weights', 'best.pt')

        if not os.path.exists(model_path):
            model_path = os.path.join(PROJECT_ROOT, 'yolov8n.pt')
            print(f"[AI] Custom model not found, falling back to: {model_path}")

        if not os.path.exists(model_path):
            print(f"[AI] Error: No model found. Set MODEL_PATH in ai_system/src/lettu_vault_ai/config.py")
            return

    # --- Camera & Model Initialization ---
    print(f"[AI] Loading model: {model_path}")
    model = YOLO(model_path)
    cap = _open_camera()
    if cap is None:
        return

    print(f"[AI] Camera is LIVE. Press 'q' to quit.")

    # --- Continuous Monitor State (Worms/Wilting) ---
    continuous_classes = ["worms", "wilting"]
    produce_classes    = ["lettuce", "strawberry"]
    
    # Stability Trackers
    cont_start_time = None
    cont_last_time  = 0
    cont_sent       = False

    prod_start_time = None
    prod_last_time  = 0
    last_publish_time = 0 # Produce cooldown
    last_cont_publish_time = 0 # Condition cooldown

    consecutive_failures = 0
    while True:
        success, frame = cap.read()
        if not success:
            consecutive_failures += 1
            if consecutive_failures >= 30:
                print(f"⚠️ [AI] Camera read failed {consecutive_failures} times. Attempting to reconnect...")
                cap.release()
                cap = _open_camera()
                if cap is None:
                    return
                consecutive_failures = 0
                print(f"✅ [AI] Camera reconnected successfully.")
            continue
        consecutive_failures = 0

        results = list(model.predict(source=frame, conf=ai_cfg.CONFIDENCE_THRESHOLD, show=False, stream=True, verbose=False))
        annotated_frame = frame.copy()
        
        # 1. 🔍 PROCESS MONITORS
        continuous_summary = {cls: 0 for cls in continuous_classes}
        max_conf_cont = 0.0
        found_cont = False

        produce_summary = {cls: 0 for cls in produce_classes}
        max_conf_prod = 0.0
        found_prod = False

        for r in results:
            annotated_frame = r.plot()
            for box in r.boxes:
                cls_name = model.names[int(box.cls[0])]
                conf = float(box.conf[0])
                
                if cls_name in continuous_classes:
                    continuous_summary[cls_name] += 1
                    found_cont = True
                    if conf > max_conf_cont: max_conf_cont = conf
                
                if PRODUCE_SCAN_REQUESTED and cls_name in produce_classes:
                    produce_summary[cls_name] += 1
                    found_prod = True
                    if conf > max_conf_prod: max_conf_prod = conf

        if ai_cfg.SHOW_CAMERA_WINDOW:
            cv2.imshow(ai_cfg.CAMERA_WINDOW_TITLE, annotated_frame)

        current_time = time.time()

        # --- Continuous Logic (Worms/Wilting) ---
        if found_cont:
            cont_last_time = current_time
            if cont_start_time is None: cont_start_time = current_time
            
            duration = current_time - cont_start_time
            if duration >= ai_cfg.STABILITY_SECONDS and not cont_sent and (current_time - last_cont_publish_time > 5):
                print(f"🪱 [AI] Continuous Stability Met. Sending {continuous_summary}")
                
                # Lock immediately
                cont_sent = True 
                last_cont_publish_time = current_time
                
                send_results_to_backend(continuous_summary, max_conf_cont, annotated_frame, scan_type="condition")
        else:
            if cont_start_time and (current_time - cont_last_time > ai_cfg.GRACE_PERIOD_SECONDS):
                cont_start_time = None
                cont_sent = False

        # --- One-Time Produce Logic (Lettuce/Strawberry) with 3s Rule ---
        if PRODUCE_SCAN_REQUESTED:
            if found_prod:
                prod_last_time = current_time
                if prod_start_time is None: 
                    prod_start_time = current_time
                    print(f"🥗 [AI] Produce detected! Waiting for stability ({ai_cfg.STABILITY_SECONDS}s)...")
                
                duration = current_time - prod_start_time
                if duration >= ai_cfg.STABILITY_SECONDS and (current_time - last_publish_time > 5):
                    print(f"✅ [AI] Produce Stability Reached. Saving to Database: {produce_summary}")
                    
                    # Update cooldown FIRST
                    last_publish_time = current_time
                    
                    # LOCK IMMEDIATELY before sending
                    PRODUCE_SCAN_REQUESTED = False 
                    prod_start_time = None
                    
                    send_results_to_backend(produce_summary, max_conf_prod, annotated_frame, scan_type="produce")
                    print("💤 [AI] Produce scan complete. Going to sleep until next trigger.")
            else:
                # Reset stability timer if lost during the 3-second window
                if prod_start_time and (current_time - prod_last_time > ai_cfg.GRACE_PERIOD_SECONDS):
                    print(f"🥗 [AI] Produce lost. Searching again...")
                    prod_start_time = None
                
                # Pulse a log every 30 seconds to show we are still searching
                if int(current_time) % 30 == 0 and int(current_time - 1) % 30 != 0:
                    print("🔍 [AI] Still searching for produce inside the Hub...")

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()
    print("[AI] Camera closed.")

if __name__ == "__main__":
    run_live_camera()
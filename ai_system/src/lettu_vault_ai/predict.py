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
TEST_CAPTURE_REQUESTED = False
scan_start_time = time.time()  # Initialize globally

def on_message(client, userdata, msg):
    global PRODUCE_SCAN_REQUESTED, TEST_CAPTURE_REQUESTED, scan_start_time
    try:
        command = msg.payload.decode()
        if command == "TRIGGER_PRODUCE_SCAN":
            print("🚀 [AI] MQTT Command Received: Triggering Produce Scan...")
            PRODUCE_SCAN_REQUESTED = True
            scan_start_time = time.time() # Reset timeout clock
        elif command == "FORCE_TEST_CAPTURE":
            print("📸 [AI] MQTT Command Received: Forcing Test Capture...")
            TEST_CAPTURE_REQUESTED = True
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
#  Status Reporting
# =====================================================
def send_status_to_backend(message: str):
    """Publishes a plain text status message to the status topic."""
    try:
        payload = {
            "api_key": settings.X_API_KEY,
            "status": message
        }
        mqtt_client.publish("lettuvault/status", json.dumps(payload))
    except Exception as e:
        print(f"⚠️ [AI] Could not send status: {e}")

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
    """Attempts to find and open a working camera source with auto-discovery."""
    # Determine which indices to try. 
    indices_to_try = [ai_cfg.CAMERA_INDEX]
    
    # Only add fallbacks if explicitly allowed in config.py
    if getattr(ai_cfg, "ALLOW_CAMERA_FALLBACK", True):
        if isinstance(ai_cfg.CAMERA_INDEX, int):
            indices_to_try += [i for i in range(5) if i != ai_cfg.CAMERA_INDEX]
        else:
            indices_to_try += [0, 1, 2, 3, 4]
    else:
        print(f"⚠️ [AI] Strict Mode: Only attempting configured camera index {ai_cfg.CAMERA_INDEX}")

    # Backend selection: DSHOW is significantly more stable on Windows for webcams
    backend = cv2.CAP_DSHOW if os.name == 'nt' else cv2.CAP_ANY

    for attempt in range(1, CAMERA_MAX_RETRIES + 1):
        for idx in indices_to_try:
            print(f"🔍 [AI] Probing camera source: {idx} (Backend: {'DSHOW' if backend == cv2.CAP_DSHOW else 'DEFAULT'})...")
            cap = cv2.VideoCapture(idx, backend)
            
            # Check if camera opened AND can actually read a frame
            if cap.isOpened():
                success, _ = cap.read()
                if success:
                    cap.set(cv2.CAP_PROP_FRAME_WIDTH,  ai_cfg.CAMERA_WIDTH)
                    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, ai_cfg.CAMERA_HEIGHT)
                    # Limit buffer size to get fresh frames
                    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
                    
                    # Log the success clearly
                    print(f"✅ [AI] LOCKED onto camera at index {idx}!")
                    send_status_to_backend(f"✅ AI locked onto camera at index {idx}")
                    if idx != ai_cfg.CAMERA_INDEX:
                        print(f"💡 [AI] Note: Configured index {ai_cfg.CAMERA_INDEX} failed or was skipped. Found working camera at {idx}.")
                    return cap
            
            cap.release()

        if attempt < CAMERA_MAX_RETRIES:
            print(f"⚠️ [AI] Could not find ANY working camera (Attempt {attempt}/{CAMERA_MAX_RETRIES}). Retrying in {CAMERA_RETRY_INTERVAL}s...")
            send_status_to_backend(f"⚠️ AI camera probe failed (Attempt {attempt}/{CAMERA_MAX_RETRIES}). Retrying...")
            time.sleep(CAMERA_RETRY_INTERVAL)
        else:
            print(f"❌ [AI] Failed to find a camera after {CAMERA_MAX_RETRIES} attempts. Giving up.")
            send_status_to_backend(f"❌ AI failed to find any working camera after {CAMERA_MAX_RETRIES} attempts.")
            
    return None

# =====================================================
#  Main Camera Loop
# =====================================================
def run_live_camera():
    global PRODUCE_SCAN_REQUESTED, TEST_CAPTURE_REQUESTED, scan_start_time
    # --- Resolve Model Path ---
    if ai_cfg.MODEL_PATH and os.path.exists(ai_cfg.MODEL_PATH):
        model_path = ai_cfg.MODEL_PATH
    else:
        from lettu_backend.core.config import PROJECT_ROOT
        model_path = os.path.join(PROJECT_ROOT, 'ai_system', 'runs', 'lettuce_strawberry_v116', 'weights', 'best.pt')

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
    actual_fps = 0.0
    last_fps_time = time.time()
    
    while True:
        loop_start_time = time.time()
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

        # Filter detections to only the classes we actually want to track
        # This prevents unwanted classes (like strawberry) from being detected or shown
        target_indices = [i for i, name in model.names.items() if name in (produce_classes + continuous_classes)]
        
        results = list(model.predict(
            source=frame, 
            conf=ai_cfg.CONFIDENCE_THRESHOLD, 
            classes=target_indices,
            show=False, 
            stream=True, 
            verbose=False
        ))
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
            cv2.putText(annotated_frame, f"FPS: {actual_fps:.1f}", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
            cv2.imshow(ai_cfg.CAMERA_WINDOW_TITLE, annotated_frame)
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break

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

        # --- Manual Test Capture ---
        if TEST_CAPTURE_REQUESTED:
            print("📸 [AI] Taking Force Snapshot for Testing...")
            TEST_CAPTURE_REQUESTED = False
            send_results_to_backend({"Camera Test": 1}, 1.0, annotated_frame, scan_type="produce")


        # --- Enforce FPS Target & Calculate Actual FPS ---
        if hasattr(ai_cfg, 'TARGET_FPS') and ai_cfg.TARGET_FPS > 0:
            elapsed_loop_time = time.time() - loop_start_time
            sleep_time = (1.0 / ai_cfg.TARGET_FPS) - elapsed_loop_time
            if sleep_time > 0:
                time.sleep(sleep_time)
                
        # Calculate actual FPS for display
        curr_time = time.time()
        actual_fps = 1.0 / (curr_time - last_fps_time) if (curr_time - last_fps_time) > 0 else 0
        last_fps_time = curr_time

    cap.release()
    cv2.destroyAllWindows()
    print("[AI] Camera closed.")

if __name__ == "__main__":
    run_live_camera()
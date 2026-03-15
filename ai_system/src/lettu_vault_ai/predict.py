import os
import cv2
import json
import time
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

def connect_mqtt():
    print(f"[AI] Attempting to connect to MQTT broker at {MQTT_BROKER}:{MQTT_PORT}")
    while True:
        try:
            mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
            mqtt_client.loop_start()
            print(f"[AI] Successfully connected to MQTT broker")
            return True
        except Exception as e:
            print(f"[AI] Connection failed ({e}), retrying in 5s...")
            time.sleep(5)

if not connect_mqtt():
    print("[AI] Could not connect to MQTT Broker. Is it running?")

# =====================================================
#  Send Detection Results
# =====================================================
def send_results_to_backend(summary, confidence, image_name="camera_feed.jpg"):
    """Publishes detection data to the MQTT broker."""
    summary_str = ", ".join([f"{v} {k}" for k, v in summary.items() if v > 0])
    payload = {
        "api_key": settings.X_API_KEY,
        "worm_count": summary.get("worms", 0),
        "confidence_score": float(confidence),
        "image_name": image_name,
        "label": summary_str if summary_str else "No Detections"
    }
    try:
        mqtt_client.publish(MQTT_TOPIC, json.dumps(payload))
        print(f"📤 [PUBLISHER] Detection Results: {summary_str}")
    except Exception as e:
        print(f"❌ [AI] MQTT Publish Error: {e}")

# =====================================================
#  Main Camera Loop
# =====================================================
def run_live_camera():
    # --- Resolve Model Path ---
    if ai_cfg.MODEL_PATH and os.path.exists(ai_cfg.MODEL_PATH):
        model_path = ai_cfg.MODEL_PATH
    else:
        package_dir   = os.path.dirname(os.path.abspath(__file__))
        ai_system_dir = os.path.dirname(os.path.dirname(package_dir))
        model_path    = os.path.join(ai_system_dir, 'runs', 'lettuce_strawberry_v12', 'weights', 'best.pt')

        if not os.path.exists(model_path):
            model_path = os.path.join(ai_system_dir, 'yolov8n.pt')
            print(f"[AI] Custom model not found, falling back to: {model_path}")

        if not os.path.exists(model_path):
            root_dir   = os.path.dirname(ai_system_dir)
            model_path = os.path.join(root_dir, 'yolov8n.pt')
            if not os.path.exists(model_path):
                print(f"[AI] Error: No model found. Set MODEL_PATH in ai_system/src/lettu_vault_ai/config.py")
                return

    print(f"[AI] Loading model: {model_path}")
    model = YOLO(model_path)

    # --- Open Camera ---
    print(f"[AI] Opening camera index: {ai_cfg.CAMERA_INDEX}")
    cap = cv2.VideoCapture(ai_cfg.CAMERA_INDEX)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH,  ai_cfg.CAMERA_WIDTH)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, ai_cfg.CAMERA_HEIGHT)

    if not cap.isOpened():
        print(f"[AI] Error: Could not open camera {ai_cfg.CAMERA_INDEX}.")
        print("[AI] Tip: Change CAMERA_INDEX in ai_system/src/lettu_vault_ai/config.py")
        return

    print(f"[AI] Camera is LIVE at {ai_cfg.CAMERA_WIDTH}x{ai_cfg.CAMERA_HEIGHT}. Press 'q' to quit.")

    # --- Detection State ---
    detection_start_time     = None
    last_detection_time      = 0
    last_timer_log_time      = 0
    data_sent_for_current_event = False

    # Load stability settings from config
    stability_threshold = ai_cfg.STABILITY_SECONDS
    grace_period        = ai_cfg.GRACE_PERIOD_SECONDS
    timer_log_interval  = ai_cfg.TIMER_LOG_INTERVAL
    total_ms            = int(stability_threshold * 1000)

    # Build detection summary template from tracked classes
    detection_template = {cls: 0 for cls in ai_cfg.TRACKED_CLASSES}

    while True:
        success, frame = cap.read()
        if not success:
            break

        results = model.predict(
            source=frame,
            conf=ai_cfg.CONFIDENCE_THRESHOLD,
            show=False,
            stream=True,
            verbose=False
        )

        detection_summary = detection_template.copy()
        max_conf          = 0.0
        total_detections  = 0

        for r in results:
            annotated_frame = r.plot()
            for box in r.boxes:
                class_id   = int(box.cls[0])
                class_name = model.names[class_id]
                if class_name in detection_summary:
                    detection_summary[class_name] += 1
                conf = float(box.conf[0])
                if conf > max_conf:
                    max_conf = conf
                total_detections += 1

        if ai_cfg.SHOW_CAMERA_WINDOW:
            cv2.imshow(ai_cfg.CAMERA_WINDOW_TITLE, annotated_frame)

        # --- Stability Trigger Logic ---
        current_time = time.time()

        if total_detections > 0:
            last_detection_time = current_time
            if detection_start_time is None:
                detection_start_time = current_time
                last_timer_log_time  = current_time
                print(f"[AI] Object detected! [0/{total_ms}ms]")
            else:
                duration   = current_time - detection_start_time
                ms_elapsed = int(duration * 1000)

                if not data_sent_for_current_event and (current_time - last_timer_log_time > timer_log_interval):
                    print(f"[AI] Stability Check: {min(ms_elapsed, total_ms)}/{total_ms}ms")
                    last_timer_log_time = current_time

                if duration >= stability_threshold and not data_sent_for_current_event:
                    print(f"[AI] Stability Reached: {total_ms}/{total_ms}ms. Sending data!")
                    send_results_to_backend(detection_summary, max_conf)
                    data_sent_for_current_event = True
        else:
            if detection_start_time is not None:
                time_since_last_seen = current_time - last_detection_time
                if time_since_last_seen > grace_period:
                    print(f"[AI] Object lost (>{int(grace_period*1000)}ms). Resetting timer.")
                    detection_start_time        = None
                    data_sent_for_current_event = False

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()
    print("[AI] Camera closed.")

if __name__ == "__main__":
    run_live_camera()
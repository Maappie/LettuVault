# =============================================================
#  🌟 LETTUVAULT AI - MASTER CONFIGURATION
# =============================================================

# ----------------------------
# 📷 CAMERA SETTINGS
# ----------------------------

# Which camera to use.
#   0 = Built-in laptop webcam (default)
#   1 = First external USB camera
#   2 = Second external USB camera
#   "rtsp://..." = IP/Network camera stream URL
CAMERA_INDEX = 2

# Resolution hint (camera may not support all values)
# Common options: (640, 480), (1280, 720), (1920, 1080)
CAMERA_WIDTH  = 640
CAMERA_HEIGHT = 480

# ----------------------------
# 🧠 AI / MODEL SETTINGS
# ----------------------------

# Confidence Threshold (0.0 to 1.0)
#   0.2 = Lenient: detects even uncertain objects (good for dim lighting)
#   0.5 = Balanced: recommended for controlled environments
#   0.7 = Strict: only reports high-confidence detections
CONFIDENCE_THRESHOLD = 0.6

# Path to the custom YOLO model weights.
# Leave as None to use auto-detection (looks for best.pt in runs/).
MODEL_PATH = None  # Example: "ai_system/runs/my_model/weights/best.pt"

# Which classes to track. Must match the model's trained class names.
TRACKED_CLASSES = ["lettuce", "wilting", "worms", "strawberry"]

# ----------------------------
# ⏳ STABILITY & TRIGGER SETTINGS
# ----------------------------

# How long (in seconds) an object must be continuously visible
# before data is sent to the backend.
STABILITY_SECONDS = 3.0

# Grace period (in seconds): if the object disappears briefly
# within this window, the timer does NOT reset.
GRACE_PERIOD_SECONDS = 0.8

# Target AI processing frames per second. Lower values save CPU on the Pi.
TARGET_FPS = 5

# How often to print the stability timer to the log (in seconds).
# Lower = more frequent updates. Higher = less spam.
TIMER_LOG_INTERVAL = 0.3

# ----------------------------
# 📡 MQTT PUBLISHER SETTINGS
# ----------------------------
# These override the .env values. Set to None to use .env instead.

MQTT_BROKER_OVERRIDE = None  # e.g., "127.0.0.1" or None (use .env)
MQTT_PORT_OVERRIDE   = None  # e.g., 1883 or None (use .env)

# ----------------------------
# 🖥️ DISPLAY SETTINGS
# ----------------------------

# Show the annotated camera window with bounding boxes
SHOW_CAMERA_WINDOW = False

# Window title
CAMERA_WINDOW_TITLE = "LettuVault Live AI Detection"

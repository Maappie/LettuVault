import os
from ultralytics import YOLO
from lettu_backend.core.config import PROJECT_ROOT

model_path = os.path.join(PROJECT_ROOT, 'ai_system', 'runs', 'lettuce_strawberry_v116', 'weights', 'best.pt')
if not os.path.exists(model_path):
    model_path = os.path.join(PROJECT_ROOT, 'yolov8n.pt')

model = YOLO(model_path)
print(f"Model: {model_path}")
print(f"Names: {model.names}")

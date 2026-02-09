from ultralytics import YOLO

def main():
    # 1. Load the pre-trained Nano model
    model = YOLO('yolov8n.pt') 

    # 2. Train the model
    # We use imgsz=640 and device='cpu' for stability on your machine
    model.train(
        data='./datasets/data.yaml',   # Point to your custom YAML file
        epochs=100,                    # Standard for thesis research
        imgsz=640,                     # Reliable image resolution
        device='cpu',                  # Forces use of CPU
        project='thesis_runs',         # Main folder for results
        name='lettuce_strawberry_v1',  # Specific run name
        batch=8,                       # Adjust lower (e.g., 4) if it's too slow
        workers=0                      # Prevents multi-processing errors on Windows
    )

if __name__ == '__main__':
    main()
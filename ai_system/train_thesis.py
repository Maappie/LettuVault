import os
from ultralytics import YOLO

def main():
    print("🚀 Initializing YOLOv8 AI Training for Thesis...")

    # 1. Load the pre-trained Nano model
    print("🧠 Loading the YOLOv8 Nano model (yolov8n.pt)...")
    from lettu_backend.core.config import PROJECT_ROOT
    model_path = os.path.join(PROJECT_ROOT, 'ai_system', 'runs', 'lettuce_strawberry_v111', 'weights', 'best.pt')
    if not os.path.exists(model_path):
        model_path = os.path.join(PROJECT_ROOT, 'ai_system', 'yolov8n.pt')
    model = YOLO(model_path) 

    # 2. Get the folder where THIS script is sitting (relative to project root)
    script_dir = os.path.join(PROJECT_ROOT, 'ai_system')
    
    # 3. Path to your data.yaml
    yaml_path = os.path.join(script_dir, 'datasets', 'data.yaml')
    
    # 4. Path for your results (This puts the 'runs' folder inside 'ai_system')
    save_dir = os.path.join(script_dir, 'runs')
    
    print(f"📂 Using dataset configuration from: {yaml_path}")
    print(f"📁 Saving all training results to: {save_dir}")

    # 5. Train the model
    print("🔥 Starting training! This will take a while on CPU...")
    
    model.train(
        data=yaml_path,                
        epochs=3,                    
        imgsz=640,                     
        device='0',                  
        project=save_dir,              # 🎯 Forces results into ai_system/runs
        name='lettuce_strawberry_v1',  
        batch=8,                       
        workers=0                      
    )

    print("\n🎉 Training Complete! Your AI is ready.")
    print(f"📁 Find your graphs and weights in: {save_dir}/lettuce_strawberry_v1")

if __name__ == '__main__':
    main()
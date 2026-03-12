import os
from ultralytics import YOLO

def main():
    print("🚀 Initializing YOLOv8 AI Training for Thesis...")

    # 1. Load the pre-trained Nano model
    print("🧠 Loading the YOLOv8 Nano model (yolov8n.pt)...")
    model = YOLO('yolov8n.pt') 

    # 2. Get the folder where THIS script is sitting (C:\...\LettuVault\ai_system)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
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
        epochs=1,                    
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
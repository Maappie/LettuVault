import os
from ultralytics import YOLO

def main():
    print("🚀 Initializing YOLOv8 AI Training for Thesis...")

    # --- 1. CONFIGURATION ---
    # Since you stopped v116 midway, we keep this as our target.
    target_name = 'lettuce_strawberry_v116' 
    total_epochs = 150 

    script_dir = os.path.dirname(os.path.abspath(__file__))
    yaml_path = os.path.join(script_dir, 'datasets', 'data.yaml')
    save_dir = os.path.join(script_dir, 'runs')
    
    # Path to the specific checkpoint you just created by stopping midway
    checkpoint_path = os.path.join(save_dir, target_name, 'weights', 'last.pt')

    # --- 2. RESUME LOGIC ---
    if os.path.exists(checkpoint_path):
        print(f"✅ Found progress! Resuming {target_name} from: {checkpoint_path}")
        
        # Load the partially trained model
        model = YOLO(checkpoint_path)
        
        # When resume=True, YOLO loads 'data', 'imgsz', and 'name' from the file.
        # We only need to specify the total epochs and device.
        model.train(
            resume=True,
            epochs=total_epochs,
            device='0',
            workers=0
        )
    else:
        # FALLBACK: If v116 is missing, start fresh from your last successful version
        print(f"⚠️ Checkpoint not found at {checkpoint_path}")
        print("🧠 Starting fresh using V114 best weights...")
        
        from lettu_backend.core.config import PROJECT_ROOT
        initial_weights = os.path.join(PROJECT_ROOT, 'ai_system', 'runs', 'lettuce_strawberry_v114', 'weights', 'best.pt')
        model = YOLO(initial_weights)
        
        model.train(
            data=yaml_path,                
            epochs=total_epochs,                 
            imgsz=640,                     
            device='0',                  
            project=save_dir,              
            name=target_name,
            batch=8,                       
            workers=0                      
        )

    print("\n🎉 Training session handled!")

if __name__ == '__main__':
    main()
# start.py (in the root folder)
import uvicorn
import os
import sys

# Ensure the 'src' folders are in the Python path so the packages are found
# This mimics the '-e .' behavior of your installation
sys.path.append(os.path.join(os.getcwd(), "backend", "src"))
sys.path.append(os.path.join(os.getcwd(), "ai_system", "src"))

if __name__ == "__main__":
    print("🥬 LettuVault System Booting Up...")
    
    # Run Uvicorn programmatically
    # 'lettu_backend.main:app' matches your package structure
    uvicorn.run(
        "lettu_backend.main:app", 
        host="127.0.0.1", 
        port=8000, 
        reload=True,
        log_level="info"
    )
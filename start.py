# start.py (in the root folder)
import uvicorn
import os
import sys
import socket

# Ensure the 'src' folders are in the Python path so the packages are found
sys.path.append(os.path.join(os.getcwd(), "backend", "src"))
sys.path.append(os.path.join(os.getcwd(), "ai_system", "src"))

if __name__ == "__main__":
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)
    
    print(f"🥬 LettuVault System Booting Up...")
    print(f"📍 Network Accessible at: http://{local_ip}:8000")
    print(f"🛠️  Local Docs: http://localhost:8000/docs")
    print("-" * 50)
    
    # Run Uvicorn - Bind to 0.0.0.0 for external network access
    uvicorn.run(
        "lettu_backend.main:app", 
        host="0.0.0.0", 
        port=8000, 
        reload=True,
        log_level="info"
    )
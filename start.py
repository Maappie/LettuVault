import uvicorn
import os
import sys
import socket
from dotenv import load_dotenv, find_dotenv

# Load env variables
load_dotenv(find_dotenv())

# Ensure the 'src' folders are in the Python path so the packages are found
sys.path.append(os.path.join(os.getcwd(), "backend", "src"))
sys.path.append(os.path.join(os.getcwd(), "ai_system", "src"))

if __name__ == "__main__":
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)
    
    api_host = os.getenv("API_HOST", "0.0.0.0")
    api_port = int(os.getenv("API_PORT", 8000))
    
    print(f"🥬 LettuVault System Booting Up...")
    print(f"📍 Network Accessible at: http://{local_ip}:{api_port}")
    print(f"🛠️  Local Docs: http://localhost:{api_port}/docs")
    print("-" * 50)
    
    # Run Uvicorn - Bind to 0.0.0.0 for external network access
    uvicorn.run(
        "lettu_backend.main:app", 
        host=api_host, 
        port=api_port, 
        reload=True,
        log_level="info"
    )
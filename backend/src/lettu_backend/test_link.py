# backend/src/lettu_backend/test_link.py

# This is the "Magic Import" we enabled with the workspace mapping
from lettu_vault_ai.test_detector import WormDetector

def run_test():
    print("[Backend] Requesting scan from AI...")
    
    # Initialize the class from the OTHER package
    bot = WormDetector()
    
    # Run the dummy scan
    result = bot.scan()
    
    print(f"[Backend] Received results: {result}")

if __name__ == "__main__":
    run_test()
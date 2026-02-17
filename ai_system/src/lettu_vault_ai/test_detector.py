# ai_system/src/lettu_vault_ai/detector.py
# put your detector logic here

# ai_system/src/lettu_vault_ai/detector.py

class WormDetector:
    def __init__(self):
        self.model_name = "YOLOv8-LettuVault"
        print(f"[AI] {self.model_name} initialized and ready.")

    def scan(self):
        # This is a dummy result for testing
        return {"worms_found": 2, "confidence": 0.98, "status": "Worms detected!"}
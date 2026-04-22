# backend/src/lettu_backend/services/mqtt/handlers/ai_handler.py
import base64
import os
import datetime
import logging
from typing import Dict, Any

from lettu_backend.services.mqtt.api_client import api_client

logger = logging.getLogger("MQTT_SERVICE")

# Folder where AI snapshots are stored (strictly relative to LettuVault root)
from lettu_backend.core.config import CAPTURES_DIR

os.makedirs(CAPTURES_DIR, exist_ok=True)

class AIActivityHandler:
    def __init__(self):
        self.last_produce_time = 0
        self.last_condition_time = 0

    def process(self, payload: Dict[str, Any]):
        """Decodes base64 images, processes produce/condition detection with debouncing."""
        image_rel_path = None
        image_b64 = payload.pop("image_b64", None)
        scan_type = payload.pop("scan_type", "condition") # Default to condition
        
        if image_b64:
            try:
                ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S_%f")
                filename = f"scan_{ts}.jpg"
                filepath = os.path.join(CAPTURES_DIR, filename)
                with open(filepath, "wb") as f:
                    f.write(base64.b64decode(image_b64))
                image_rel_path = filename
                logger.info(f"📸 [SUBSCRIBER] Snapshot saved locally: {os.path.join(CAPTURES_DIR, filename)}")
            except Exception as img_err:
                logger.warning(f"⚠️ [SUBSCRIBER] Could not save snapshot: {img_err}")

        payload["image"] = image_rel_path
        
        if scan_type == "produce":
            # --- DEBOUNCE: 10-second Backend Lock ---
            now_ts = datetime.datetime.now().timestamp()
            if now_ts - self.last_produce_time < 10.0:
                logger.warning("🚫 [SUBSCRIBER] Produce Scan ignored (Debounce Lock)")
                return
            self.last_produce_time = now_ts

            produce_payload = {
                "produce_type": payload.get("produce_type"),
                "confidence_score": payload.get("confidence_score"),
                "image": payload.get("image"),
                "label": payload.get("label")
            }
            api_client.send_to_api("ai-scans", produce_payload)
            logger.info("🥗 [SUBSCRIBER] Posted AI Produce detection to API")
        else:
            # --- DEBOUNCE: 30-second Backend Cooldown ---
            now_ts = datetime.datetime.now().timestamp()
            if now_ts - self.last_condition_time < 30.0:
                logger.warning("🚫 [SUBSCRIBER] Condition Scan ignored (Debounce Lock)")
                return
            self.last_condition_time = now_ts

            condition_payload = {
                "worm_count": payload.get("worm_count", 0),
                "confidence_score": payload.get("confidence_score"),
                "image": payload.get("image"),
                "label": payload.get("label")
            }
            api_client.send_to_api("ai-scans", condition_payload)
            logger.info("🐛 [SUBSCRIBER] Posted AI Condition detection to API")

ai_handler = AIActivityHandler()

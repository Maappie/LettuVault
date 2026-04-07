# backend/src/lettu_backend/services/mqtt/handlers/config_handler.py
import logging
from typing import Dict, Any
from lettu_backend.services.mqtt.api_client import api_client

logger = logging.getLogger("MQTT_SERVICE")

def process_config_update(payload: Dict[str, Any]):
    """Processes incoming ESP32 configuration updates (sync)."""
    # Extract only the configuration fields
    config_payload = {}
    if "temperature" in payload:
        config_payload["temperature"] = payload["temperature"]
    if "humidity" in payload:
        config_payload["humidity"] = payload["humidity"]
    if "pressure" in payload:
        config_payload["pressure"] = payload["pressure"]
    
    if config_payload:
        # Send to the /system_config endpoint to update the database
        api_client.send_to_api("system_config", config_payload)
        logger.info(f"⚙️ [SUBSCRIBER] Synced Config scan from ESP32 to DB: {config_payload}")
    else:
        logger.warning("⚠️ [SUBSCRIBER] Received config sync with no valid fields")

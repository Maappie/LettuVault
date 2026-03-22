# backend/src/lettu_backend/services/mqtt/handlers/sensor_handler.py
import logging
from typing import Dict, Any
from lettu_backend.services.mqtt.api_client import api_client

logger = logging.getLogger("MQTT_SERVICE")

def process_sensor_data(payload: Dict[str, Any]):
    """Processes incoming ESP32 sensor readings."""
    sensor_payload = {
        "temperature": payload.get("temperature"),
        "humidity": payload.get("humidity"),
        "pressure": payload.get("pressure")
    }
    api_client.send_to_api("sensor-readings", sensor_payload)
    api_client.send_to_api("internal-environment", sensor_payload)
    logger.info("🌡️ [SUBSCRIBER] Posted Sensor data to API (/sensor-readings & /internal-environment)")

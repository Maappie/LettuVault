# backend/src/lettu_backend/services/mqtt/router.py
import json
import logging
from typing import Dict, Any

from lettu_backend.core.config import settings
from lettu_backend.services.mqtt.handlers.ai_handler import ai_handler
from lettu_backend.services.mqtt.handlers.sensor_handler import process_sensor_data
from lettu_backend.services.mqtt.handlers.config_handler import process_config_update
from lettu_backend.services.mqtt.rpc_manager import rpc_manager

logger = logging.getLogger("MQTT_SERVICE")

def dispatch(topic: str, raw_payload: bytes, is_subscriber: bool):
    """Parses JSON, performs security check, and routes to appropriate handler."""
    try:
        data = json.loads(raw_payload.decode())
    except json.JSONDecodeError as je:
        logger.error(f"❌ [ROUTER] JSON decode error on [{topic}]: {je}")
        logger.error(f"   Raw payload was: {raw_payload[:200]}")
        return
    except Exception as e:
        logger.error(f"❌ [ROUTER] Unexpected error processing message on [{topic}]: {e}")
        return

    # --- 1. ACKNOWLEDGE MESSAGE CHECK ---
    # ACKs are purely utility messages for FastAPI routes; they bypass standard API Key checks.
    if topic == "lettuvault/ack":
        ack_id = data.get("ack_id")
        if ack_id is not None:
            rpc_manager.resolve_ack(ack_id)
        return

    # --- 2. API SERVER SHORT-CIRCUIT ---
    # If the FastAPI worker is in publisher mode, it MUST NOT process actual data to prevent DB duplication!
    if not is_subscriber:
        return 
        
    logger.info(f"📨 [ROUTER] Message matched on topic: [{topic}] ({len(raw_payload)} bytes)")

    # --- 3. SECURITY CHECK ---
    payload_key = data.get("api_key")
    if payload_key != settings.X_API_KEY:
        logger.warning(f"🔒 [ROUTER] Security block on [{topic}]. Invalid/Missing X-API-KEY: {payload_key}")
        return

    # --- 4. TOPIC DISPATCHING ---
    if topic == settings.MQTT_TOPIC_AI:
        ai_handler.process(data)
    elif topic == settings.MQTT_TOPIC_SENSORS:
        process_sensor_data(data)
    elif topic == "lettuvault/config/sync":
        process_config_update(data)
    else:
        logger.warning(f"⚠️ [ROUTER] Unmapped topic received: {topic}")

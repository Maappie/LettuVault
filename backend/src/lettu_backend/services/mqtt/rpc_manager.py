# backend/src/lettu_backend/services/mqtt/rpc_manager.py
import uuid
import time
import json
import logging
import threading
from typing import Dict, Optional, Callable

logger = logging.getLogger("MQTT_SERVICE")

class MQTTRpcManager:
    """Safely manages synchronous HTTP waits against asynchronous MQTT thread traffic."""
    
    def __init__(self):
        # Maps tx_id (str) -> threading.Event
        self.pending_acks: Dict[str, threading.Event] = {}

    def resolve_ack(self, ack_id: str):
        """Called by the MQTT Router when an incoming lettuvault/ack message arrives."""
        if ack_id in self.pending_acks:
            self.pending_acks[ack_id].set()
            logger.info(f"✅ [ACK] Delivered config to ESP32: tx_id={ack_id}")

    def wait_for_ack(self, publish_callback: Callable, payload: dict, max_retries: int = 3, timeout: float = 3.0) -> bool:
        """
        Publishes config and blocks the current thread until `resolve_ack()` sets the event.
        publish_callback must be a function that takes a JSON string and publishes it.
        """
        tx_id = str(uuid.uuid4())
        payload["tx_id"] = tx_id
        msg_str = json.dumps(payload)
        
        # Create a threading Event specifically for this transaction
        ack_event = threading.Event()
        self.pending_acks[tx_id] = ack_event
        
        success = False
        
        try:
            for attempt in range(max_retries):
                ack_event.clear()
                logger.info(f"📤 [PUBLISHER] Sending config (Attempt {attempt+1}/{max_retries}) tx_id={tx_id}")
                publish_callback(msg_str)
                
                # Wait blocks ONLY this thread pool thread, immediately unblocking on set()
                got_ack = ack_event.wait(timeout)
                
                if got_ack:
                    logger.info(f"✅ [PUBLISHER] ACK successfully received from ESP32 for {tx_id}")
                    success = True
                    break
                    
                logger.warning(f"⏳ [PUBLISHER] Timeout waiting for ACK {tx_id} (Attempt {attempt+1})")
        finally:
            if tx_id in self.pending_acks:
                del self.pending_acks[tx_id]
                
        return success

rpc_manager = MQTTRpcManager()

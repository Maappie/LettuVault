# backend/src/lettu_backend/services/mqtt/__main__.py
import time
import logging

from lettu_backend.services.mqtt.client import mqtt_service

logger = logging.getLogger("MQTT_SERVICE")

def run_standalone():
    """Entry point for running MQTT service in its own terminal worker."""
    logging.basicConfig(level=logging.INFO, format='%(message)s')
    
    # Crucial: Standalone worker acts as a subscriber to parse data.
    # It does not run HTTP FastAPI endpoints, so it doesn't wait for ACKs
    mqtt_service.is_subscriber = True
    mqtt_service.start()
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        logger.info("🛑 [MQTT] Subscriber interupted by user. Shutting down...")
        mqtt_service.client.loop_stop()
        mqtt_service.client.disconnect()

if __name__ == "__main__":
    run_standalone()

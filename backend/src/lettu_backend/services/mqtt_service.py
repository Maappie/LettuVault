# backend/src/lettu_backend/services/mqtt_service.py
import paho.mqtt.client as mqtt
import json
import logging
from lettu_backend.core.config import settings
from lettu_backend.models.database import SessionLocal
from lettu_backend.repository.scan_repo import DataRepository

logger = logging.getLogger("MQTT_SERVICE")

class MQTTService:
    def __init__(self):
        self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message
        self.broker = settings.MQTT_BROKER
        self.port = settings.MQTT_PORT

    def on_connect(self, client, userdata, flags, rc, properties):
        if rc == 0:
            client.subscribe(settings.MQTT_TOPIC_SENSORS)
            client.subscribe(settings.MQTT_TOPIC_AI)
            logger.info(f"[MQTT] Subscribed to Sensors: {settings.MQTT_TOPIC_SENSORS}")
            logger.info(f"[MQTT] Subscribed to AI: {settings.MQTT_TOPIC_AI}")

    def on_message(self, client, userdata, msg):
        try:
            data = json.loads(msg.payload.decode())
            db = SessionLocal()
            try:
                repo = DataRepository(db)
                if msg.topic == settings.MQTT_TOPIC_AI:
                    repo.create_ai_scan(data)
                    logger.info("AI data saved via MQTT.")
                elif msg.topic == settings.MQTT_TOPIC_SENSORS:
                    repo.create_sensor_reading(data)
                    logger.info("Sensor data saved via MQTT.")
            finally:
                db.close()
        except Exception as e:
            logger.error(f"❌ MQTT Processing Error: {e}")

    def start(self):
        import time
        retries = 5
        while retries > 0:
            try:
                self.client.connect(self.broker, self.port, 60)
                self.client.loop_start()
                logger.info(f"[MQTT] Connected to {self.broker}")
                return
            except Exception as e:
                retries -= 1
                logger.warning(f"[MQTT] Broker not ready, retrying in 2s... ({retries} left)")
                time.sleep(2)
        logger.error("[MQTT] Connection failed after multiple attempts.")

mqtt_service = MQTTService()

def run_standalone():
    """Entry point for running MQTT service in its own terminal."""
    import time
    logging.basicConfig(level=logging.INFO)
    logger.info("[MQTT] Connecting to Broker...")
    mqtt_service.start()
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        logger.info("[MQTT] Stopping...")

if __name__ == "__main__":
    run_standalone()

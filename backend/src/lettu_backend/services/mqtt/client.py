# backend/src/lettu_backend/services/mqtt/client.py
import paho.mqtt.client as mqtt
import logging
import time

from lettu_backend.core.config import settings
from lettu_backend.services.mqtt import router
from lettu_backend.services.mqtt.rpc_manager import rpc_manager

logger = logging.getLogger("MQTT_SERVICE")

class MQTTClientWrapper:
    def __init__(self):
        self.client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
        self.client.on_connect = self.on_connect
        self.client.on_disconnect = self.on_disconnect
        self.client.on_message = self.on_message
        self.broker = settings.MQTT_BROKER
        self.port = settings.MQTT_PORT
        self.is_subscriber = True  # Default to Worker Mode

    def on_connect(self, client, userdata, flags, rc, properties):
        if not rc.is_failure:
            if self.is_subscriber:
                result_sensors, _ = client.subscribe(settings.MQTT_TOPIC_SENSORS)
                result_ai, _      = client.subscribe(settings.MQTT_TOPIC_AI)
                
                logger.info(f"✅ [SUBSCRIBER] Connected to Broker @ {self.broker}:{self.port}")
                
                if result_sensors == mqtt.MQTT_ERR_SUCCESS:
                    logger.info(f"📥 [SUBSCRIBER] Subscribed OK → {settings.MQTT_TOPIC_SENSORS}")
                else:
                    logger.error(f"❌ [SUBSCRIBER] Failed to subscribe to {settings.MQTT_TOPIC_SENSORS}")
                if result_ai == mqtt.MQTT_ERR_SUCCESS:
                    logger.info(f"📥 [SUBSCRIBER] Subscribed OK → {settings.MQTT_TOPIC_AI}")
                else:
                    logger.error(f"❌ [SUBSCRIBER] Failed to subscribe to {settings.MQTT_TOPIC_AI}")
            
            # ALWAYS subscribe to the ACK topic so the FastAPI worker can receive its HTTP response acks
            result_ack, _ = client.subscribe("lettuvault/ack")
            if result_ack == mqtt.MQTT_ERR_SUCCESS:
                logger.info(f"📥 [SUBSCRIBER] Subscribed OK → lettuvault/ack")
            else:
                logger.error(f"❌ [SUBSCRIBER] Failed to subscribe to lettuvault/ack")

            # Subscribe to the config sync topic
            result_sync, _ = client.subscribe("lettuvault/config/sync")
            if result_sync == mqtt.MQTT_ERR_SUCCESS:
                logger.info(f"📥 [SUBSCRIBER] Subscribed OK → lettuvault/config/sync")
            else:
                logger.error(f"❌ [SUBSCRIBER] Failed to subscribe to lettuvault/config/sync")
                
            if not self.is_subscriber:
                logger.info(f"📤 [PUBLISHER] API Server connected to Broker (Send-Only Mode + Ack Listener)")
        else:
            logger.error(f"❌ [MQTT] Connection FAILED → {str(rc)}")

    def on_disconnect(self, client, userdata, disconnect_flags, rc, properties):
        if not rc.is_failure:
            logger.info("🔌 [MQTT] Disconnected cleanly.")
        else:
            logger.warning(f"⚠️ [MQTT] Unexpected disconnect → {str(rc)}. Will attempt to reconnect...")

    def on_message(self, client, userdata, msg):
        # Pass logic off to the isolated routing module
        router.dispatch(msg.topic, msg.payload, self.is_subscriber)

    def start(self):
        logger.info(f"[MQTT] Attempting to connect to broker @ {self.broker}:{self.port} ...")
        while True:
            try:
                self.client.connect(self.broker, self.port, 60)
                self.client.loop_start()
                logger.info(f"✅ [MQTT] Broker connection established @ {self.broker}:{self.port}")
                return
            except ConnectionRefusedError:
                logger.error(f"❌ [MQTT] Connection refused by broker @ {self.broker}:{self.port} — Is the broker running? Retrying in 5s...")
                time.sleep(5)
            except OSError as e:
                logger.error(f"❌ [MQTT] Network error connecting to {self.broker}:{self.port} — {e}. Retrying in 5s...")
                time.sleep(5)
            except Exception as e:
                logger.warning(f"⚠️ [MQTT] Unknown connection error ({e}), retrying in 5s...")
                time.sleep(5)

    def send_command(self, message: str):
        """Send a message to the ESP32 control topic."""
        topic = "lettuvault/control"
        self.client.publish(topic, message)
        logger.info(f"📤 [PUBLISHER] Sent command: '{message}' to {topic}")

    def send_config_with_ack(self, payload: dict, max_retries=3, timeout=3.0) -> bool:
        """Publishes config through rpc_manager and blocks the current async-friendly worker."""
        # Using a closure lambda callback to allow decoupled RPC manager to execute network operations securely
        return rpc_manager.wait_for_ack(
            publish_callback=lambda msg_str: self.client.publish("lettuvault/control", msg_str),
            payload=payload,
            max_retries=max_retries,
            timeout=timeout
        )

mqtt_service = MQTTClientWrapper()

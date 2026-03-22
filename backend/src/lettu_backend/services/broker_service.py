import asyncio
import logging
import os
from amqtt.broker import Broker
from dotenv import load_dotenv, find_dotenv

load_dotenv(find_dotenv())

logging.getLogger('amqtt').setLevel(logging.ERROR)
logging.getLogger('transitions').setLevel(logging.ERROR)

# ✅ Port is read from .env — change it there for local dev or cloud deployment
MQTT_PORT = int(os.getenv("MQTT_PORT", "1883"))
MQTT_BIND = f"0.0.0.0:{MQTT_PORT}"

CONFIG = {
    'listeners': {
        'default': {
            'type': 'tcp',
            'bind': MQTT_BIND,
        }
    },
    'sys_interval': 10,
    'auth': {
        'allow-anonymous': True,
    }
}

async def main():
    broker = Broker(CONFIG)
    await broker.start()
    print(f"[BROKER] Local MQTT Broker running on {MQTT_BIND}")
    try:
        while True:
            await asyncio.sleep(1)
    except asyncio.CancelledError:
        pass
    await broker.shutdown()
    print("[BROKER] Stopped.")

if __name__ == '__main__':
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("[BROKER] Shutting down...")


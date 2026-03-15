import asyncio
import logging
from amqtt.broker import Broker

logging.getLogger('amqtt').setLevel(logging.ERROR)
logging.getLogger('transitions').setLevel(logging.ERROR)

CONFIG = {
    'listeners': {
        'default': {
            'type': 'tcp',
            'bind': '0.0.0.0:1883',
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
    print("[BROKER] Local MQTT Broker running on 127.0.0.1:1883")
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

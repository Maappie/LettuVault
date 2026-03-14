# Embedded System — LettuVault (ESP32)

This folder contains the firmware/code for the ESP32 hardware component.

---

## What the ESP32 does

1. Reads **temperature** and **humidity** from a sensor (e.g., DHT22)
2. Connects to WiFi
3. **Publishes** sensor data to the local MQTT broker as JSON

---

## MQTT Payload Format

The ESP32 should publish to the `lettuvault/sensors` topic with this JSON format:

```json
{
  "temperature": 27.5,
  "humidity": 65.2,
  "device_id": "esp32-01"
}
```

## MQTT Connection Settings

Match these to your `.env` file:

```
Broker IP : 127.0.0.1  (or your PC's local IP on the same WiFi network)
Port      : 1883
Topic     : lettuvault/sensors
```

> **Note**: If the ESP32 and your PC are on the same WiFi, use your PC's local IP (e.g., `192.168.1.x`) instead of `127.0.0.1`.

---

## Testing Without Hardware

Use the **Hardware Simulator** at `http://127.0.0.1:8000/simulator` to send fake sensor data while developing.
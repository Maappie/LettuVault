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


Viewed main.cpp:1-18
Viewed platformio.ini:1-15
Edited platformio.ini
Edited main.cpp
Listed directory src
Edited main.cpp

I have updated your code and configuration to support the BME280 sensor. 

### ⚙️ 1. Wiring Instructions (ESP32 to BME280)
For a standard ESP32 DevKit, use these connections (I2C mode):

| BME280 Pin | ESP32 Pin | Description |
| :--- | :--- | :--- |
| **VCC** | **3.3V** | Power (Do not use 5V) |
| **GND** | **GND** | Ground |
| **SCL** | **GPIO 22** | I2C Clock |
| **SDA** | **GPIO 21** | I2C Data |

### 🛠️ 2. What I've Done
1.  **Updated [platformio.ini](cci:7://file:///c:/Users/Renz/LettuVault/platformio.ini:0:0-0:0)**: Added the `Adafruit BME280 Library` to your project dependencies.
2.  **Updated [main.cpp](cci:7://file:///c:/Users/Renz/LettuVault/embedded/src/LettuVault/src/main.cpp:0:0-0:0)**: Replaced the placeholder code with a complete script that:
    *   Initializes the BME280 sensor.
    *   Reads Temperature, Pressure, Altitude, and Humidity.
    *   Prints the results to the Serial Monitor every 3 seconds.

### 📝 3. Things to Note
*   **I2C Address**: Most BME280 sensors use address `0x76`. If the code says it can't find the sensor, try changing `bme.begin(0x76)` to `bme.begin(0x77)` in the [setup()](cci:1://file:///c:/Users/Renz/LettuVault/embedded/src/LettuVault/src/main.cpp:17:0-35:1) function.
*   **Serial Monitor**: Make sure your Serial Monitor speed is set to **115200 baud** in VS Code to see the output.

You can now upload the code to your ESP32 using the PlatformIO "Upload" button!
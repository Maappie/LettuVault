# Embedded System — LettuVault (ESP32)

This folder contains the firmware/code for the ESP32 hardware component running FreeRTOS dual-core tasks.

---

## 🔌 Complete Wiring Guide

### 1. I2C Bus (OLED Display & BME280 Sensor)
Both the BME280 and SSD1306 OLED share the same I2C pins. You can daisy-chain them or wire them both to the exact same pins on the ESP32.

| Component Pin | ESP32 Pin | Description |
| :--- | :--- | :--- |
| **VCC** | **3.3V** | Power (Do not use 5V for BME280!) |
| **GND** | **GND** | Ground |
| **SCL** | **GPIO 22** | I2C Clock |
| **SDA** | **GPIO 21** | I2C Data |

*Note: The BME280 uses address 0x76 by default in the code, while the OLED uses 0x3C.*

### 2. Relay Modules (Two 4-Channel Boards)
The code triggers these pins as Logic HIGH. Even though you have two physical relay boards, they are both hooked to the **same single ESP32**.

| Relay Component | ESP32 Pin | Purpose |
| :--- | :--- | :--- |
| **Relay 1 (Board 1)** | **GPIO 25** | 30A Compressor (Cooling) |
| **Relay 1 (Board 2)** | **GPIO 26** | 10A Vacuum Pump (Pressure) |
| **Relay 2 (Board 2)** | **GPIO 27** | 10A Humidifier (Moisture) |
| **VCC / JD-VCC** | **5V (VIN)** | Power for Relay Coils |
| **GND** | **GND** | Common Ground |

*Note: The code runs all three control loops simultaneously on Core 1.*

### 3. Membrane Keypad (4x4)
Wire the 8 pins from the membrane keypad from left to right (facing the front of the keypad/buttons).

| Keypad Pin (L→R) | Type | ESP32 Pin |
| :--- | :--- | :--- |
| **Pin 1** | Row 1 | **GPIO 19** |
| **Pin 2** | Row 2 | **GPIO 18** |
| **Pin 3** | Row 3 | **GPIO 5** |
| **Pin 4** | Row 4 | **GPIO 4** |
| **Pin 5** | Col 1 | **GPIO 13** |
| **Pin 6** | Col 2 | **GPIO 14** |
| **Pin 7** | Col 3 | **GPIO 23** |
| **Pin 8** | Col 4 | **GPIO 33** |

---

## 📡 MQTT Payload Format

The ESP32 publishes sensor data every 5 seconds to the `lettuvault/sensors` topic.

```json
{
  "api_key": "lettuce-master-key-2024",
  "device_id": "ESP32-LettuVault-01",
  "temperature": 27.5,
  "humidity": 65.2,
  "pressure": 1013.25
}
```

## ⚙️ How to Setup

Open `src/main.cpp` and update these lines at the very top of the file to match your environment before flashing:

```cpp
#define WIFI_SSID       "YourWiFi"
#define WIFI_PASSWORD   "YourPass123!"
#define MQTT_SERVER     "192.168.1.X" // Your PC/Server's Local IP
#define DEVICE_ID       "ESP32-LettuVault-01" 
```

Upload the code to your ESP32 using the PlatformIO "Upload" button!
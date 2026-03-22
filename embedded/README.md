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

### 2. Relays (Board 1 vs Board 2)
The relays are configured as Logic HIGH triggers. The code automatically behaves differently based on the `DEVICE_ID` configured in `main.cpp`.

| Relay Label | ESP32 Pin | Board 1 (`LettuVault-01`) | Board 2 (`LettuVault-02`) |
| :--- | :--- | :--- | :--- |
| **Relay 1 (IN1)** | **GPIO 25** | 30A Compressor (Cooling) | 10A (Pressure Control) |
| **Relay 2 (IN2)** | **GPIO 26** | *Not Used* | 10A (Humidity Control) |
| **Relay 3 (IN3)** | **GPIO 27** | *Not Used* | 10A (Spare/Future) |
| **Relay VCC** | **5V (VIN)** | Power for Relay Coil | Power for Relay Coil |
| **Relay GND** | **GND**      | Common Ground | Common Ground |

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
#define DEVICE_ID       "ESP32-LettuVault-01" // Use -01 for Board 1, -02 for Board 2
```

Upload the code to your ESP32 using the PlatformIO "Upload" button!
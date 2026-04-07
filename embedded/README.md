# Embedded System — LettuVault (ESP32)

This folder contains the firmware/code for the ESP32 hardware component running FreeRTOS dual-core tasks.

---

## 🔌 Complete Wiring Guide

### 1. I2C Bus 0 — OLED Display (Wire: SDA=21, SCL=22)

| Component Pin | ESP32 Pin | Description |
| :--- | :--- | :--- |
| **VCC** | **3.3V** | Power |
| **GND** | **GND** | Ground |
| **SCL** | **GPIO 22** | I2C Clock (Wire default) |
| **SDA** | **GPIO 21** | I2C Data (Wire default) |

*OLED I2C address: `0x3C`*

### 2. I2C Bus 1 — BME280 Sensor (Wire1: SDA=32, SCL=33)

| Component Pin | ESP32 Pin | Description |
| :--- | :--- | :--- |
| **VCC** | **3.3V** | Power (Do not use 5V!) |
| **GND** | **GND** | Ground |
| **SCL** | **GPIO 33** | I2C Clock (Wire1) |
| **SDA** | **GPIO 32** | I2C Data (Wire1) |

*BME280 I2C address: `0x76` (default) or `0x77`*

### 3. Relay Modules

Both boards are **Active HIGH** — `HIGH` activates the relay, `LOW` deactivates it.

#### Board 1 — Compressor (Active HIGH)
| Relay | ESP32 Pin | Trigger | Load Terminal |
| :--- | :--- | :--- | :--- |
| **Relay 1** | **GPIO 25** | HIGH = ON | **NO** |
| **VCC / JD-VCC** | **5V (VIN)** | — | Power for coil |
| **GND** | **GND** | — | Ground |

#### Board 2 — Vacuum Pump & Humidifier (Active LOW)
| Relay | ESP32 Pin | Trigger | Load Terminal |
| :--- | :--- | :--- | :--- |
| **Relay 1** | **GPIO 26** | LOW = ON | **NO** |
| **Relay 2** | **GPIO 27** | LOW = ON | **NO** |
| **VCC / JD-VCC** | **5V (VIN)** | — | Power for coil |
| **GND** | **GND** | — | Ground |

- **Active LOW**: Send `LOW` to activate, `HIGH` to deactivate.
- **Connect all loads to NO (Normally Open)**: Load is OFF by default. Safe during ESP32 resets (pins initialize HIGH, keeping relay OFF).

*All three control loops run simultaneously on Core 1.*

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
| **Pin 8** | Col 4 | **GPIO 15** |

---

## ⚙️ How to Setup

WiFi and MQTT settings are stored in **non-volatile storage (NVS)** on the ESP32 and can be changed at runtime using the keypad menu. The values in `main.cpp` are only used as **first-boot defaults**:

```cpp
#define DEFAULT_WIFI_SSID       "YourWiFi"
#define DEFAULT_WIFI_PASSWORD   "YourPass123!"
#define DEFAULT_MQTT_SERVER     "192.168.1.X" // Your PC/Server's Local IP
#define DEFAULT_MQTT_PORT       1883
#define DEVICE_ID               "ESP32-LettuVault-01"
```

After the first boot, all settings (WiFi, MQTT, and Setpoints) can be changed directly from the **OLED Keypad Menu** without reflashing.

Upload the code to your ESP32 using the PlatformIO "Upload" button!

---

## 🖥️ OLED Menu Navigation

The 4x4 keypad controls a multi-page menu on the OLED screen.

| Key | Action |
| :--- | :--- |
| `0–9` | Select a menu option |
| `*` | Enter Edit mode / Decimal point when entering values |
| `A` | Confirm / Save input |
| `B` | **Backspace** (delete last character) |
| `D` | Go Back / Cancel |

### Menu Structure
```
Home (shows WIFI & MQTT status)
├── 1. System Config      → View current setpoints
│   └── *. Edit Config
│       ├── 1. Temperature  → Enter new value (A=Save, B=Del, D=Cancel)
│       ├── 2. Humidity
│       └── 3. Pressure
├── 2. System Read        → Live BME280 sensor values
└── 3. Network Config
    ├── 1. WIFI Status    → Shows SSID and connection state
    ├── 2. Change WIFI    → Enter new SSID then Password
    ├── 3. MQTT Status    → Shows server, port, and connection state
    └── 4. Change MQTT    → Enter new server then port
```

---

## 📡 MQTT Topics

| Topic | Direction | Description |
| :--- | :--- | :--- |
| `lettuvault/sensors` | ESP32 → Backend | Sensor telemetry every 5 seconds |
| `lettuvault/control` | Backend → ESP32 | Remote setpoint updates |
| `lettuvault/ack` | ESP32 → Backend | Acknowledgement for received commands |
| `lettuvault/config/sync` | ESP32 → Backend | Setpoint changes made via keypad |

### Sensor Payload (`lettuvault/sensors`)
```json
{
  "api_key": "lettuce-master-key-2024",
  "device_id": "ESP32-LettuVault-01",
  "temperature": 27.5,
  "humidity": 65.2,
  "pressure": 1013.25
}
```

### Config Sync Payload (`lettuvault/config/sync`)
Published automatically when setpoints are changed via the keypad:
```json
{
  "api_key": "lettuce-master-key-2024",
  "device_id": "ESP32-LettuVault-01",
  "temperature": 20.0,
  "humidity": 60.0,
  "pressure": 1013.25
}
```
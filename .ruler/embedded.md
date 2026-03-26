# Embedded System Rules — LettuVault
# Hardware: ESP32 DevKit
# Framework: Arduino / FreeRTOS via PlatformIO

---

## Hardware Overview

One **single ESP32** controls:
- **1 BME280 sensor** (temperature, humidity, pressure) via I2C
- **1 SSD1306 OLED display** (128×64) via I2C (shared bus with BME280)
- **2 four-channel relay boards** connected to GPIO pins 25, 26, 27
- **1 4×4 membrane keypad**

---

## Pin Assignments

| GPIO | Component | Notes |
|---|---|---|
| **21** | I2C SDA | Shared: BME280 + SSD1306 OLED |
| **22** | I2C SCL | Shared: BME280 + SSD1306 OLED |
| **25** | `RELAY_COMPRESSOR` | 30A — Board 1, Channel 1 (Temperature) |
| **26** | `RELAY_VACUUM` | 10A — Board 2, Channel 1 (Pressure) |
| **27** | `RELAY_HUMIDIFIER` | 10A — Board 2, Channel 2 (Humidity) |
| **19** | Keypad Row 1 | |
| **18** | Keypad Row 2 | |
| **5** | Keypad Row 3 | |
| **4** | Keypad Row 4 | |
| **13** | Keypad Col 1 | |
| **14** | Keypad Col 2 | |
| **23** | Keypad Col 3 | |
| **33** | Keypad Col 4 | |

**I2C Addresses:**
- BME280 = `0x76` (code falls back to `0x77` automatically)
- SSD1306 OLED = `0x3C`

---

## FreeRTOS Dual-Core Architecture

| Core | Task | Responsibility |
|---|---|---|
| **Core 0** | `networkTask` | Wi-Fi reconnect loop + `client.loop()` (MQTT keepalive) |
| **Core 1** | `loop()` | Sensor read (every 5s) + relay logic + OLED update + keypad scan |

**Mutex:** `mqttMutex` (SemaphoreHandle_t) guards all `client.publish()` and `client.loop()` calls to prevent I2C/SPI bus collisions across cores.

---

## Relay Control Logic

All relays trigger on **Logic HIGH**. All three relay loops run simultaneously on Core 1 every 5 seconds.

### Compressor (30A — Temperature)

```cpp
#define RELAY_COMPRESSOR 25
const unsigned long COMPRESSOR_LOCKOUT_MS = 180000; // 3 minutes

if (temp > set_temperature + 1.5) {
    // Turn ON only if not already running AND lockout has expired
    if (!isCompressorRunning && (now - lastCompressorOffTime >= COMPRESSOR_LOCKOUT_MS)) {
        digitalWrite(RELAY_COMPRESSOR, HIGH);
        isCompressorRunning = true;
    }
} else if (temp <= set_temperature - 1.5) {
    // Turn OFF and start the 3-minute lockout timer
    if (isCompressorRunning) {
        digitalWrite(RELAY_COMPRESSOR, LOW);
        isCompressorRunning = false;
        lastCompressorOffTime = now;
    }
}
```

**Lockout Bypass:** When `set_temperature` changes via MQTT, bypass the lockout instantly:
```cpp
lastCompressorOffTime = millis() - COMPRESSOR_LOCKOUT_MS;
```

**Rule:** `COMPRESSOR_LOCKOUT_MS` must NEVER be reduced below `60000` (1 minute) without user approval.

### Vacuum Pump (10A — Pressure)

```cpp
#define RELAY_VACUUM 26
float pres_tol = set_pressure * 0.05; // ±5% of setpoint

if (pressure > set_pressure + pres_tol)  → digitalWrite(RELAY_VACUUM, HIGH)
if (pressure <= set_pressure - pres_tol) → digitalWrite(RELAY_VACUUM, LOW)
```

### Humidifier (10A — Humidity)

```cpp
#define RELAY_HUMIDIFIER 27
// ±5.0 absolute RH (not percentage of setpoint)

if (humidity < set_humidity - 5.0)  → digitalWrite(RELAY_HUMIDIFIER, HIGH)
if (humidity >= set_humidity + 5.0) → digitalWrite(RELAY_HUMIDIFIER, LOW)
```

---

## Settings Persistence (NVS)

Settings survive reboots via `Preferences` under namespace `"lettuvault"`:

| Key | Default | Description |
|---|---|---|
| `set_temp` | 25.0 | Target temperature (°C) |
| `set_hum` | 60.0 | Target humidity (% RH) |
| `set_pres` | 1013.25 | Target pressure (hPa) |

Settings are updated via the MQTT `lettuvault/control` topic.

---

## MQTT Communication

| Direction | Topic | Description |
|---|---|---|
| **Publishes** | `lettuvault/sensors` | Sensor data every 5 seconds |
| **Subscribes** | `lettuvault/control` | Receives system config updates from backend |

### Published Payload (every 5s)

```json
{
  "api_key": "lettuce-master-key-2024",
  "device_id": "ESP32-LettuVault-01",
  "temperature": 27.5,
  "humidity": 65.2,
  "pressure": 1013.25
}
```

### Received Config Payload

```json
{
  "tx_id": "abc123",
  "temperature": 15.0,
  "humidity": 80.0,
  "pressure": 1010.0
}
```

After receiving config, the ESP32 ACKs back to `lettuvault/ack`:
```json
{ "ack_id": "abc123" }
```

---

## OLED Display Layout

```
WIFI:OK  MQTT:OK
--- SETPOINTS ---
T:25.0C H:60.0%
P:1013.3hPa
--- HARDWARE ---
Comp: OFF
Vac:OFF Hum:OFF
```

---

## Configuration (main.cpp)

These must be edited before flashing:

```cpp
#define WIFI_SSID       "YourWiFi"
#define WIFI_PASSWORD   "YourPassword"
#define MQTT_SERVER     "192.168.X.X"   // Your PC's local IP on the same network
#define DEVICE_ID       "ESP32-LettuVault-01"
#define API_KEY         "lettuce-master-key-2024"  // Must match X_API_KEY in .env
```

**Rules:**
- These are `#define` macros — this is correct for embedded. Do NOT attempt to load them from `.env`.
- The ESP32 has no filesystem and cannot read the backend's `.env` at runtime.
- Serial baud rate is `115200`.

---

## Flashing

```powershell
# Build only
pio run

# Build and upload
pio run --target upload

# Open Serial Monitor
pio device monitor --baud 115200
```

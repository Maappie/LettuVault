# Backend — LettuVault

FastAPI web server, MQTT subscriber, local broker, and data gateway.

---

## Architecture

```text
lettu_backend/
├── main.py                 # FastAPI app + run_system() entry point
├── templates/
│   ├── dashboard.html      # Live 4-panel detection dashboard
│   └── simulator.html      # Hardware (ESP32) simulator for testing
├── core/
│   ├── config.py           # Reads .env: MQTT, DB URL, API Keys
│   └── security.py         # X-API-KEY + JWT authentication
├── models/
│   ├── database.py         # SQLAlchemy: ai_scans + sensor_readings tables
│   └── domain.py           # Pydantic: request/response schemas
├── services/
│   ├── broker_service.py   # Local MQTT Broker (amqtt @ 127.0.0.1:1883)
│   ├── mqtt/               # Modular MQTT Subsystem
│   │   ├── client.py       # Core paho-mqtt wrapper
│   │   ├── router.py       # Topic dispatcher & security guard
│   │   ├── rpc_manager.py  # Synchronous ACK management
│   │   └── handlers/       # Business logic (AI, Sensors)
│   └── log_hub.py          # VS Code TUI: 4-tab live log viewer
└── repository/
    └── scan_repo.py        # DataRepository: CRUD for ai_scans + sensor_readings
```

---

## API Endpoints

| Method | Route | Description | Auth |
|---|---|---|---|
| GET | `/` | Health check | None |
| GET | `/dashboard` | Live dashboard UI | None |
| GET | `/simulator` | Hardware simulator UI | None |
| GET | `/api/v1/ai-scans` | List all AI detections | X-API-KEY |
| POST | `/api/v1/ai-scans` | Submit new AI detection | X-API-KEY |
| GET | `/api/v1/sensor-readings` | List all sensor readings | X-API-KEY |
| POST | `/api/v1/sensor-readings` | Submit new sensor reading | X-API-KEY |

---

## Database Tables

### `ai_scans`
Stores data from the AI camera system.

| Column | Type | Description |
|---|---|---|
| `id` | Integer | Auto PK |
| `timestamp` | DateTime | Manila time (UTC+8) |
| `worm_count` | Integer | Number of worms detected |
| `confidence_score` | Float | YOLO confidence (0.0–1.0) |
| `image_name` | String | Frame identifier |
| `label` | String | e.g., `"1 lettuce, 2 worms"` |

### `sensor_readings`
Stores data from ESP32 hardware.

| Column | Type | Description |
|---|---|---|
| `id` | Integer | Auto PK |
| `timestamp` | DateTime | Manila time (UTC+8) |
| `temperature` | Float | Celsius |
| `humidity` | Float | Percent |
| `device_id` | String | ESP32 identifier |

---

## MQTT Topics

| Topic | Direction | Destination |
|---|---|---|
| `lettuvault/ai` | AI → Broker → Backend | `ai_scans` table |
| `lettuvault/sensors` | ESP32 → Broker → Backend | `sensor_readings` table |

---

## Running

```powershell
# Recommended: Full TUI
lettu_vault_start

# Backend only
python -m uvicorn lettu_backend.main:app --host 0.0.0.0 --port 8000

# Local MQTT Broker only
python -m lettu_backend.services.broker_service

# MQTT Subscriber only (Worker Mode)
python -m lettu_backend.services.mqtt
```
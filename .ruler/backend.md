# Backend Rules — LettuVault
# Package: lettu_backend
# Location: backend/src/lettu_backend/

---

## Directory Structure

```
backend/src/lettu_backend/
├── main.py              — FastAPI app, CORS, startup events, run_system()
├── core/
│   ├── config.py        — Settings (pydantic), PROJECT_ROOT, CAPTURES_DIR
│   └── security.py      — X-API-KEY validation + JWT
├── api/v1/
│   └── endpoints.py     — All API route handlers
├── models/
│   ├── database.py      — SQLAlchemy table definitions
│   └── domain.py        — Pydantic schemas (request/response)
├── repository/
│   └── scan_repo.py     — All CRUD logic (single access point to DB)
├── services/
│   ├── broker_service.py  — amqtt local MQTT broker @ 127.0.0.1:1883
│   ├── log_hub.py         — TUI launcher (4-tab live log viewer)
│   └── mqtt/              — Modular MQTT subsystem
└── templates/
    ├── dashboard.html     — Live 4-panel detection dashboard
    └── simulator.html     — Hardware simulator UI
```

---

## Project Root & Path Rules

The project root MUST always be resolved using `find_dotenv()`, never with `__file__` or `parents[N]`:

```python
# core/config.py — Single Source of Truth
dotenv_path = find_dotenv()
PROJECT_ROOT = os.path.dirname(dotenv_path) if dotenv_path else os.getcwd()
CAPTURES_DIR = os.path.join(PROJECT_ROOT, "data", "captures")
```

- **NEVER** hardcode `C:\Users\Renz\...` or any absolute OS path in Python code.
- Any file needing `PROJECT_ROOT` or `CAPTURES_DIR` MUST import it from `lettu_backend.core.config`.
- `data/lettu_vault.db` and `data/captures/` are always at the **project root**, never inside `backend/`.

---

## Settings & Environment

All runtime configuration comes from `.env` via the pydantic `Settings` class in `core/config.py`.

```python
class Settings(BaseSettings):
    PROJECT_NAME: str
    VERSION: str
    API_V1_STR: str = "/api/v1"          # Use this — never hardcode the string
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7
    X_API_KEY: str
    DATABASE_URL: str
    MQTT_BROKER: str
    MQTT_PORT: int
    MQTT_TOPIC_SENSORS: str
    MQTT_TOPIC_AI: str
    API_LOOPBACK_URL: str = "http://localhost:8000"
```

**Rules:**
- Use `settings.API_V1_STR` everywhere — NEVER hardcode `"/api/v1"`.
- Use `settings.API_LOOPBACK_URL` for internal loopback calls — never hardcode `localhost:8000`.
- Mount the router: `app.include_router(router, prefix=settings.API_V1_STR)`.

---

## Architecture Layer Rules

| Layer | File | Rule |
|---|---|---|
| **Config** | `core/config.py` | Single import point for all settings and paths |
| **Schema** | `models/domain.py` | All Pydantic request/response models defined here |
| **Table** | `models/database.py` | All SQLAlchemy ORM models defined here |
| **Repository** | `repository/scan_repo.py` | All DB CRUD goes here — never access `session` from endpoints |
| **Endpoint** | `api/v1/endpoints.py` | Calls repo only — no direct DB queries |
| **Service** | `services/mqtt/` | MQTT lifecycle, routing, RPC — never mixed into endpoints |

---

## MQTT Subsystem (services/mqtt/)

```
services/mqtt/
├── __init__.py       — Exports shared mqtt_service instance
├── client.py         — paho-mqtt lifecycle, reconnect, dual-mode
├── router.py         — Topic dispatcher + API-key security guard
├── rpc_manager.py    — threading.Event() for synchronous ACK blocking
├── api_client.py     — Loopback POSTs to FastAPI endpoints
└── handlers/
    ├── ai_handler.py      — Base64 decode, 10s debounce, snapshot save
    └── sensor_handler.py  — BME280 payload parse and post
```

**Dual Mode:**
- **API Mode** (`is_subscriber = False`): Runs inside FastAPI process. Send-only. Set at startup in `main.py`.
- **Worker Mode** (`is_subscriber = True`): Standalone subscriber. Run via `python -m lettu_backend.services.mqtt`.

**Loopback URL rule:** Always build URLs as:
```python
f"{settings.API_LOOPBACK_URL}{settings.API_V1_STR}/{endpoint}"
```

**Snapshot Rule:** AI images are always saved to `CAPTURES_DIR` imported from `core/config.py`. Never compute the path locally.

---

## API Endpoints

| Method | Route | Description | Auth |
|---|---|---|---|
| GET | `/` | Health check | None |
| GET | `/dashboard` | Live dashboard UI | None |
| GET | `/simulator` | Hardware simulator UI | None |
| POST | `/api/v1/trigger-produce-scan` | Trigger AI produce scan via MQTT | X-API-KEY |
| GET | `/api/v1/ai-scans` | List all AI detections | X-API-KEY |
| POST | `/api/v1/ai-scans` | Submit new AI detection | X-API-KEY |
| GET | `/api/v1/sensor-readings` | List all sensor readings | X-API-KEY |
| POST | `/api/v1/sensor-readings` | Submit new sensor reading | X-API-KEY |
| GET | `/api/v1/system-config` | Get current system configuration | X-API-KEY |
| POST | `/api/v1/system-config` | Update system configuration | X-API-KEY |
| GET | `/api/v1/internal-environment` | List internal environment readings | X-API-KEY |

---

## Database Rules

- **Active DB:** `data/lettu_vault.db` at project root (configured in `.env` as `DATABASE_URL`)
- **Tables:** `ai_scans`, `sensor_readings`, `internal_environment_readings`, `system_config`
- **Timestamps:** Always stored as Manila time (UTC+8)
- **Migrations workflow:**
  1. Edit `models/database.py`
  2. `db-migrate "describe the change"`
  3. `db-upgrade`
- **Never** write raw SQL or access `session` outside of `scan_repo.py` and `database.py`.

---

## Security

- **ESP32 / Hardware:** `X-API-KEY` header (set in `.env`)
- **Mobile App:** JWT Bearer Token (OAuth2 Password Bearer, 7-day expiry, bcrypt passwords)
- **CORS:** Configured to allow all origins (for Flutter compatibility)
- **MQTT:** Anonymous for local dev. Add `username_pw_set()` for production.

---

## Running

```powershell
# Full system (recommended)
lettu_vault_start

# Backend only
python -m uvicorn lettu_backend.main:app --host 0.0.0.0 --port 8000

# MQTT Broker only
python -m lettu_backend.services.broker_service

# MQTT Subscriber only
python -m lettu_backend.services.mqtt
```

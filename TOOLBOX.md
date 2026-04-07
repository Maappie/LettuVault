# LettuVault Script Toolbox

This document lists all custom command-line shortcuts for development.

---

## Prerequisites

Virtual environment MUST be active:

```powershell
.\.venv\Scripts\Activate.ps1
```

---

## System Commands

| Command | What it does |
|---|---|
| `lettu_vault_start` | Starts ALL services: Broker, Backend, MQTT, AI — in a live TUI |

---

## Database Commands (Alembic)

Use these when you change `database.py`:

| Command | Action | When |
|---|---|---|
| `db-migrate "message"` | Creates a migration file | After editing `database.py` |
| `db-upgrade` | Applies migrations to DB | After generating |
| `db-history` | Shows all past changes | For auditing |
| `db-status` | Shows current DB version | Troubleshooting |

---

## Database Utilities

```powershell
python verify_data.py    # Count records in each table
python clear_db.py       # Wipe ALL data (keeps structure)
```

---

## Individual Services (Advanced)

Run a single service manually for debugging:

```powershell
# Backend only
python -m uvicorn lettu_backend.main:app --host 0.0.0.0 --port 8000

# Local MQTT Broker only
python -m lettu_backend.services.broker_service

# MQTT Subscriber only
python -m lettu_backend.services.mqtt

# AI Camera only
python -m lettu_vault_ai.predict
```

---

## Where are these defined?

- **Script names**: Root `pyproject.toml` under `[project.scripts]`
- **`lettu_vault_start` logic**: `backend/src/lettu_backend/services/log_hub.py`
- **DB commands**: Bottom of `backend/src/lettu_backend/main.py`

---

## AI Sensitivity (Confidence Threshold)

Edit this line in `ai_system/src/lettu_vault_ai/predict.py`:

```python
CONFIDENCE_THRESHOLD = 0.2  # 0.0 = detect everything, 1.0 = very strict
```

## MQTT Settings

Edit `MQTT_*` values in `.env`:

```bash
MQTT_BROKER="127.0.0.1"          # Local broker (change for production)
MQTT_PORT=1883
MQTT_TOPIC_SENSORS="lettuvault/sensors"
MQTT_TOPIC_AI="lettuvault/ai"
```

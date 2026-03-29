# LettuVault — Project Root

## 📂 Current Structure

```text
LettuVault/                     <-- Root Folder (The Workspace)
├── .venv/                      <-- Python Virtual Environment
├── pyproject.toml              <-- Root Workspace Config (Maps packages)
├── requirements.txt            <-- Master Dependencies List
├── .env                        <-- Secret config (NEVER commit to Git!)
├── .gitignore                  <-- Git ignore rules
│
├── ai_system/                  <-- AI Worker (Package: lettu_vault_ai)
│   ├── pyproject.toml
│   ├── runs/lettuce_strawberry_v12/weights/best.pt  <-- Trained YOLO Model
│   ├── datasets/               <-- data.yaml and training images
│   └── src/lettu_vault_ai/
│       ├── predict.py          <-- MAIN: Camera + YOLO + MQTT Publisher
│       └── __init__.py
│
├── backend/                    <-- Web Server (Package: lettu_backend)
│   └── src/lettu_backend/
│       ├── main.py             <-- FastAPI entry + run_system() launcher
│       ├── api/
│       │   └── v1/
│       │       └── endpoints.py <-- MAIN: REST API Routes (CRUD logic)
│       ├── core/
│       │   ├── config.py       <-- Reads from .env (MQTT, DB, API Keys)
│       │   └── security.py     <-- API Key & JWT auth
│       ├── models/
│       │   ├── database.py     <-- SQLAlchemy: ai_scans + sensor_readings
│       │   └── domain.py       <-- Pydantic: Request/Response schemas
│       ├── services/
│       │   ├── broker_service.py   # Local MQTT Broker (127.0.0.1:1883)
│       │   ├── mqtt/               # Modular MQTT Subsystem (Subscribers)
│       │   └── log_hub.py          # VS Code TUI (j/k log switcher)
│       ├── repository/
│       │   └── scan_repo.py    <-- DataRepository (ai_scans + sensor_readings CRUD)
│       ├── schemas/
│       │   └── __init__.py     <-- Input validators (Pydantic, equiv. of Zod schemas)
│       └── templates/
│           ├── dashboard.html  <-- Live data dashboard (4 panels)
│           └── simulator.html  <-- Hardware simulator
│
├── embedded/                   <-- ESP32 Source Code (Work in progress)
├── mobile/                     <-- Flutter Source Code (Work in progress)
│
├── data/lettu_vault.db         <-- SQLite Database (auto-created)
├── clear_db.py                 <-- Utility: Wipe all records from DB
└── verify_data.py              <-- Utility: Count records in each table
```

---

## Architecture

```
.env (single source of config)
    │
    ▼
[lettu_vault_start]
    │
    ▼
[Log Hub TUI] ─── starts ──► [broker_service.py] → MQTT Broker @ 127.0.0.1:1883
    │                                                       │
    ├── starts (after 4s) ──► [main.py / uvicorn]          │ (message hub)
    │                          FastAPI @ :8000              │
    │                          + mqtt module ◄──────────────┤ (subscribes)
    │                            ├── lettuvault/ai          │
    │                            └── lettuvault/sensors     │
    │                                                       │
    └── starts ──────────────► [predict.py]   ─────────────┘
                               AI Camera              (publishes)
                               + YOLO Model
```

---

## Setup

```powershell
# 1. Create and activate virtual environment
python -m venv .venv
.\.venv\Scripts\Activate.ps1

# 2. Install all dependencies
pip install -r requirements.txt

# 3. Run database migrations (first time only)
db-upgrade
```

---

## Running the System

```powershell
lettu_vault_start
```

This opens a **TUI** in your VS Code terminal with 4 tabs:
- **BROKER** (Yellow): Local MQTT server on `127.0.0.1:1883`
- **BACKEND** (Green): FastAPI server on `http://localhost:8000`
- **MQTT** (Cyan): Subscriber routing data to the database
- **AI** (Magenta): Camera + YOLO detections with 3s stability check

**Controls**: `j` (next tab) | `k` (prev tab) | `q` (quit all)

---

## 🛡️ Validation & Contracts (Schemas)

The system uses **Pydantic Schemas** (located in `backend/src/lettu_backend/schemas/`) as a strict validation layer for all inbound data. This is equivalent to Zod in the Next.js ecosystem.

| Schema | Validations |
|---|---|
| **Sensor Data** | Temperature (-20 to 80°C), Humidity (0-100%), Pressure (800-1200 hPa). |
| **Produce Type** | Strict Allowlist: `Lettuce`, `Strawberry`, `Empty / Unknown`, `Camera Test`. |
| **System Config** | Sane setpoint guards to prevent hardware damage from extreme temperature/humidity requests. |
| **Security** | Sanitizes strings to prevent XSS (Script Injection) and SQL Injection patterns. |

Inbound requests that fail these rules are automatically rejected by FastAPI with a `422 Unprocessable Entity` error before they reach the database.

---

## Quick Links

| Page | URL |
|---|---|
| API Health | http://127.0.0.1:8000/ |
| Live Dashboard | http://127.0.0.1:8000/dashboard |
| Swagger API Docs | http://127.0.0.1:8000/docs |
| Hardware Simulator | http://127.0.0.1:8000/simulator |

---

## Utility Scripts

```powershell
python verify_data.py    # Check how many records are in the DB
python clear_db.py       # Wipe all records (keeps table structure)
```

# 📂 LettuVault Backend Architecture

```text
lettu_backend/
├── 🚀 main.py              # Entry point: FastAPI app initialization
├── static/                 # CSS, JS, Images (e.g., box_diagram.png)
├── templates/              # HTML files (e.g., dashboard.html)
├── 🌐 api/                 # THE INTERFACE: Routes and Controllers
│   └── v1/                 # Versioned API
│       ├── endpoints.py    # URL routes (e.g., GET /scan)
│       ├── dependencies.py # Shared logic (DB sessions, Auth)
|       └── web_routes.py   # Routes that return HTML
├── 🧠 core/                # THE BRAIN: Business Rules
│   ├── config.py           # Environment variables (.env)
│   └── security.py         # API keys & Auth logic
├── 📊 models/              # THE DATA: Schemas
│   ├── domain.py           # Pydantic models (Request/Response)
│   └── database.py         # ORM models (SQLAlchemy/Tortoise)
├── ⚙️ services/            # THE GLUE: External Integrations
│   ├── ai_service.py       # Wrapper for lettu_vault_ai
│   └── mqtt_service.py     # ESP32 / IoT communication
└── 🗄️ repository/          # THE VAULT: Database Queries
    └── scan_repo.py        # CRUD operations for scan history
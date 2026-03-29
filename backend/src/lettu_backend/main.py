from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import pathlib
import os

from lettu_backend.core.config import settings
from lettu_backend.api.v1.endpoints import router as api_v1_router
from lettu_backend.services.mqtt import mqtt_service

# 📂 Set up templates directory
template_dir = pathlib.Path(__file__).parent.resolve() / "templates"
templates = Jinja2Templates(directory=str(template_dir))

# 🛠️ Root FastAPI Application
app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Relational data gateway for LettuVault AI and IoT Sensors.",
    version=settings.VERSION
)

# 🚀 Mount Versioned API Router
app.include_router(api_v1_router, prefix=settings.API_V1_STR)

# 📸 Serve AI snapshot images from explicitly defined CAPTURES_DIR
from lettu_backend.core.config import CAPTURES_DIR
os.makedirs(CAPTURES_DIR, exist_ok=True)
app.mount("/captures", StaticFiles(directory=CAPTURES_DIR), name="captures")

@app.on_event("startup")
def startup_event():
    # Ensure tables are created (especially important after refactoring)
    from lettu_backend.models.database import Base, engine
    Base.metadata.create_all(bind=engine)
    
    # Enable Send-Only mode for the API server (Prevents duplicate row bugs)
    mqtt_service.is_subscriber = False
    mqtt_service.start()

# 🔒 CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/", tags=["UI"])
async def root():
    return {"message": "LettuVault API Multi-Table Gateway", "status": "Online"}

@app.get("/dashboard", response_class=HTMLResponse, tags=["UI"])
async def data_dashboard(request: Request):
    return templates.TemplateResponse(
        request=request, 
        name="dashboard.html", 
        context={"project_name": settings.PROJECT_NAME, "x_api_key": settings.X_API_KEY}
    )

@app.get("/simulator", response_class=HTMLResponse, tags=["UI"])
async def hardware_simulator(request: Request):
    return templates.TemplateResponse(
        request=request, 
        name="simulator.html", 
        context={"project_name": settings.PROJECT_NAME, "x_api_key": settings.X_API_KEY}
    )

# --- Shortcuts for Command Line Interaction ---
def run_upgrade():
    import subprocess, sys
    subprocess.run([sys.executable, "-m", "alembic", "-c", "backend/alembic.ini", "upgrade", "head"])

def run_system():
    """Unified TUI Launcher with log switching."""
    from lettu_backend.services.log_hub import launch_hub
    launch_hub()

def run_db_clear():
    """Clears all transactional data tables without deleting the DB file."""
    import sqlite3
    import os
    from lettu_backend.core.config import PROJECT_ROOT
    
    db_path = os.path.join(PROJECT_ROOT, "data", "lettu_vault.db")
    if not os.path.exists(db_path):
        print(f"❌ Database not found at {db_path}")
        return

    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        tables = [
            ("AI Condition Scans", "ai_condition_scans"),
            ("AI Produce Scans", "ai_produce_scans"),
            ("System Config logs", "system_config"),
            ("Internal Environment Readings", "internal_environment_readings")
        ]

        for name, table in tables:
            try:
                cursor.execute(f"DELETE FROM {table}")
                print(f"🧹 Clearing {name}...")
            except sqlite3.OperationalError as e:
                print(f"⚪ Skipping {name} ({e})")

        conn.commit()
        conn.close()
        print("✅ Database cleanup finished!")
    except Exception as e:
        print(f"❌ Error during clear: {e}")

def run_migration():
    """Generates a new migration script."""
    import subprocess, sys
    msg = sys.argv[1] if len(sys.argv) > 1 else "manual_update"
    subprocess.run([sys.executable, "-m", "alembic", "-c", "backend/alembic.ini", "revision", "--autogenerate", "-m", msg])

def run_history():
    """Shows database migration history."""
    import subprocess, sys
    subprocess.run([sys.executable, "-m", "alembic", "-c", "backend/alembic.ini", "history"])

def run_status():
    """Shows current database migration status."""
    import subprocess, sys
    subprocess.run([sys.executable, "-m", "alembic", "-c", "backend/alembic.ini", "current"])

from fastapi import FastAPI, Depends, Security, HTTPException, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
import os
import pathlib

from lettu_backend.core.config import settings
from lettu_backend.core.security import get_current_active_device
from lettu_backend.models.database import SessionLocal, AIScan, SensorReading
from lettu_backend.models.domain import (
    AIScanResponse, AIScanCreate, 
    SensorReadingResponse, SensorReadingCreate
)
from lettu_backend.repository.scan_repo import DataRepository
from lettu_backend.services.mqtt_service import mqtt_service
from sqlalchemy import inspect

# 📂 Set up templates directory
template_dir = pathlib.Path(__file__).parent.resolve() / "templates"
templates = Jinja2Templates(directory=str(template_dir))

# 🛠️ Database Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# 🛠️ Root FastAPI Application
app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Relational data gateway for LettuVault AI and IoT Sensors.",
    version=settings.VERSION
)

@app.on_event("startup")
def startup_event():
    mqtt_service.start()

# 🔒 CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/", tags=["System Health"])
async def root():
    return {"message": "LettuVault API Multi-Table Gateway", "status": "Online"}

@app.get("/dashboard", response_class=HTMLResponse, tags=["UI"])
async def data_dashboard(request: Request):
    return templates.TemplateResponse(request=request, name="dashboard.html", context={"project_name": settings.PROJECT_NAME})

@app.get("/simulator", response_class=HTMLResponse, tags=["UI"])
async def hardware_simulator(request: Request):
    return templates.TemplateResponse(request=request, name="simulator.html", context={"project_name": settings.PROJECT_NAME, "x_api_key": settings.X_API_KEY})

# --- 🧠 AI SCAN ENDPOINTS ---
@app.get("/api/v1/ai-scans", response_model=list[AIScanResponse], tags=["AI Intelligence"], dependencies=[Depends(get_current_active_device)])
def get_ai_scans(db: Session = Depends(get_db)):
    repo = DataRepository(db)
    return repo.get_all_ai_scans()

@app.post("/api/v1/ai-scans", response_model=AIScanResponse, tags=["AI Intelligence"], dependencies=[Depends(get_current_active_device)])
def create_ai_scan(scan_in: AIScanCreate, db: Session = Depends(get_db)):
    repo = DataRepository(db)
    return repo.create_ai_scan(scan_in.model_dump())

# --- 📡 SENSOR DATA ENDPOINTS ---
@app.get("/api/v1/sensor-readings", response_model=list[SensorReadingResponse], tags=["Hardware Sensors"], dependencies=[Depends(get_current_active_device)])
def get_sensor_readings(db: Session = Depends(get_db)):
    repo = DataRepository(db)
    return repo.get_all_sensor_readings()

@app.post("/api/v1/sensor-readings", response_model=SensorReadingResponse, tags=["Hardware Sensors"], dependencies=[Depends(get_current_active_device)])
def create_sensor_reading(reading_in: SensorReadingCreate, db: Session = Depends(get_db)):
    repo = DataRepository(db)
    return repo.create_sensor_reading(reading_in.model_dump())

# --- Shortcuts for database management ---
def run_migration():
    import subprocess, sys, pathlib
    pathlib.Path("data").mkdir(exist_ok=True)
    desc = sys.argv[1] if len(sys.argv) > 1 else "split_tables"
    subprocess.run([sys.executable, "-m", "alembic", "-c", "backend/alembic.ini", "revision", "--autogenerate", "-m", desc])

def run_upgrade():
    import subprocess, sys, pathlib
    pathlib.Path("data").mkdir(exist_ok=True)
    subprocess.run([sys.executable, "-m", "alembic", "-c", "backend/alembic.ini", "upgrade", "head"])

def run_system():
    """Unified TUI Launcher with log switching."""
    from lettu_backend.services.log_hub import launch_hub
    launch_hub()

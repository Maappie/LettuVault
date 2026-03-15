from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from lettu_backend.core.config import settings
from lettu_backend.core.security import get_current_active_device
from lettu_backend.models.database import SessionLocal
from lettu_backend.models.domain import (
    AIScanResponse, AIScanCreate, 
    SensorReadingResponse, SensorReadingCreate,
    SystemConfigResponse, SystemConfigCreate
)
from lettu_backend.repository.scan_repo import DataRepository

router = APIRouter(tags=["v1 API"])

# 🛠️ Database Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# --- 🧠 AI SCAN ENDPOINTS ---
@router.get("/ai-scans", response_model=list[AIScanResponse], dependencies=[Depends(get_current_active_device)])
def get_ai_scans(db: Session = Depends(get_db)):
    repo = DataRepository(db)
    return repo.get_all_ai_scans()

@router.post("/ai-scans", response_model=AIScanResponse, dependencies=[Depends(get_current_active_device)])
def create_ai_scan(scan_in: AIScanCreate, db: Session = Depends(get_db)):
    repo = DataRepository(db)
    return repo.create_ai_scan(scan_in.model_dump())

# --- 📡 SENSOR DATA ENDPOINTS ---
@router.get("/sensor-readings", response_model=list[SensorReadingResponse], dependencies=[Depends(get_current_active_device)])
def get_sensor_readings(db: Session = Depends(get_db)):
    repo = DataRepository(db)
    return repo.get_all_sensor_readings()

@router.post("/sensor-readings", response_model=SensorReadingResponse, dependencies=[Depends(get_current_active_device)])
def create_sensor_reading(reading_in: SensorReadingCreate, db: Session = Depends(get_db)):
    repo = DataRepository(db)
    return repo.create_sensor_reading(reading_in.model_dump())

# --- ⚙️ SYSTEM CONFIG ENDPOINTS ---
@router.get("/system_config", response_model=list[SystemConfigResponse], dependencies=[Depends(get_current_active_device)])
def get_system_configs(db: Session = Depends(get_db)):
    repo = DataRepository(db)
    return repo.get_all_system_configs()

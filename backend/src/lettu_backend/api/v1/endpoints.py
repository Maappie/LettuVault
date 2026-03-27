from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from lettu_backend.core.config import settings
from lettu_backend.core.security import get_current_active_device
from lettu_backend.models.database import SessionLocal
from lettu_backend.models.domain import (
    AIConditionResponse, AIProduceResponse,
    SensorReadingResponse, SensorReadingCreate,
    SystemConfigResponse, SystemConfigCreate,
    InternalEnvironmentReadingResponse, InternalEnvironmentReadingCreate
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
@router.get("/ai-scans/condition", response_model=list[AIConditionResponse], dependencies=[Depends(get_current_active_device)])
def get_condition_scans(db: Session = Depends(get_db)):
    repo = DataRepository(db)
    return repo.get_all_condition_scans()

@router.get("/ai-scans/produce", response_model=list[AIProduceResponse], dependencies=[Depends(get_current_active_device)])
def get_produce_scans(db: Session = Depends(get_db)):
    repo = DataRepository(db)
    return repo.get_all_produce_scans()

@router.post("/ai-scans", dependencies=[Depends(get_current_active_device)])
def create_ai_scan(scan_in: dict, db: Session = Depends(get_db)):
    # Generic endpoint for manual posts, routes based on content
    repo = DataRepository(db)
    if "produce_type" in scan_in:
        response = repo.create_produce_scan(scan_in)
        
        # --- AI DETECTION: Standard Environment Override ---
        # Checks if we should auto-apply environmental standards based on AI detection
        from lettu_backend.core.constants import PRODUCE_CONFIGS
        produce_type = scan_in.get("produce_type", "").lower()
        
        if produce_type in PRODUCE_CONFIGS:
            # We instantly force the baseline system config whenever a standard crop is detected
            config_data = PRODUCE_CONFIGS[produce_type].copy()
            
            from lettu_backend.services.mqtt import mqtt_service
            success = mqtt_service.send_config_with_ack(config_data.copy(), max_retries=1, timeout=2.0)
            
            if success:
                # Log it into the actual config table so it persists in the frontend
                repo.create_system_config(config_data)

        return response
    return repo.create_condition_scan(scan_in)

@router.post("/trigger-produce-scan", dependencies=[Depends(get_current_active_device)])
def trigger_produce_scan():
    """Tells the AI system to wake up and look for a new produce via MQTT."""
    from lettu_backend.services.mqtt import mqtt_service
    # Send primitive string command instead of JSON config
    mqtt_service.send_command("TRIGGER_PRODUCE_SCAN")
    return {"message": "Produce scan triggered"}

# --- 📡 SENSOR DATA ENDPOINTS ---
@router.get("/sensor-readings", response_model=list[SensorReadingResponse], dependencies=[Depends(get_current_active_device)])
def get_sensor_readings(db: Session = Depends(get_db)):
    repo = DataRepository(db)
    return repo.get_all_sensor_readings()

@router.post("/sensor-readings", response_model=SensorReadingResponse, dependencies=[Depends(get_current_active_device)])
def create_sensor_reading(reading_in: SensorReadingCreate, db: Session = Depends(get_db)):
    repo = DataRepository(db)
    return repo.create_sensor_reading(reading_in.model_dump())

# --- ⚙️ SYSTEM CONFIGURATION ENDPOINTS (Desired Environment Settings) ---
@router.get("/system_config", response_model=list[SystemConfigResponse], dependencies=[Depends(get_current_active_device)])
def get_system_configs(db: Session = Depends(get_db)):
    repo = DataRepository(db)
    return repo.get_all_system_configs()

@router.post("/system_config", response_model=SystemConfigResponse, dependencies=[Depends(get_current_active_device)])
def create_system_config(config_in: SystemConfigCreate, db: Session = Depends(get_db)):
    repo = DataRepository(db)
    
    from lettu_backend.services.mqtt import mqtt_service
    
    # Forward the provided settings to the ESP32 via MQTT with ACK
    payload = {k: v for k, v in config_in.model_dump().items() if v is not None}
    
    if payload:
        success = mqtt_service.send_config_with_ack(payload, max_retries=3, timeout=3.0)
        if not success:
            raise HTTPException(
                status_code=503, 
                detail="ESP32 did not acknowledge the configuration update. Backend update aborted."
            )
        esp32_status = "ESP32 received"
    else:
        raise HTTPException(status_code=400, detail="Empty configuration payload")
        
    db_result = repo.create_system_config(config_in.model_dump())
    
    # Construct response dictionary
    return {
        "id": db_result.id,
        "timestamp": db_result.timestamp,
        "temperature": db_result.temperature,
        "humidity": db_result.humidity,
        "pressure": db_result.pressure,
        "esp32_status": esp32_status
    }

@router.post("/trigger-produce-scan", dependencies=[Depends(get_current_active_device)])
def trigger_produce_scan():
    from lettu_backend.services.mqtt_service import mqtt_service
    # Send a command to the AI system to do a one-time check for Lettuce/Strawberry
    mqtt_service.send_command("TRIGGER_PRODUCE_SCAN")
    return {"status": "Command sent"}

# --- 🌡️ INTERNAL ENVIRONMENT ENDPOINTS ---
@router.get("/internal-environment", response_model=list[InternalEnvironmentReadingResponse], dependencies=[Depends(get_current_active_device)])
def get_internal_environment_readings(db: Session = Depends(get_db)):
    repo = DataRepository(db)
    return repo.get_all_internal_environment_readings()

@router.post("/internal-environment", response_model=InternalEnvironmentReadingResponse, dependencies=[Depends(get_current_active_device)])
def create_internal_environment_reading(reading_in: InternalEnvironmentReadingCreate, db: Session = Depends(get_db)):
    repo = DataRepository(db)
    return repo.create_internal_environment_reading(reading_in.model_dump())

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from lettu_backend.core.config import settings
from lettu_backend.core.security import get_current_active_device
from lettu_backend.models.database import SessionLocal
from lettu_backend.models.domain import (
    AIConditionResponse, AIProduceResponse,
    SystemConfigResponse,
    InternalEnvironmentReadingResponse
)
from lettu_backend.schemas import (
    SystemConfigCreateSchema,
    InternalEnvironmentCreateSchema
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

    # 🧹 Strip routing metadata — not stored in the DB
    scan_in.pop("scan_type", None)

    if "produce_type" in scan_in:
        response = repo.create_produce_scan(scan_in)
        
        # --- AI DETECTION: Standard Environment Override ---
        from lettu_backend.core.constants import PRODUCE_CONFIGS
        produce_type = scan_in.get("produce_type", "").lower()
        
        if produce_type in PRODUCE_CONFIGS:
            config_data = PRODUCE_CONFIGS[produce_type].copy()
            
            if settings.REQUIRE_ESP32_ACK:
                from lettu_backend.services.mqtt import mqtt_service
                success = mqtt_service.send_config_with_ack(config_data.copy(), max_retries=1, timeout=2.0)
                if success:
                    repo.create_system_config(config_data)
            else:
                # Bypass ACK — save directly (no ESP32 connected)
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

@router.post("/test-camera", dependencies=[Depends(get_current_active_device)])
def test_camera():
    """Forces the AI to take a raw snapshot and upload it."""
    from lettu_backend.services.mqtt import mqtt_service
    mqtt_service.send_command("FORCE_TEST_CAPTURE")
    return {"message": "Test capture triggered"}

# --- ⚙️ SYSTEM CONFIGURATION ENDPOINTS (Desired Environment Settings) ---
@router.get("/system_config", response_model=list[SystemConfigResponse], dependencies=[Depends(get_current_active_device)])
def get_system_configs(db: Session = Depends(get_db)):
    repo = DataRepository(db)
    return repo.get_all_system_configs()

@router.post("/system_config", response_model=SystemConfigResponse, dependencies=[Depends(get_current_active_device)])
def create_system_config(config_in: SystemConfigCreateSchema, db: Session = Depends(get_db)):
    repo = DataRepository(db)
    
    # Forward the provided settings to the ESP32 via MQTT with ACK
    payload = {k: v for k, v in config_in.model_dump().items() if v is not None}
    
    if not payload:
        raise HTTPException(status_code=400, detail="Empty configuration payload")
    
    if settings.REQUIRE_ESP32_ACK:
        from lettu_backend.services.mqtt import mqtt_service
        success = mqtt_service.send_config_with_ack(payload, max_retries=3, timeout=3.0)
        if not success:
            raise HTTPException(
                status_code=503, 
                detail="ESP32 did not acknowledge the configuration update. Backend update aborted."
            )
        esp32_status = "ESP32 received"
    else:
        # Bypass ACK — save directly (no ESP32 connected)
        esp32_status = "Saved (ACK bypassed — no hardware)"
        
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

# --- 🌡️ INTERNAL ENVIRONMENT ENDPOINTS ---
@router.get("/internal-environment", response_model=list[InternalEnvironmentReadingResponse], dependencies=[Depends(get_current_active_device)])
def get_internal_environment_readings(db: Session = Depends(get_db)):
    repo = DataRepository(db)
    return repo.get_all_internal_environment_readings()

@router.post("/internal-environment", response_model=InternalEnvironmentReadingResponse, dependencies=[Depends(get_current_active_device)])
def create_internal_environment_reading(reading_in: InternalEnvironmentCreateSchema, db: Session = Depends(get_db)):
    repo = DataRepository(db)
    return repo.create_internal_environment_reading(reading_in.model_dump())

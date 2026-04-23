from fastapi import APIRouter, Depends, HTTPException, Request
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
def get_condition_scans(request: Request, db: Session = Depends(get_db)):
    repo = DataRepository(db)
    scans = repo.get_all_condition_scans()
    base_url = str(request.base_url).rstrip("/")
    for s in scans:
        if s.image and not s.image.startswith("http"):
            # Ensure path is captures/filename
            img = s.image.lstrip("/")
            if not img.startswith("captures/"): img = f"captures/{img}"
            s.image = f"{base_url}/{img}"
    return scans

@router.get("/ai-scans/produce", response_model=list[AIProduceResponse], dependencies=[Depends(get_current_active_device)])
def get_produce_scans(request: Request, db: Session = Depends(get_db)):
    repo = DataRepository(db)
    scans = repo.get_all_produce_scans()
    base_url = str(request.base_url).rstrip("/")
    for s in scans:
        if s.image and not s.image.startswith("http"):
            # Ensure path is captures/filename
            img = s.image.lstrip("/")
            if not img.startswith("captures/"): img = f"captures/{img}"
            s.image = f"{base_url}/{img}"
    return scans

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

@router.post("/system-off", dependencies=[Depends(get_current_active_device)])
def system_off(db: Session = Depends(get_db)):
    """Puts the ESP32 into standby mode — all relays OFF, telemetry paused."""
    from lettu_backend.services.mqtt import mqtt_service
    import json

    payload = {"system_off": True}

    if settings.REQUIRE_ESP32_ACK:
        success = mqtt_service.send_config_with_ack(payload, max_retries=1, timeout=2.0)
        esp32_status = "ESP32 in standby" if success else "ESP32 unreachable"
    else:
        # Bypass ACK — just publish directly
        mqtt_service.client.publish("lettuvault/control", json.dumps(payload))
        esp32_status = "Standby sent (ACK bypassed)"

    # Save a null-config row so the dashboard shows no targets
    repo = DataRepository(db)
    repo.create_system_config({})

    return {"message": "System entering standby", "esp32_status": esp32_status}

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
        # Bypass ACK — just publish directly
        from lettu_backend.services.mqtt import mqtt_service
        import json
        mqtt_service.client.publish("lettuvault/control", json.dumps(payload))
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


# --- 👤 USER IDENTITY ENDPOINT ---
from pydantic import BaseModel as _BaseModel
from lettu_backend.core.config import PROJECT_ROOT
import re as _re, pathlib as _pathlib

class _IdentityPayload(_BaseModel):
    email: str

@router.post("/identity", dependencies=[Depends(get_current_active_device)])
def save_user_identity(payload: _IdentityPayload, db: Session = Depends(get_db)):
    """
    Called by the mobile app after successful cloud auth.
    1. Saves the user email into the system_config table (most recent row).
    2. Writes VAULT_USER_EMAIL to the project .env so sync_engine.py picks it up.
    """
    repo = DataRepository(db)
    repo.save_user_email(payload.email)

    # Persist to .env file so sync_engine reads it on next cycle
    env_path = _pathlib.Path(PROJECT_ROOT) / ".env"
    try:
        content = env_path.read_text(encoding="utf-8")
        if "VAULT_USER_EMAIL" in content:
            content = _re.sub(
                r"^VAULT_USER_EMAIL=.*",
                f"VAULT_USER_EMAIL={payload.email}",
                content, flags=_re.MULTILINE
            )
        else:
            content += f"\nVAULT_USER_EMAIL={payload.email}\n"
        env_path.write_text(content, encoding="utf-8")
    except Exception as e:
        import logging; logging.getLogger("identity").warning(f"Could not write .env: {e}")

    return {"ok": True, "email": payload.email}


# --- 📡 HOME WIFI CONNECT ENDPOINT ---
import subprocess as _subprocess, socket as _socket, asyncio as _asyncio
from fastapi import BackgroundTasks

class _WifiPayload(_BaseModel):
    ssid: str
    password: str

@router.post("/connect-home-wifi", dependencies=[Depends(get_current_active_device)])
def connect_home_wifi(payload: _WifiPayload):
    """
    Commands the Pi to connect its USB WiFi adapter (wlan1) to the given home router.
    Blocks until connected (max 20s) then tests internet connectivity.
    """
    ssid     = payload.ssid.strip()
    password = payload.password

    # --- DEV OVERRIDE (For Laptop Testing) ---
    if not settings.IS_PRODUCTION:
        import logging; logging.getLogger("wifi").info(f"[DEV] Mocking WiFi connection to {ssid}")
        return {"success": True, "ssid": ssid, "note": "Dev Mock"}

    # Step 1: Connect wlan1 to the home router using nmcli
    connect_result = _subprocess.run(
        ["nmcli", "dev", "wifi", "connect", ssid,
         "password", password, "ifname", "wlan1"],
        capture_output=True, text=True, timeout=25,
    )
    if connect_result.returncode != 0:
        err = connect_result.stderr.strip() or connect_result.stdout.strip()
        # Translate nmcli errors to user-friendly messages
        if "No network with SSID" in err:
            detail = "That Wi-Fi network was not found. Make sure the name is correct."
        elif "Secrets were required" in err or "password" in err.lower():
            detail = "Wrong password. Please check and try again."
        elif "already connected" in err.lower():
            detail = None  # Already connected — proceed to internet test
        else:
            detail = "Could not connect to your home Wi-Fi. Please try again."
        if detail:
            raise HTTPException(status_code=422, detail=detail)

    # Step 2: Internet connectivity test
    try:
        sock = _socket.create_connection(("8.8.8.8", 53), timeout=5)
        sock.close()
        internet_ok = True
    except OSError:
        internet_ok = False

    if not internet_ok:
        raise HTTPException(
            status_code=503,
            detail="Connected to your Wi-Fi, but no internet was detected. Check your router."
        )

    return {"success": True, "ssid": ssid}


# --- 🛡️ IOT CLOUD AUTH PROXY ---

import requests as _requests

class _AuthProxyPayload(_BaseModel):
    email: str
    password: str
    cloud_auth_url: str  # The full URL to the cloud server's login or signup endpoint
    
@router.post("/proxy-auth", dependencies=[Depends(get_current_active_device)])
def proxy_cloud_authentication(payload: _AuthProxyPayload):
    """
    IoT Proxy Auth: Solves the network routing dilemma where the phone is trapped
    on the Pi's hotspot without internet. The phone sends its credentials here,
    and the Pi (which is connected to home Wi-Fi) forwards them to the Cloud.
    """
    try:
        # Step 1: Forward request to the Cloud
        res = _requests.post(
            payload.cloud_auth_url,
            json={"email": payload.email, "password": payload.password},
            timeout=15
        )
        data = res.json()
        
        # Step 2: If auth succeeded, auto-save the identity on the Pi!
        if res.status_code in (200, 201) and "access_token" in data:
            import re
            import pathlib
            from lettu_backend.core.config import PROJECT_ROOT
            
            # Save to database
            from lettu_backend.models.database import SessionLocal
            from lettu_backend.repository.scan_repo import DataRepository
            db = SessionLocal()
            try:
                repo = DataRepository(db)
                repo.save_user_email(payload.email)
            finally:
                db.close()

            # Save to .env
            env_path = pathlib.Path(PROJECT_ROOT) / ".env"
            try:
                content = env_path.read_text(encoding="utf-8")
                if "VAULT_USER_EMAIL" in content:
                    content = re.sub(
                        r"^VAULT_USER_EMAIL=.*",
                        f"VAULT_USER_EMAIL={payload.email}",
                        content, flags=re.MULTILINE
                    )
                else:
                    content += f"\nVAULT_USER_EMAIL={payload.email}\n"
                env_path.write_text(content, encoding="utf-8")
            except Exception as e:
                import logging
                logging.getLogger("proxy").warning(f"Failed writing .env: {e}")

        # Step 3: Forward the Cloud Server's EXACT response status & JSON back to the phone
        from fastapi.responses import JSONResponse
        return JSONResponse(status_code=res.status_code, content=data)

    except _requests.RequestException as e:
        raise HTTPException(
            status_code=502,
            detail=f"Pi could not reach the Cloud Server: {str(e)}"
        )

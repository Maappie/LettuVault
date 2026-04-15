# cloud-server/src/cloud_backend/api/v1/endpoints.py
# Cloud API routes. No MQTT, no hardware, no AI — data mirror only.

from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session
from typing import Optional
import os
import base64
import requests
from datetime import datetime

from cloud_backend.core.security import require_sync_key, require_mobile_key, hash_password, verify_password, create_access_token
from cloud_backend.models.database import SessionLocal
from cloud_backend.models.domain import (
    SyncBatchPayload, SyncResult, AuthRequest, AuthResponse,
    PendingCommandResponse, CommandAckRequest, SyncSystemConfig
)
from cloud_backend.repository.cloud_repo import CloudRepository

router = APIRouter(tags=["Cloud API v1"])


# ── DB Dependency ─────────────────────────────────────────────────────────────
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ── POST /sync ────────────────────────────────────────────────────────────────
@router.post(
    "/sync",
    response_model=SyncResult,
    dependencies=[Depends(require_sync_key)],
    summary="Edge Vault → Cloud: Batch upload of sensor and AI records",
)
def sync_vault_data(batch: SyncBatchPayload, db: Session = Depends(get_db)):
    """
    Protected endpoint called by the Sync Engine running on each Raspberry Pi.
    Requires: X-SYNC-API-KEY header matching CLOUD_SYNC_API_KEY in .env
    """
    repo = CloudRepository(db)

    def _process_image_uploads(scans):
        """Intercepts local images encoded as base64, uploads them to Supabase S3, and replaces the payload URL."""
        if not scans:
            return
        
        supabase_url = os.getenv("SUPABASE_URL")
        supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        supabase_bucket = os.getenv("SUPABASE_BUCKET", "lettu-captures")
        
        for scan in scans:
            if scan.image and scan.image.startswith("b64:"):
                # If Supabase is not configured on the cloud server, we drop the image to save DB space
                if not supabase_url or not supabase_key:
                    scan.image = None
                    continue
                
                try:
                    raw_b64 = scan.image.replace("b64:", "", 1)
                    image_bytes = base64.b64decode(raw_b64)
                    
                    ts = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
                    filename = f"scan_{scan.vault_id}_{ts}.jpg"
                    
                    headers = {
                        "Authorization": f"Bearer {supabase_key}",
                        "apikey": supabase_key,
                        "Content-Type": "image/jpeg"
                    }
                    url = f"{supabase_url.rstrip('/')}/storage/v1/object/{supabase_bucket}/{filename}"
                    
                    r = requests.post(url, headers=headers, data=image_bytes, timeout=10)
                    if r.status_code in [200, 201]:
                        # Assign the public Supabase URL
                        scan.image = f"{supabase_url.rstrip('/')}/storage/v1/object/public/{supabase_bucket}/{filename}"
                    else:
                        scan.image = None # upload failed
                except Exception:
                    scan.image = None # decode or upload error

    # Process uploads before saving
    _process_image_uploads(batch.condition_scans)
    _process_image_uploads(batch.produce_scans)

    sensors_saved   = repo.bulk_insert_sensor_readings(batch.sensor_readings)   if batch.sensor_readings   else 0
    condition_saved = repo.bulk_insert_condition_scans(batch.condition_scans)    if batch.condition_scans    else 0
    produce_saved   = repo.bulk_insert_produce_scans(batch.produce_scans)        if batch.produce_scans      else 0
    configs_saved   = repo.bulk_insert_system_configs(batch.system_configs)      if batch.system_configs     else 0

    return SyncResult(
        sensor_readings_saved=sensors_saved,
        condition_scans_saved=condition_saved,
        produce_scans_saved=produce_saved,
        system_configs_saved=configs_saved,
        message=f"Sync accepted: {sensors_saved} sensors, {condition_saved} conditions, {produce_saved} produce, {configs_saved} configs."
    )

# ── GET/POST /sync/commands (Edge Vault queries the queue) ────────────────────

@router.get(
    "/sync/commands/{vault_id}",
    response_model=list[PendingCommandResponse],
    dependencies=[Depends(require_sync_key)],
    summary="Edge Vault → Cloud: Retrieve pending hardware commands.",
)
def fetch_pending_commands(vault_id: str, db: Session = Depends(get_db)):
    repo = CloudRepository(db)
    cmds = repo.get_pending_commands(vault_id=vault_id)
    return [PendingCommandResponse(
        id=c.id, command_type=c.command_type, payload_json=c.payload_json, created_at=c.created_at
    ) for c in cmds]


@router.post(
    "/sync/commands/ack",
    dependencies=[Depends(require_sync_key)],
    summary="Edge Vault → Cloud: Acknowledge command execution.",
)
def ack_command(req: CommandAckRequest, db: Session = Depends(get_db)):
    repo = CloudRepository(db)
    repo.mark_command_delivered(req.command_id)
    return {"message": "Command ACKed"}


# ── GET endpoints (Mobile App reads the cloud mirror) ─────────────────────────
# All mobile-facing endpoints use X-MOBILE-API-KEY — separate from the sync key.

@router.get(
    "/internal-environment",
    dependencies=[Depends(require_mobile_key)],
    summary="[Mobile] Latest sensor readings from cloud mirror",
)
def list_sensor_readings(
    vault_id: Optional[str] = Query(None, description="Filter by vault ID"),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
    user_email: str | None = Depends(require_mobile_key)
):
    repo = CloudRepository(db)
    target_vault = vault_id
    if not target_vault and user_email:
        target_vault = repo.get_vault_id_by_email(user_email)
    
    return repo.get_sensor_readings(vault_id=target_vault, limit=limit)


@router.get(
    "/ai-scans/condition",
    dependencies=[Depends(require_mobile_key)],
    summary="[Mobile] AI condition scans from cloud mirror",
)
def list_condition_scans(
    vault_id: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    user_email: str | None = Depends(require_mobile_key)
):
    repo = CloudRepository(db)
    target_vault = vault_id
    if not target_vault and user_email:
        target_vault = repo.get_vault_id_by_email(user_email)
        
    return repo.get_condition_scans(vault_id=target_vault, limit=limit)


@router.get(
    "/ai-scans/produce",
    dependencies=[Depends(require_mobile_key)],
    summary="[Mobile] AI produce scans from cloud mirror",
)
def list_produce_scans(
    vault_id: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
    user_email: str | None = Depends(require_mobile_key)
):
    repo = CloudRepository(db)
    target_vault = vault_id
    if not target_vault and user_email:
        target_vault = repo.get_vault_id_by_email(user_email)
        
    return repo.get_produce_scans(vault_id=target_vault, limit=limit)


@router.get(
    "/system_config",
    dependencies=[Depends(require_mobile_key)],
    summary="[Mobile] Latest system config from cloud mirror",
)
def get_latest_system_config(
    vault_id: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    user_email: str | None = Depends(require_mobile_key)
):
    repo = CloudRepository(db)
    target_vault = vault_id
    if not target_vault and user_email:
        target_vault = repo.get_vault_id_by_email(user_email)
        
    return repo.get_latest_system_config(vault_id=target_vault)


# ── Remote Hardware Action Endpoints (Mobile App → Cloud Queue) ───────────────
import json

@router.post(
    "/test-camera",
    summary="[Mobile] Queue a test picture trigger for a Vault.",
)
def trigger_test_camera(
    vault_id: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    user_email: str | None = Depends(require_mobile_key)
):
    repo = CloudRepository(db)
    target_vault = vault_id
    if not target_vault and user_email:
        target_vault = repo.get_vault_id_by_email(user_email)
    
    if not target_vault:
        raise HTTPException(status_code=400, detail="No vault_id provided and could not determine vault from user profile.")
        
    cmd = repo.enqueue_command(target_vault, "FORCE_TEST_CAPTURE")
    return {"message": "Command queued", "command_id": cmd.id}


@router.post(
    "/trigger-produce-scan",
    summary="[Mobile] Queue a produce scan trigger for a Vault.",
)
def trigger_produce_scan(
    vault_id: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    user_email: str | None = Depends(require_mobile_key)
):
    repo = CloudRepository(db)
    target_vault = vault_id
    if not target_vault and user_email:
        target_vault = repo.get_vault_id_by_email(user_email)
    
    if not target_vault:
        raise HTTPException(status_code=400, detail="No vault_id provided and could not determine vault from user profile.")
        
    cmd = repo.enqueue_command(target_vault, "TRIGGER_PRODUCE_SCAN")
    return {"message": "Command queued", "command_id": cmd.id}


@router.post(
    "/system_config",
    summary="[Mobile] Queue a System Config update for a Vault.",
)
def save_system_config(
    config_in: dict,
    vault_id: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    user_email: str | None = Depends(require_mobile_key)
):
    repo = CloudRepository(db)
    target_vault = vault_id
    if not target_vault and user_email:
        target_vault = repo.get_vault_id_by_email(user_email)
    
    if not target_vault:
        raise HTTPException(status_code=400, detail="No vault_id provided and could not determine vault from user profile.")
        
    cmd = repo.enqueue_command(target_vault, "SYS_CONFIG", json.dumps(config_in))
    return {"message": "Config queued for broadcast", "command_id": cmd.id}


# ── Auth Endpoints (Mobile App → Cloud) ───────────────────────────────────────────────

@router.post(
    "/auth/signup",
    response_model=AuthResponse,
    summary="[Mobile] Register a new user account",
)
def signup(req: AuthRequest, db: Session = Depends(get_db)):
    """
    Creates a new cloud user account.
    Returns a JWT on success so the app can proceed without a second login step.
    """
    repo = CloudRepository(db)
    if repo.get_user_by_email(req.email):
        raise HTTPException(status_code=409, detail="email_taken")
    hashed = hash_password(req.password)
    repo.create_user(email=req.email, password_hash=hashed)
    token = create_access_token(req.email)
    return AuthResponse(access_token=token, email=req.email)


@router.post(
    "/auth/login",
    response_model=AuthResponse,
    summary="[Mobile] Login with email and password",
)
def login(req: AuthRequest, db: Session = Depends(get_db)):
    """
    Verifies credentials against the cloud_users table.
    Returns a JWT on success.
    """
    repo = CloudRepository(db)
    user = repo.get_user_by_email(req.email)
    if not user or not verify_password(req.password, user.password_hash):
        raise HTTPException(status_code=401, detail="invalid_credentials")
    if not user.is_active:
        raise HTTPException(status_code=403, detail="account_disabled")
    token = create_access_token(req.email)
    return AuthResponse(access_token=token, email=req.email)

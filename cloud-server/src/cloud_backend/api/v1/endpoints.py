# cloud-server/src/cloud_backend/api/v1/endpoints.py
# Cloud API routes. No MQTT, no hardware, no AI — data mirror only.

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from typing import Optional

from cloud_backend.core.security import require_sync_key, require_mobile_key
from cloud_backend.models.database import SessionLocal
from cloud_backend.models.domain import SyncBatchPayload, SyncResult
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


# ── GET endpoints (Mobile App reads the cloud mirror) ─────────────────────────
# All mobile-facing endpoints use X-MOBILE-API-KEY — separate from the sync key.

@router.get(
    "/sensor-readings",
    dependencies=[Depends(require_mobile_key)],
    summary="[Mobile] Latest sensor readings from cloud mirror",
)
def list_sensor_readings(
    vault_id: Optional[str] = Query(None, description="Filter by vault ID"),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
):
    repo = CloudRepository(db)
    return repo.get_sensor_readings(vault_id=vault_id, limit=limit)


@router.get(
    "/ai-scans/condition",
    dependencies=[Depends(require_mobile_key)],
    summary="[Mobile] AI condition scans from cloud mirror",
)
def list_condition_scans(
    vault_id: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
):
    repo = CloudRepository(db)
    return repo.get_condition_scans(vault_id=vault_id, limit=limit)


@router.get(
    "/ai-scans/produce",
    dependencies=[Depends(require_mobile_key)],
    summary="[Mobile] AI produce scans from cloud mirror",
)
def list_produce_scans(
    vault_id: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
):
    repo = CloudRepository(db)
    return repo.get_produce_scans(vault_id=vault_id, limit=limit)


@router.get(
    "/system-config",
    dependencies=[Depends(require_mobile_key)],
    summary="[Mobile] Latest system config from cloud mirror",
)
def get_latest_system_config(
    vault_id: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    repo = CloudRepository(db)
    return repo.get_latest_system_config(vault_id=vault_id)

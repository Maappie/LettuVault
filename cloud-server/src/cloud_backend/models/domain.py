# cloud-server/src/cloud_backend/models/domain.py
# Pydantic schemas for the cloud sync API — all payloads require vault_id.

from pydantic import BaseModel, field_validator
from datetime import datetime
from typing import Optional, List


# ── Inbound Sync Payloads (Edge → Cloud) ────────────────────────────────────

class SyncSensorReading(BaseModel):
    """One BME280 sensor reading from a local vault."""
    vault_id: str
    user_email: Optional[str] = None
    device_id: Optional[str] = None
    temperature: Optional[float] = None
    humidity: Optional[float] = None
    pressure: Optional[float] = None
    timestamp: datetime  # Original local timestamp (Manila time is fine)


class SyncAIConditionScan(BaseModel):
    """One AI condition detection (worms/wilting) from a local vault."""
    vault_id: str
    user_email: Optional[str] = None
    worm_count: int = 0
    confidence_score: Optional[float] = None
    label: Optional[str] = None
    image: Optional[str] = None
    timestamp: datetime


class SyncAIProduceScan(BaseModel):
    """One AI produce detection (lettuce/strawberry) from a local vault."""
    vault_id: str
    user_email: Optional[str] = None
    produce_type: Optional[str] = None
    confidence_score: Optional[float] = None
    label: Optional[str] = None
    image: Optional[str] = None
    timestamp: datetime


class SyncSystemConfig(BaseModel):
    """One system configuration update from a local vault."""
    vault_id: str
    user_email: Optional[str] = None
    temperature: Optional[float] = None
    humidity: Optional[float] = None
    pressure: Optional[float] = None
    timestamp: datetime


class SyncBatchPayload(BaseModel):
    """
    The full batch payload POSTed to /api/v1/sync by the Sync Engine.
    All three lists are optional — the engine only sends what has new records.
    """
    sensor_readings: Optional[List[SyncSensorReading]] = []
    condition_scans: Optional[List[SyncAIConditionScan]] = []
    produce_scans: Optional[List[SyncAIProduceScan]] = []
    system_configs: Optional[List[SyncSystemConfig]] = []


# ── Auth Schemas ──────────────────────────────────────────────────────────────────────

class AuthRequest(BaseModel):
    email: str
    password: str


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    email: str


# ── Outbound Responses (Cloud → Edge) ────────────────────────────────────────

class SyncResult(BaseModel):
    """Summary returned to the sync engine after a successful batch upload."""
    sensor_readings_saved: int
    condition_scans_saved: int
    produce_scans_saved: int
    system_configs_saved: int
    message: str = "Sync completed"

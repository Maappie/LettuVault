# cloud-server/src/cloud_backend/models/database.py
# Cloud schema mirrors the local schema but adds vault_id to all tables
# so the cloud can distinguish between multiple physical hardware boxes.

from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime
from sqlalchemy.orm import declarative_base, sessionmaker
from cloud_backend.core.config import settings
import datetime

engine = create_engine(
    settings.DATABASE_URL,
    # check_same_thread only needed for SQLite
    connect_args={"check_same_thread": False} if "sqlite" in settings.DATABASE_URL else {}
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def utc_now():
    return datetime.datetime.utcnow()


# ── Cloud Mirror: Internal Environment (Sensor) Readings ────────────────────
class CloudSensorReading(Base):
    __tablename__ = "cloud_sensor_readings"

    id           = Column(Integer, primary_key=True, index=True)
    vault_id     = Column(String, nullable=False, index=True)   # e.g. "VAULT_ALPHA_01"
    device_id    = Column(String, nullable=True)                 # ESP32 device identifier
    temperature  = Column(Float, nullable=True)
    humidity     = Column(Float, nullable=True)
    pressure     = Column(Float, nullable=True)
    timestamp    = Column(DateTime, nullable=False)              # Original edge timestamp
    synced_at    = Column(DateTime, default=utc_now)            # When it arrived at the cloud


# ── Cloud Mirror: AI Condition Scans (Worms / Wilting) ──────────────────────
class CloudAIConditionScan(Base):
    __tablename__ = "cloud_ai_condition_scans"

    id               = Column(Integer, primary_key=True, index=True)
    vault_id         = Column(String, nullable=False, index=True)
    worm_count       = Column(Integer, default=0)
    confidence_score = Column(Float, nullable=True)
    label            = Column(String, nullable=True)
    image            = Column(String, nullable=True)   # base64 or relative path
    timestamp        = Column(DateTime, nullable=False)
    synced_at        = Column(DateTime, default=utc_now)


# ── Cloud Mirror: AI Produce Scans (Lettuce / Strawberry) ───────────────────
class CloudAIProduceScan(Base):
    __tablename__ = "cloud_ai_produce_scans"

    id               = Column(Integer, primary_key=True, index=True)
    vault_id         = Column(String, nullable=False, index=True)
    produce_type     = Column(String, nullable=True)
    confidence_score = Column(Float, nullable=True)
    label            = Column(String, nullable=True)
    image            = Column(String, nullable=True)
    timestamp        = Column(DateTime, nullable=False)
    synced_at        = Column(DateTime, default=utc_now)

# ── Cloud Mirror: System Configuration ──────────────────────────────────────────
class CloudSystemConfig(Base):
    __tablename__ = "cloud_system_config"

    id               = Column(Integer, primary_key=True, index=True)
    vault_id         = Column(String, nullable=False, index=True)
    temperature      = Column(Float, nullable=True)
    humidity         = Column(Float, nullable=True)
    pressure         = Column(Float, nullable=True)
    timestamp        = Column(DateTime, nullable=False)
    synced_at        = Column(DateTime, default=utc_now)

# backend/src/lettu_backend/models/database.py

import pathlib
from lettu_backend.core.config import settings
from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import datetime


# Set up the engine
# 'check_same_thread=False' is required for SQLite to work with fastAPI
engine = create_engine(settings.DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# 🇵🇭 Manila Time Helper (UTC+8)
def manila_now():
    return datetime.datetime.utcnow() + datetime.timedelta(hours=8)

# Define the database table/model

class AIScan(Base):
    __tablename__ = "ai_scans"
    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime, default=manila_now)
    worm_count = Column(Integer)
    confidence_score = Column(Float)
    image_name = Column(String)  
    image = Column(String, nullable=True)  # Relative path: captures/scan_xyz.jpg
    label = Column(String)

class SensorReading(Base):
    __tablename__ = "sensor_readings"
    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime, default=manila_now)
    temperature = Column(Float)
    humidity = Column(Float)  
    device_id = Column(String) # E.g. "ESP32-Vault-01"

class SystemConfig(Base):
    __tablename__ = "system_config"
    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime, default=manila_now)
    temperature = Column(Float)
    humidity = Column(Float)
    pressure = Column(Float)
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

class AIConditionScan(Base):
    __tablename__ = "ai_condition_scans"
    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime, default=manila_now)
    worm_count = Column(Integer, default=0)
    confidence_score = Column(Float)
    image = Column(String, nullable=True) # Relative path
    label = Column(String) # E.g. "1 worms, 2 wilting"

class AIProduceScan(Base):
    __tablename__ = "ai_produce_scans"
    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime, default=manila_now)
    confidence_score = Column(Float)
    image = Column(String, nullable=True)
    produce_type = Column(String) # "Lettuce" or "Strawberry"
    label = Column(String) # Raw YOLO string


class SystemConfig(Base):
    __tablename__ = "system_config"
    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime, default=manila_now)
    temperature = Column(Float, nullable=True)
    humidity = Column(Float, nullable=True)
    pressure = Column(Float, nullable=True)
    user_email = Column(String, nullable=True)  # Cloud-registered user email

class InternalEnvironmentReading(Base):
    __tablename__ = "internal_environment_readings"
    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime, default=manila_now)
    temperature = Column(Float, nullable=True)
    humidity = Column(Float, nullable=True)
    pressure = Column(Float, nullable=True)
    device_id = Column(String, nullable=True) 
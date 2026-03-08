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

# Define the database table/model

class ScanRecord(Base):
    __tablename__ = "scans"
    
    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    worm_count = Column(Integer)
    confidence_score = Column(Float)
    image_name = Column(String)  
    temperature = Column(Float)
    humidity = Column(Float)  
    name = Column(String)
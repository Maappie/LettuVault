# backend/src/lettu_backend/models/database.py

import pathlib
from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import datetime

# get the path to "LettuVault/backend" folder automatically
BASE_DIR = pathlib.Path(__file__).parent.parent.parent.resolve()
DATABASE_URL = f"sqlite:///{BASE_DIR}/lettu_vault.db"

# Set up the engine
# 'check_same_thread=False' is required for SQLite to work with fastAPI
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Define the database table/model

class ScanRecord(Base):
    __tablename__ = "scans"
    
    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)
    worm_count = Column(Integer)
    confidence_score = Column(Float)
    image_name = Column(String)  # Filename like 'scan_20260218_01.jpg'
    box_id = Column(String)      # ID of the specific LettuVault box
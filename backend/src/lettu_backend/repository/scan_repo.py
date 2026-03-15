# backend/src/lettu_backend/repository/scan_repo.py
from sqlalchemy.orm import Session
from lettu_backend.models.database import AIScan, SensorReading, SystemConfig

class DataRepository:
    def __init__(self, db: Session):
        self.db = db

    # --- AI SCAN METHODS ---
    def get_all_ai_scans(self, limit: int = 100):
        return self.db.query(AIScan).order_by(AIScan.timestamp.desc()).limit(limit).all()

    def create_ai_scan(self, data: dict):
        db_record = AIScan(**data)
        self.db.add(db_record)
        self.db.commit()
        self.db.refresh(db_record)
        return db_record

    # --- SENSOR METHODS ---
    def get_all_sensor_readings(self, limit: int = 100):
        return self.db.query(SensorReading).order_by(SensorReading.timestamp.desc()).limit(limit).all()

    def create_sensor_reading(self, data: dict):
        db_record = SensorReading(**data)
        self.db.add(db_record)
        self.db.commit()
        self.db.refresh(db_record)
        return db_record

    # --- SYSTEM CONFIG METHODS ---
    def create_system_config(self, data: dict):
        db_record = SystemConfig(**data)
        self.db.add(db_record)
        self.db.commit()
        self.db.refresh(db_record)
        return db_record

    def get_all_system_configs(self, limit: int = 100):
        return self.db.query(SystemConfig).order_by(SystemConfig.timestamp.desc()).limit(limit).all()

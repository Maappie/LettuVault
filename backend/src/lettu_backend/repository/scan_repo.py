# backend/src/lettu_backend/repository/scan_repo.py
from sqlalchemy.orm import Session
from lettu_backend.models.database import AIConditionScan, AIProduceScan, SensorReading, SystemConfig, InternalEnvironmentReading

class DataRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_all_condition_scans(self, limit: int = 100):
        return self.db.query(AIConditionScan).order_by(AIConditionScan.timestamp.desc()).limit(limit).all()

    def create_condition_scan(self, data: dict):
        db_record = AIConditionScan(**data)
        self.db.add(db_record)
        self.db.commit()
        self.db.refresh(db_record)
        return db_record

    # --- AI SCAN METHODS (PRODUCE) ---
    def get_all_produce_scans(self, limit: int = 50):
        return self.db.query(AIProduceScan).order_by(AIProduceScan.timestamp.desc()).limit(limit).all()

    def create_produce_scan(self, data: dict):
        db_record = AIProduceScan(**data)
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

    # --- INTERNAL ENVIRONMENT METHODS ---
    def create_internal_environment_reading(self, data: dict):
        db_record = InternalEnvironmentReading(**data)
        self.db.add(db_record)
        self.db.commit()
        self.db.refresh(db_record)
        return db_record

    def get_all_internal_environment_readings(self, limit: int = 100):
        return self.db.query(InternalEnvironmentReading).order_by(InternalEnvironmentReading.timestamp.desc()).limit(limit).all()


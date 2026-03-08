# backend/src/lettu_backend/repository/scan_repo.py
from sqlalchemy.orm import Session
from lettu_backend.models.database import ScanRecord

class ScanRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_all_scans(self, limit: int = 100):
        return self.db.query(ScanRecord).limit(limit).all()

    def create_scan(self, scan_data: dict):
        db_scan = ScanRecord(**scan_data)
        self.db.add(db_scan)
        self.db.commit()
        self.db.refresh(db_scan)
        return db_scan

    def get_scan_by_id(self, scan_id: int):
        return self.db.query(ScanRecord).filter(ScanRecord.id == scan_id).first()

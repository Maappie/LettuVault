# cloud-server/src/cloud_backend/repository/cloud_repo.py
# All CRUD operations for the cloud mirror database.

from sqlalchemy.orm import Session
from cloud_backend.models.database import (
    CloudSensorReading,
    CloudAIConditionScan,
    CloudAIProduceScan,
    CloudSystemConfig,
)
from cloud_backend.models.domain import (
    SyncSensorReading,
    SyncAIConditionScan,
    SyncAIProduceScan,
    SyncSystemConfig,
)


class CloudRepository:
    def __init__(self, db: Session):
        self.db = db

    def bulk_insert_sensor_readings(self, readings: list[SyncSensorReading]) -> int:
        records = [CloudSensorReading(**r.model_dump()) for r in readings]
        self.db.bulk_save_objects(records)
        self.db.commit()
        return len(records)

    def bulk_insert_condition_scans(self, scans: list[SyncAIConditionScan]) -> int:
        records = [CloudAIConditionScan(**s.model_dump()) for s in scans]
        self.db.bulk_save_objects(records)
        self.db.commit()
        return len(records)

    def bulk_insert_produce_scans(self, scans: list[SyncAIProduceScan]) -> int:
        records = [CloudAIProduceScan(**s.model_dump()) for s in scans]
        self.db.bulk_save_objects(records)
        self.db.commit()
        return len(records)

    def bulk_insert_system_configs(self, configs: list[SyncSystemConfig]) -> int:
        records = [CloudSystemConfig(**c.model_dump()) for c in configs]
        self.db.bulk_save_objects(records)
        self.db.commit()
        return len(records)

    # ── Read endpoints for the Mobile App ───────────────────────────────────

    def get_sensor_readings(self, vault_id: str | None = None, limit: int = 100):
        q = self.db.query(CloudSensorReading)
        if vault_id:
            q = q.filter(CloudSensorReading.vault_id == vault_id)
        return q.order_by(CloudSensorReading.timestamp.desc()).limit(limit).all()

    def get_condition_scans(self, vault_id: str | None = None, limit: int = 50):
        q = self.db.query(CloudAIConditionScan)
        if vault_id:
            q = q.filter(CloudAIConditionScan.vault_id == vault_id)
        return q.order_by(CloudAIConditionScan.timestamp.desc()).limit(limit).all()

    def get_produce_scans(self, vault_id: str | None = None, limit: int = 50):
        q = self.db.query(CloudAIProduceScan)
        if vault_id:
            q = q.filter(CloudAIProduceScan.vault_id == vault_id)
        return q.order_by(CloudAIProduceScan.timestamp.desc()).limit(limit).all()

    def get_latest_system_config(self, vault_id: str | None = None):
        q = self.db.query(CloudSystemConfig)
        if vault_id:
            q = q.filter(CloudSystemConfig.vault_id == vault_id)
        return q.order_by(CloudSystemConfig.timestamp.desc()).first()

# cloud-server/src/cloud_backend/repository/cloud_repo.py
# All CRUD operations for the cloud mirror database.

from sqlalchemy.orm import Session
from cloud_backend.models.database import (
    CloudSensorReading,
    CloudAIConditionScan,
    CloudAIProduceScan,
    CloudSystemConfig,
    CloudUser,
    CloudCommandQueue,
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
        return q.order_by(CloudSystemConfig.timestamp.desc()).limit(1).all()

    # ── User Auth ────────────────────────────────────────────────────────────

    def create_user(self, email: str, password_hash: str) -> CloudUser:
        user = CloudUser(email=email, password_hash=password_hash)
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return user

    def get_user_by_email(self, email: str) -> CloudUser | None:
        return self.db.query(CloudUser).filter(CloudUser.email == email).first()

    def get_all_users(self) -> list[CloudUser]:
        return self.db.query(CloudUser).order_by(CloudUser.created_at.desc()).all()

    # ── Command Queue (Remote Hardware Actions) ──────────────────────────────

    def enqueue_command(self, vault_id: str, command_type: str, payload_json: str | None = None) -> CloudCommandQueue:
        cmd = CloudCommandQueue(
            vault_id=vault_id,
            command_type=command_type,
            payload_json=payload_json,
            status="PENDING"
        )
        self.db.add(cmd)
        self.db.commit()
        self.db.refresh(cmd)
        return cmd

    def get_pending_commands(self, vault_id: str) -> list[CloudCommandQueue]:
        return self.db.query(CloudCommandQueue)\
            .filter(CloudCommandQueue.vault_id == vault_id, CloudCommandQueue.status == "PENDING")\
            .order_by(CloudCommandQueue.created_at.asc())\
            .all()

    def mark_command_delivered(self, command_id: int):
        from datetime import datetime
        cmd = self.db.query(CloudCommandQueue).filter(CloudCommandQueue.id == command_id).first()
        if cmd:
            cmd.status = "DELIVERED"
            cmd.delivered_at = datetime.utcnow()
            self.db.commit()

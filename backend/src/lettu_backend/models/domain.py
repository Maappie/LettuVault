# backend/src/lettu_backend/models/domain.py
from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class ScanRecordBase(BaseModel):
    worm_count: int
    confidence_score: float
    image_name: str
    temperature: Optional[float] = None
    humidity: Optional[float] = None
    name: Optional[str] = None

class ScanRecordCreate(ScanRecordBase):
    pass

class ScanRecordResponse(ScanRecordBase):
    id: int
    timestamp: datetime

    class Config:
        from_attributes = True

# backend/src/lettu_backend/models/domain.py
from pydantic import BaseModel
from datetime import datetime
from typing import Optional

# --- AI DETECTION SCHEMAS ---
class AIScanBase(BaseModel):
    worm_count: int
    confidence_score: float
    image_name: str
    label: Optional[str] = "Primary Camera"

class AIScanCreate(AIScanBase):
    pass

class AIScanResponse(AIScanBase):
    id: int
    timestamp: datetime
    class Config:
        from_attributes = True

# --- SENSOR DATA SCHEMAS ---
class SensorReadingBase(BaseModel):
    temperature: float
    humidity: float
    device_id: Optional[str] = "LettuVault-Hardware"

class SensorReadingCreate(SensorReadingBase):
    pass

class SensorReadingResponse(SensorReadingBase):
    id: int
    timestamp: datetime
    class Config:
        from_attributes = True

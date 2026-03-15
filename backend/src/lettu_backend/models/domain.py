# backend/src/lettu_backend/models/domain.py
from pydantic import BaseModel
from datetime import datetime
from typing import Optional

# --- AI DETECTION SCHEMAS ---
class AIScanBase(BaseModel):
    worm_count: int
    confidence_score: float
    image_name: str
    image: Optional[str] = None  # Relative path: captures/scan_xyz.jpg
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

# --- SYSTEM CONFIG SCHEMAS ---
class SystemConfigBase(BaseModel):
    temperature: float
    humidity: float
    pressure: float

class SystemConfigCreate(SystemConfigBase):
    pass

class SystemConfigResponse(SystemConfigBase):
    id: int
    timestamp: datetime
    class Config:
        from_attributes = True

# backend/src/lettu_backend/models/domain.py
from pydantic import BaseModel
from datetime import datetime
from typing import Optional

# --- AI CONDITION SCHEMAS (Worms/Wilting) ---
class AIConditionBase(BaseModel):
    worm_count: int = 0
    confidence_score: float
    image: Optional[str] = None
    label: Optional[str] = ""

class AIConditionCreate(AIConditionBase):
    pass

class AIConditionResponse(AIConditionBase):
    id: int
    timestamp: datetime
    class Config:
        from_attributes = True

# --- AI PRODUCE SCHEMAS (Lettuce/Strawberry) ---
class AIProduceBase(BaseModel):
    produce_type: str
    confidence_score: float
    image: Optional[str] = None
    label: Optional[str] = ""

class AIProduceCreate(AIProduceBase):
    pass

class AIProduceResponse(AIProduceBase):
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
    temperature: Optional[float] = None
    humidity: Optional[float] = None
    pressure: Optional[float] = None

class SystemConfigCreate(SystemConfigBase):
    pass

class SystemConfigResponse(SystemConfigBase):
    id: int
    timestamp: datetime
    esp32_status: Optional[str] = None
    class Config:
        from_attributes = True

# --- INTERNAL ENVIRONMENT SCHEMAS ---
class InternalEnvironmentReadingBase(BaseModel):
    temperature: Optional[float] = None
    humidity: Optional[float] = None
    pressure: Optional[float] = None

class InternalEnvironmentReadingCreate(InternalEnvironmentReadingBase):
    pass

class InternalEnvironmentReadingResponse(InternalEnvironmentReadingBase):
    id: int
    timestamp: datetime
    class Config:
        from_attributes = True

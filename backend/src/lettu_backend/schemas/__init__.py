"""
📦 LettuVault - API Schemas (Input Validators)
================================================
This is the equivalent of Zod schemas in Next.js or contracts in other systems.

Every piece of data that enters this API from the outside world MUST be
validated through one of these schemas BEFORE it touches the database or
any business logic. This prevents bad/malformed data, injection attempts,
and unexpected crashes.

Pattern:
  - <Entity>Create  → Validates inbound POST request body
  - <Entity>Update  → Validates inbound PATCH/PUT request body (partial)
  - <Entity>Response → Defines what the API sends BACK to the client
"""
from pydantic import BaseModel, Field, field_validator
from typing import Optional
import re


# ============================================================
#  🧠 AI CONDITION SCAN (Worms / Wilting)
# ============================================================

class AIConditionCreateSchema(BaseModel):
    """Validates incoming worm/wilting detection data from the AI publisher."""

    worm_count: int = Field(
        default=0,
        ge=0,          # Must be >= 0, cannot be negative
        le=1000,       # Sanity cap: no more than 1000 worms in one scan
        description="Number of worms detected"
    )
    confidence_score: float = Field(
        ...,
        ge=0.0,        # Cannot be below 0%
        le=1.0,        # Cannot be above 100%
        description="Model confidence between 0.0 and 1.0"
    )
    label: Optional[str] = Field(
        default="",
        max_length=500,
        description="Human-readable detection label"
    )
    image: Optional[str] = Field(
        default=None,
        description="Base64-encoded image or file path"
    )

    @field_validator("label")
    @classmethod
    def sanitize_label(cls, v):
        """Strip any HTML/script tags from the label to prevent XSS."""
        if v:
            return re.sub(r'<[^>]+>', '', v).strip()
        return v


# ============================================================
#  🥗 AI PRODUCE SCAN (Lettuce / Strawberry)
# ============================================================

ALLOWED_PRODUCE_TYPES = {"Lettuce", "Strawberry", "Empty / Unknown", "Camera Test"}

class AIProduceCreateSchema(BaseModel):
    """Validates incoming produce identification data from the AI publisher."""

    produce_type: str = Field(
        ...,
        min_length=1,
        max_length=100,
        description="Type of produce identified"
    )
    confidence_score: float = Field(
        ...,
        ge=0.0,
        le=1.0,
        description="Model confidence between 0.0 and 1.0"
    )
    label: Optional[str] = Field(
        default="",
        max_length=500
    )
    image: Optional[str] = Field(
        default=None,
        description="Base64-encoded image or file path"
    )

    @field_validator("produce_type")
    @classmethod
    def validate_produce_type(cls, v):
        """Only allow known, pre-approved produce type names."""
        if v not in ALLOWED_PRODUCE_TYPES:
            raise ValueError(
                f"Invalid produce_type '{v}'. Must be one of: {ALLOWED_PRODUCE_TYPES}"
            )
        return v

    @field_validator("label")
    @classmethod
    def sanitize_label(cls, v):
        if v:
            return re.sub(r'<[^>]+>', '', v).strip()
        return v


# ============================================================
#  ⚙️ SYSTEM CONFIG (Target Setpoints sent to ESP32)
# ============================================================

class SystemConfigCreateSchema(BaseModel):
    """Validates the desired environment setpoints before sending to ESP32."""

    temperature: Optional[float] = Field(
        default=None,
        ge=0.0,        # Cannot set a target temperature below freezing
        le=50.0,       # 50°C is the sane upper limit for a grow vault
        description="Target temperature in Celsius"
    )
    humidity: Optional[float] = Field(
        default=None,
        ge=0.0,
        le=100.0,
        description="Target relative humidity percentage"
    )
    pressure: Optional[float] = Field(
        default=None,
        ge=800.0,
        le=1200.0,
        description="Atmospheric pressure in hPa"
    )


# ============================================================
#  🌡️ INTERNAL ENVIRONMENT / SENSOR READING (All BME280 data)
#
#  Previously two separate schemas (SensorReadingCreateSchema +
#  InternalEnvironmentCreateSchema), now unified since both
#  write to the same `internal_environment_readings` table.
# ============================================================

class InternalEnvironmentCreateSchema(BaseModel):
    """
    Validates ALL inbound BME280 sensor readings.
    Used by both /sensor-readings and /internal-environment endpoints.
    """

    temperature: float = Field(
        ...,
        ge=-20.0,      # Below -20°C is outside any reasonable lettuce range
        le=80.0,       # Above 80°C the sensor is probably broken
        description="Temperature in Celsius"
    )
    humidity: float = Field(
        ...,
        ge=0.0,
        le=100.0,
        description="Relative humidity as a percentage"
    )
    pressure: Optional[float] = Field(
        default=None,
        ge=800.0,      # Minimum realistic atmospheric pressure (hPa)
        le=1200.0,     # Maximum realistic atmospheric pressure (hPa)
        description="Atmospheric pressure in hPa (from BME280)"
    )
    device_id: Optional[str] = Field(
        default="LettuVault-Hardware",
        max_length=100,
        description="Hardware device identifier"
    )

    @field_validator("device_id")
    @classmethod
    def sanitize_device_id(cls, v):
        """Only allow alphanumeric chars, dashes, and underscores in the device ID."""
        if v and not re.match(r'^[a-zA-Z0-9_\-]+$', v):
            raise ValueError("device_id must contain only letters, numbers, dashes, and underscores.")
        return v

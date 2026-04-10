# cloud-server/src/cloud_backend/core/config.py
# Stripped-down settings for cloud deployment. No MQTT, no hardware.

from pydantic_settings import BaseSettings
from functools import lru_cache
from dotenv import load_dotenv, find_dotenv
import os

dotenv_path = find_dotenv()
dotenv_path = find_dotenv()
load_dotenv(dotenv_path, override=True)

class Settings(BaseSettings):
    PROJECT_NAME: str = "LettuVault Cloud Mirror"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"

    # Security: Used by Edge Vaults (Raspberry Pis) to authenticate sync requests
    CLOUD_SYNC_API_KEY: str = os.getenv("CLOUD_SYNC_API_KEY", "change-me-in-production")

    # Separate key for the Flutter Mobile App (online mode)
    CLOUD_MOBILE_API_KEY: str = os.getenv("CLOUD_MOBILE_API_KEY", "change-me-in-production")

    # Optional: JWT for the Mobile App to query this cloud server directly
    SECRET_KEY: str = os.getenv("SECRET_KEY", "change-me-in-production")
    ALGORITHM: str = "HS256"

    # Cloud PostgreSQL connection string (e.g. from Neon.tech)
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./cloud_mirror.db")

    class Config:
        case_sensitive = True

@lru_cache()
def get_settings():
    return Settings()

settings = get_settings()

# backend/src/lettu_backend/core/config.py
from pydantic_settings import BaseSettings
from functools import lru_cache
from dotenv import load_dotenv
import os
import pathlib

# 📂 Root Folder Helper
# Find the .env file in the PROJECT ROOT
ROOT_DIR = pathlib.Path(__file__).parent.parent.parent.parent.parent.resolve()
ENV_PATH = ROOT_DIR / ".env"

# 🛠️ MANUALLY LOAD DOTENV
# This ensures os.getenv() works even if Pydantic's internal loader fails.
if ENV_PATH.exists():
    load_dotenv(str(ENV_PATH))

class Settings(BaseSettings):
    # API Identity
    PROJECT_NAME: str = os.getenv("PROJECT_NAME", "LettuVault API")
    VERSION: str = os.getenv("VERSION", "0.1.0")
    API_V1_STR: str = "/api/v1"
    
    # Security: Mobile App (JWT)
    # Generate a secret key: openssl rand -hex 32
    SECRET_KEY: str = os.getenv("SECRET_KEY", "your-very-secret-key-for-jwt-development")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7 
    
    # Security: Hardware (ESP32 API Key)
    X_API_KEY: str = os.getenv("X_API_KEY", "lettuce-master-key-2024")
    
    # 💾 Database Connection String
    # Prioritizes .env, falls back to the local /data folder
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///data/lettu_vault.db")

    # 📡 MQTT Settings
    MQTT_BROKER: str = os.getenv("MQTT_BROKER", "127.0.0.1")
    MQTT_PORT: int = int(os.getenv("MQTT_PORT", "1883"))
    MQTT_TOPIC_SENSORS: str = os.getenv("MQTT_TOPIC_SENSORS", "lettuvault/sensors")
    MQTT_TOPIC_AI: str = os.getenv("MQTT_TOPIC_AI", "lettuvault/ai")

    class Config:
        case_sensitive = True

@lru_cache()
def get_settings():
    return Settings()

settings = get_settings()

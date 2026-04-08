from pydantic_settings import BaseSettings
from functools import lru_cache
from dotenv import load_dotenv, find_dotenv
import os
import pathlib

# 📂 Load Environment Variables
# find_dotenv() automatically climbs the directory tree until it finds .env
dotenv_path = find_dotenv()
load_dotenv(dotenv_path)

# Single Source of Truth: The directory containing .env is our true project root!
if dotenv_path:
    PROJECT_ROOT = os.path.dirname(dotenv_path)
else:
    # Safe fallback just in case .env is ever missing
    PROJECT_ROOT = os.getcwd()

CAPTURES_DIR = os.path.join(PROJECT_ROOT, "data", "captures")

class Settings(BaseSettings):
    # API Identity
    PROJECT_NAME: str = os.getenv("PROJECT_NAME")
    VERSION: str = os.getenv("VERSION")
    API_V1_STR: str = "/api/v1"
    
    # Security: Mobile App (JWT)
    SECRET_KEY: str = os.getenv("SECRET_KEY")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7 
    
    # Security: Hardware (ESP32 API Key)
    X_API_KEY: str = os.getenv("X_API_KEY")
    
    # 💾 Database Connection String
    DATABASE_URL: str = os.getenv("DATABASE_URL")

    # 📡 MQTT Settings
    MQTT_BROKER: str = os.getenv("MQTT_BROKER")
    MQTT_PORT: int = int(os.getenv("MQTT_PORT") or 0)
    MQTT_TOPIC_SENSORS: str = os.getenv("MQTT_TOPIC_SENSORS")
    MQTT_TOPIC_AI: str = os.getenv("MQTT_TOPIC_AI")

    # 🌐 Network Settings
    API_HOST: str = os.getenv("API_HOST", "0.0.0.0")
    API_PORT: int = int(os.getenv("API_PORT", "8000"))
    
    # 🔄 Loopback
    API_LOOPBACK_URL: str = os.getenv("API_LOOPBACK_URL", "http://localhost:8000")

    # 🔧 Hardware Confirmation
    # When True, system config changes require ESP32 ACK before saving to DB.
    # Set to False to bypass for development without hardware.
    REQUIRE_ESP32_ACK: bool = os.getenv("REQUIRE_ESP32_ACK", "true").lower() == "true"

    class Config:
        case_sensitive = True

@lru_cache()
def get_settings():
    return Settings()

settings = get_settings()

from pydantic_settings import BaseSettings
from functools import lru_cache
from dotenv import load_dotenv, find_dotenv
import os
import pathlib

# 📂 Load Environment Variables
# find_dotenv() automatically searches upwards from this file 
# to find the project root where .env lives.
load_dotenv(find_dotenv())

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

    class Config:
        case_sensitive = True

@lru_cache()
def get_settings():
    return Settings()

settings = get_settings()

# backend/src/lettu_backend/services/mqtt/api_client.py
import urllib.request
import urllib.error
import json
import logging
from lettu_backend.core.config import settings

logger = logging.getLogger("MQTT_SERVICE")

class APIClient:
    """Handles cross-process loopback requests to the FastAPI backend."""
    
    @staticmethod
    def send_to_api(endpoint: str, payload: dict):
        base_url = f"http://localhost:8000/api/v1/{endpoint}"
        req = urllib.request.Request(base_url, method="POST")
        req.add_header('Content-Type', 'application/json')
        # Include API key in headers to bypass security checks from hardware simulators
        req.add_header('X-API-KEY', settings.X_API_KEY)
        
        try:
            urllib.request.urlopen(req, data=json.dumps(payload).encode('utf-8'))
            logger.info(f"✅ [API] POST success → /api/v1/{endpoint}")
        except Exception as api_err:
            logger.error(f"❌ [SUBSCRIBER] API POST Error on {endpoint}: {api_err}")

api_client = APIClient()

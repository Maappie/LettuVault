# cloud-server/src/cloud_backend/core/security.py
# Simple API Key guard — only edge vaults can POST to the sync endpoint.

from fastapi import HTTPException, Security, status
from fastapi.security import APIKeyHeader
from cloud_backend.core.config import settings

SYNC_API_KEY_NAME = "X-SYNC-API-KEY"
sync_api_key_header = APIKeyHeader(name=SYNC_API_KEY_NAME, auto_error=False)

MOBILE_API_KEY_NAME = "X-MOBILE-API-KEY"
mobile_api_key_header = APIKeyHeader(name=MOBILE_API_KEY_NAME, auto_error=False)

def require_sync_key(api_key: str = Security(sync_api_key_header)):
    """Guards the /sync endpoint. Only authenticated Edge Vaults may POST here."""
    if api_key == settings.CLOUD_SYNC_API_KEY:
        return True
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or missing X-SYNC-API-KEY. This vault is not authorized.",
    )

def require_mobile_key(api_key: str = Security(mobile_api_key_header)):
    """Guards mobile-facing GET endpoints. Only the Flutter app may read here."""
    if api_key == settings.CLOUD_MOBILE_API_KEY:
        return True
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or missing X-MOBILE-API-KEY.",
    )

# cloud-server/src/cloud_backend/core/security.py
# Auth utilities: bcrypt password hashing + JWT creation/verification.

import os
from datetime import datetime, timedelta, timezone

from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import HTTPException, Security, Request
from fastapi.security import APIKeyHeader

from cloud_backend.core.config import settings

# ── Password hashing ──────────────────────────────────────────────────────────
# Using pbkdf2_sha256 to avoid bcrypt's 72-character limit and version conflicts.
_pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")

def hash_password(plain: str) -> str:
    return _pwd_context.hash(plain)

def verify_password(plain: str, hashed: str) -> bool:
    return _pwd_context.verify(plain, hashed)


# ── JWT ───────────────────────────────────────────────────────────────────────
_ACCESS_TOKEN_EXPIRE_DAYS = 30

def create_access_token(email: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=_ACCESS_TOKEN_EXPIRE_DAYS)
    return jwt.encode(
        {"sub": email, "exp": expire},
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM,
    )

def decode_access_token(token: str) -> str:
    """Returns the email (sub) from a valid JWT, raises 401 otherwise."""
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        email: str = payload.get("sub")
        if not email:
            raise HTTPException(status_code=401, detail="Invalid token")
        return email
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired token")


# ── API Key Guards ────────────────────────────────────────────────────────────
_sync_key_header   = APIKeyHeader(name="X-SYNC-API-KEY",   auto_error=False)
_mobile_key_header = APIKeyHeader(name="X-MOBILE-API-KEY", auto_error=False)

def require_sync_key(key: str = Security(_sync_key_header)):
    if key != settings.CLOUD_SYNC_API_KEY:
        raise HTTPException(status_code=403, detail="Invalid sync API key")


def require_mobile_key(request: Request, key: str = Security(_mobile_key_header)) -> str | None:
    """
    Dual-mode auth guard for all mobile-facing GET endpoints.

    Accepts EITHER:
      1. JWT Bearer token  → preferred method from the Flutter mobile app
                             (sent as 'Authorization: Bearer <token>')
      2. X-MOBILE-API-KEY → static key for backwards-compat / simulator testing

    Returns the user's email if authenticated via JWT, otherwise returns None.
    """
    # --- Path 1: JWT Bearer Token (Mobile App — Online Mode) ---
    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        token = auth_header[len("Bearer "):].strip()
        if token:
            # decode_access_token raises 401 automatically on failure
            email = decode_access_token(token)
            return email  # ✅ JWT is valid — return email
        # Empty bearer string → fall through to API key check

    # --- Path 2: Static API Key (Simulator / Manual Testing) ---
    if key and key == settings.CLOUD_MOBILE_API_KEY:
        return None  # ✅ Key matches — return None

    # --- Nothing matched ---
    raise HTTPException(
        status_code=403,
        detail="Access denied. Provide a valid Bearer token or X-MOBILE-API-KEY."
    )

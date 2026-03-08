# backend/src/lettu_backend/core/security.py
import os
from datetime import datetime, timedelta
from typing import Any, Union, Optional

from fastapi import HTTPException, Security, status
from fastapi.security import APIKeyHeader, OAuth2PasswordBearer
from jose import jwt, JWTError
from passlib.context import CryptContext

from lettu_backend.core.config import settings

# --- Setup ---
# OAuth2 for the Flutter Mobile App
oauth2_scheme = OAuth2PasswordBearer(tokenUrl=f"{settings.API_V1_STR}/auth/login")

# API Key for the ESP32 Hardware
API_KEY_NAME = "X-API-KEY"
api_key_header = APIKeyHeader(name=API_KEY_NAME, auto_error=False)

# Password Hashing for the Database
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# --- Password Logic (For User Creation/Login) ---
def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)


# --- JWT Token Logic (For Flutter Logins) ---
def create_access_token(subject: Union[str, Any], expires_delta: Optional[timedelta] = None) -> str:
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode = {"exp": expire, "sub": str(subject)}
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt

def decode_token(token: str) -> Optional[str]:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        return payload.get("sub")
    except JWTError:
        return None


# --- Dependency: Verify Hardware (ESP32) ---
def get_current_active_device(api_key: str = Security(api_key_header)):
    if api_key == settings.X_API_KEY:
        return True
    
    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Unauthorized access. Invalid API Key. This device is not recognized.",
    )


# --- Dependency: Verify User (Flutter) ---
# This will be used in future routes to check if a user is logged in
def get_current_user(token: str = Security(oauth2_scheme)):
    user_id = decode_token(token)
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials. Please log in again.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user_id # Later this will return a full user object from the DB

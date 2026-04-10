# cloud-server/src/cloud_backend/main.py
# Stripped-down FastAPI application for the cloud mirror.
# No MQTT. No hardware. No AI. Data mirror + sync endpoint only.

from fastapi import FastAPI
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware

from cloud_backend.core.config import settings
from cloud_backend.api.v1.endpoints import router as api_v1_router

app = FastAPI(
    title=settings.PROJECT_NAME,
    description=(
        "LettuVault Cloud Mirror — Receives batched data from local Edge Vaults "
        "and exposes it to the mobile app. Does NOT contain MQTT, AI, or hardware logic."
    ),
    version=settings.VERSION,
)

# Allow Flutter mobile app from any origin
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount versioned routes
app.include_router(api_v1_router, prefix=settings.API_V1_STR)


@app.on_event("startup")
def startup_event():
    """Auto-create cloud tables on first boot."""
    from cloud_backend.models.database import Base, engine
    Base.metadata.create_all(bind=engine)


@app.get("/cloud-server-health", tags=["Health"], include_in_schema=False)
def health_check():
    return {
        "service": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "status": "Online",
    }


@app.get("/", tags=["UI"], include_in_schema=False)
@app.get("/home", tags=["UI"], include_in_schema=False)
def get_home_dashboard():
    template_path = os.path.join(os.path.dirname(__file__), "template", "home.html")
    return FileResponse(template_path)


from fastapi.responses import FileResponse
import os

@app.get("/love", tags=["UI"], include_in_schema=False)
def get_romantic_dashboard():
    # Serve the love.html template from the template folder
    template_path = os.path.join(os.path.dirname(__file__), "template", "love.html")
    return FileResponse(template_path)

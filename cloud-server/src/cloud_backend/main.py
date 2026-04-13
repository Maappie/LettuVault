# cloud-server/src/cloud_backend/main.py
# Stripped-down FastAPI application for the cloud mirror.
# No MQTT. No hardware. No AI. Data mirror + sync endpoint only.

from fastapi import FastAPI
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.templating import Jinja2Templates
from fastapi import Request

from cloud_backend.core.config import settings
from cloud_backend.api.v1.endpoints import router as api_v1_router
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import os

app = FastAPI(
    title=settings.PROJECT_NAME,
    description=(
        "LettuVault Cloud Mirror — Receives batched data from local Edge Vaults "
        "and exposes it to the mobile app. Does NOT contain MQTT, AI, or hardware logic."
    ),
    version=settings.VERSION,
)

static_dir = os.path.join(os.path.dirname(__file__), "global", "static")
if os.path.exists(static_dir):
    app.mount("/static", StaticFiles(directory=static_dir), name="static")

_template_dir = os.path.join(os.path.dirname(__file__), "template")
templates = Jinja2Templates(directory=_template_dir)

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
    """Run Alembic migrations on every deploy — ensures schema is always up to date."""
    from cloud_backend.core.migrate import run_migrations
    run_migrations()


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
    template_path = os.path.join(os.path.dirname(__file__), "template", "love.html")
    return FileResponse(template_path)


@app.get("/accounts", tags=["UI"], include_in_schema=False)
def get_accounts_page(request: Request):
    """Admin view: list all registered cloud users."""
    from cloud_backend.models.database import SessionLocal
    from cloud_backend.repository.cloud_repo import CloudRepository
    db = SessionLocal()
    try:
        repo = CloudRepository(db)
        users = repo.get_all_users()
        rows = [
            {
                "id":         u.id,
                "email":      u.email,
                "is_active":  u.is_active,
                "created_at": u.created_at.strftime("%Y-%m-%d %H:%M") if u.created_at else "—",
            }
            for u in users
        ]
    finally:
        db.close()
    return templates.TemplateResponse(
        "accounts.html", {"request": request, "users": rows, "total": len(rows)}
    )

from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import pathlib
import os

from lettu_backend.core.config import settings
from lettu_backend.api.v1.endpoints import router as api_v1_router
from lettu_backend.services.mqtt_service import mqtt_service

# 📂 Set up templates directory
template_dir = pathlib.Path(__file__).parent.resolve() / "templates"
templates = Jinja2Templates(directory=str(template_dir))

# 🛠️ Root FastAPI Application
app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Relational data gateway for LettuVault AI and IoT Sensors.",
    version=settings.VERSION
)

# 🚀 Mount Versioned API Router
app.include_router(api_v1_router, prefix="/api/v1")

# 📸 Serve AI snapshot images from data/captures/
CAPTURES_DIR = os.path.join("data", "captures")
os.makedirs(CAPTURES_DIR, exist_ok=True)
app.mount("/captures", StaticFiles(directory=CAPTURES_DIR), name="captures")

@app.on_event("startup")
def startup_event():
    mqtt_service.start()

# 🔒 CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/", tags=["UI"])
async def root():
    return {"message": "LettuVault API Multi-Table Gateway", "status": "Online"}

@app.get("/dashboard", response_class=HTMLResponse, tags=["UI"])
async def data_dashboard(request: Request):
    return templates.TemplateResponse(
        request=request, 
        name="dashboard.html", 
        context={"project_name": settings.PROJECT_NAME, "x_api_key": settings.X_API_KEY}
    )

@app.get("/simulator", response_class=HTMLResponse, tags=["UI"])
async def hardware_simulator(request: Request):
    return templates.TemplateResponse(
        request=request, 
        name="simulator.html", 
        context={"project_name": settings.PROJECT_NAME, "x_api_key": settings.X_API_KEY}
    )

# --- Shortcuts for Command Line Interaction ---
def run_upgrade():
    import subprocess, sys
    subprocess.run([sys.executable, "-m", "alembic", "-c", "backend/alembic.ini", "upgrade", "head"])

def run_system():
    """Unified TUI Launcher with log switching."""
    from lettu_backend.services.log_hub import launch_hub
    launch_hub()

from fastapi import FastAPI, Depends, Security, HTTPException, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
import os
import pathlib

from lettu_backend.core.config import settings
from lettu_backend.core.security import get_current_active_device
from lettu_backend.models.database import SessionLocal, ScanRecord
from lettu_backend.models.domain import ScanRecordResponse, ScanRecordCreate
from lettu_backend.repository.scan_repo import ScanRepository
from sqlalchemy import inspect

# 📂 Set up templates directory
# Resolves to: backend/src/lettu_backend/templates
template_dir = pathlib.Path(__file__).parent.resolve() / "templates"
templates = Jinja2Templates(directory=str(template_dir))

# 🛠️ Database Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# 📝 Dynamic Documentation: Auto-generating the Schema Table
def get_dynamic_schema_table():
    """Inspected the SQLAlchemy model to build a Markdown table for the docs."""
    mapper = inspect(ScanRecord)
    table_md = "### 💾 Live Database Schema: `scans` table\n"
    table_md += "| Column | Type | Description |\n| :--- | :--- | :--- |\n"
    
    for column in mapper.attrs:
        col_name = column.key
        col_type = type(column.columns[0].type).__name__
        
        descriptions = {
            "id": "Unique identifier (Primary Key)",
            "timestamp": "When the scan was recorded",
            "worm_count": "Number of worms detected by AI",
            "confidence_score": "Digital certainty (0.0 - 1.0)",
            "image_name": "Stored file reference",
            "box_id": "Hardware ID of the LettuVault",
            "temperature": "Ambient temperature (C)",
            "humidity": "Air moisture reading (%)",
            "name": "Custom labels or notes"
        }
        desc = descriptions.get(col_name, "Dynamic field added to schema")
        table_md += f"| **{col_name}** | {col_type} | {desc} |\n"
    
    return table_md

# 🛠️ Root FastAPI Application
app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Central communication gateway for LettuVault storage, AI analysis, and embedded hardware.",
    version=settings.VERSION,
    openapi_tags=[
        {"name": "System Health", "description": "Core system status and heartbeat."},
        {"name": "Sensors", "description": "Environmental data (Temperature, Humidity, etc.) from the vault."},
        {"name": "AI", "description": "Worm detection results and confidence scoring."},
        {"name": "Controls", "description": "System actuators and parameter overrides."},
        {"name": "Test Send", "description": "Manual data injection for testing and debugging."},
        {"name": "Test Request", "description": "Specific data retrieval queries."}
    ]
)

# Exception handler for more info
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={"message": str(exc), "type": type(exc).__name__},
    )

# 🔒 CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/", tags=["System Health"])
async def root():
    return {
        "message": f"Welcome to {settings.PROJECT_NAME}",
        "status": "Online",
        "version": settings.VERSION,
        "simulator": "/simulator",
        "endpoints": {
            "documentation": "/docs",
            "active_scans": "/api/v1/scans"
        }
    }

@app.get("/simulator", response_class=HTMLResponse, tags=["System Health"])
async def hardware_simulator(request: Request):
    """
    ### 🥬 LettuVault Device Hub
    A premium interface for simulating hardware IoT devices. 
    Use this to inject data into the system without technical Swagger clutter.
    """
    return templates.TemplateResponse(
        request=request, 
        name="simulator.html", 
        context={
            "project_name": settings.PROJECT_NAME,
            "x_api_key": settings.X_API_KEY
        }
    )

@app.get("/api/v1/scans", response_model=list[ScanRecordResponse], tags=["Sensors", "AI"], dependencies=[Depends(get_current_active_device)])
def get_database_preview(db: Session = Depends(get_db)):
    """
    ### 👁️ Unified Data Feed
    This view combines both **Environmental (Sensors)** and **Intelligence (AI)** data 
    into a single historical timeline.

    ---
    {get_dynamic_schema_table()}
    """
    repo = ScanRepository(db)
    return repo.get_all_scans()

# --- 🧪 Testing & Debugging Endpoints ---

@app.post("/api/v1/scans", response_model=ScanRecordResponse, tags=["Test Send"], dependencies=[Depends(get_current_active_device)])
def create_test_scan(scan_in: ScanRecordCreate, db: Session = Depends(get_db)):
    """
    ### 📥 Inject Test Data
    Use this to manually push a record into the database. 
    Ideal for testing how the Mobile App or AI UI reacts to new data.
    """
    repo = ScanRepository(db)
    return repo.create_scan(scan_in.model_dump())

@app.get("/api/v1/scans/{scan_id}", response_model=ScanRecordResponse, tags=["Test Request"], dependencies=[Depends(get_current_active_device)])
def get_specific_scan(scan_id: int, db: Session = Depends(get_db)):
    """
    ### 🔍 Find by ID
    Fetch exactly one row from the database using its unique numeric ID.
    """
    repo = ScanRepository(db)
    db_scan = repo.get_scan_by_id(scan_id)
    if not db_scan:
        raise HTTPException(status_code=404, detail=f"Scan with ID {scan_id} not found.")
    return db_scan

# 🔐 Production Security:
# Implementation of JWT or API Keys for production would go here.
# For now, we are using the basic X-API-KEY security check for the Hardware.

def run_migration():
    """Shortcut for: alembic revision --autogenerate"""
    import subprocess
    import sys
    import pathlib
    
    # 📁 Ensure data directory exists
    pathlib.Path("data").mkdir(exist_ok=True)
    
    desc = sys.argv[1] if len(sys.argv) > 1 else "auto_migration"
    print(f"[DB] Generating migration in root context: {desc}...")
    
    # Run alembic from the Current Working Directory to ensure exact relative path matching
    subprocess.run([sys.executable, "-m", "alembic", "-c", "backend/alembic.ini", "revision", "--autogenerate", "-m", desc])

def run_upgrade():
    """Shortcut for: alembic upgrade head"""
    import subprocess
    import sys
    import pathlib
    
    # 📁 Ensure data directory exists
    pathlib.Path("data").mkdir(exist_ok=True)
    
    print("[DB] Upgrading database to latest version in root context...")
    subprocess.run([sys.executable, "-m", "alembic", "-c", "backend/alembic.ini", "upgrade", "head"])

def run_history():
    """Shortcut for: alembic history --verbose"""
    import subprocess
    import sys
    
    print("[DB] Database Migration History:")
    subprocess.run([sys.executable, "-m", "alembic", "-c", "backend/alembic.ini", "history", "--verbose"])

def run_status():
    """Shortcut for: alembic current"""
    import subprocess
    import sys
    
    print("[DB] Current Database Status:")
    subprocess.run([sys.executable, "-m", "alembic", "-c", "backend/alembic.ini", "current"])

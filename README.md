
---

## 📂 Updated LettuVault Structure

```text
LettuVault/                     <-- Root Folder (The Workspace)
├── .venv/                      <-- Python Virtual Environment (Keep this active!)
├── pyproject.toml              <-- Root Workspace Config (Maps all packages)
├── requirements.txt            <-- Master List (Contains all libraries + "-e .")
├── .gitignore                  <-- Ignores .venv, __pycache__, and .egg-info
│
├── ai_system/                  <-- AI Worker (Package: lettu_vault_ai)
│   ├── pyproject.toml          <-- AI Package Config (Lists torch, ultralytics, etc.)
│   ├── yolov8n.pt              <-- Your YOLO model weights
│   ├── datasets/               <-- Training/Validation images
│   └── src/
│       └── lettu_vault_ai/     <-- Core AI Code Folder
│           ├── __init__.py
│           ├── detector.py     <-- Hybrid Zoom & Detection Logic
│           └── main.py         <-- MQTT Listener (AI Service Entry)
│
├── backend/                    <-- Web Server (Package: lettu_backend)
│   ├── pyproject.toml          <-- Backend Package Config (Lists fastapi, uvicorn)
│   └── src/
│       └── lettu_backend/      <-- Core Backend Code Folder
│           ├── __init__.py
│           ├── main.py         <-- FastAPI Endpoints & App Initialization
│           ├── test_link.py    <-- Script to verify cross-package connection
│           └── db_manager.py   <-- SQLite/Database Logic
│
├── embedded/                   <-- C++/Arduino: ESP32 Source Code
└── mobile/                     <-- Flutter: Mobile App Source Code

```

---

## 🛠️ Complete Setup Steps

### 1. Environment Creation

Open PowerShell inside the `LettuVault` root folder:

```powershell
# Create the environment
python -m venv .venv

# Activate it
.\.venv\Scripts\Activate.ps1

```

### 2. The "One-Command" Installation

This command reads your `requirements.txt`, installs the external libraries, and then hits the `-e .` line which uses your root `pyproject.toml` to link `lettu_vault_ai` and `lettu_backend` automatically.

```powershell
pip install -r requirements.txt

```

### 3. Verification

Run these to ensure the "Invisible Bridge" between packages is working:

```powershell
# Check AI Package
python -c "import lettu_vault_ai; print('AI System: Linked Successfully')"

# Check Backend Package
python -c "import lettu_backend; print('Backend System: Linked Successfully')"

```

---

## 🚀 How to Run the System

Since you are using a **Distributed Architecture**, you will run the services in separate terminal windows.

**Terminal 1: The AI Worker**
(Handles the heavy lifting: image processing and YOLO inference)

```powershell
python -m lettu_vault_ai.main

```

**Terminal 2: The Web Server**
(Handles the API requests from your Flutter app and ESP32)

```powershell
# We use 'lettu_backend.main:app' because of our package mapping
uvicorn lettu_backend.main:app --reload

```

---

### 💡 Pro-Tip for your Thesis

By using the `-m` flag (e.g., `python -m lettu_vault_ai.main`), you are telling Python to run the script **as a module**. This ensures that all your internal imports work perfectly regardless of which folder you are currently standing in.


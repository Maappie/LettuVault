
---

## 📂 Updated LettuVault Structure

```text
LettuVault/                   <-- Root Folder
├── .venv/                    <-- Python Virtual Environment (Keep this active!)
├── requirements.txt          <-- Master List (Contains all libraries + -e links)
├── .gitignore                <-- Ignores .venv, __pycache__, and .egg-info
│
├── ai_system/                <-- AI Worker (Package: lettu_vault_ai)
│   ├── pyproject.toml        <-- Package Config
│   ├── yolov8n.pt            <-- Your YOLO model
│   ├── datasets/             <-- Training/Validation images
│   └── src/
│       └── lettu_vault_ai/   <-- Core Code Folder
│           ├── __init__.py
│           ├── detector.py   <-- Hybrid Zoom & Detection Logic
│           └── main.py       <-- MQTT Listener (Worker)
│
├── backend/                  <-- Web Server (Package: lettu_api)
│   ├── pyproject.toml
│   └── src/
│       └── lettu_backend/        <-- Core Code Folder
│           ├── __init__.py
│           ├── main.py       <-- FastAPI Endpoints
│           └── db_manager.py <-- SQLite/Database Logic
│
├── embedded/                 <-- C++/Arduino: ESP32 Source Code
│   └── /
│
└── mobile/                   <-- Flutter: Mobile App Source Code
    └── /

```

---

## 🛠️ Complete Setup Steps (For You & Your Teammates)

If your teammate clones this project tomorrow, they just need to follow these exact steps to be up and running in minutes.

### 1. Environment Creation

Open PowerShell inside the `LettuVault` folder:

```powershell
# Create the environment (Using 3.10.11)
py -3.10 -m venv .venv

# Activate it
.\.venv\Scripts\Activate

```

### 2. The "One-Command" Installation

This installs the AI libraries, the Web Server, and **links** your local folders so they can talk to each other.

```powershell
pip install -r requirements.txt

```

### 3. Verification

Run these to make sure Python "sees" your packages:

```powershell
# Check AI
python -c "import lettu_vault_ai; print('AI System: Ready')"

# Check Backend
python -c "import lettu_backend; print('Backend System: Ready')"

```

---

## 🚀 How to Run the System

Since we are using the **Worker Pattern**, you run them as two separate services.

**Terminal 1 (The AI Worker):**
It stays on, manages the camera, and waits for MQTT commands.

```powershell
python -m lettu_vault_ai.main

```

**Terminal 2 (The Web Server):**
It listens for the App and the ESP32.

```powershell
# Run from the root folder
uvicorn lettu_api.main:app --reload

```

---

### Why this is a winner:

* **Separation of Concerns:** Your AI code doesn't care about HTTP requests, and your Web Server doesn't care about camera focal lengths.
* **Teammate Friendly:** Your teammate doesn't have to guess which folder to install first. The `requirements.txt` handles the order.
* **Clean Imports:** You can now write `from lettu_vault_ai.detector import WormDetector` anywhere in your project.

**Would you like me to provide the basic `main.py` code for the `lettu_api` so you can test the connection to the AI?**
# 🚀 How to Run LettuVault

Use this guide for daily development. This assumes you have already done the one-time setup (venv and pip install).

## 1. Activate the Environment
Open PowerShell in the root `LettuVault` folder and run:
```powershell
.\.venv\Scripts\Activate.ps1
```
*You should see `(.venv)` in your prompt.*

## 2. Start the System
Run the bootstrapper script:
```powershell
python start.py
```
This starts the **FastAPI Backend** and prepares the **AI System** paths.

---

## 🔗 Quick Links (API Access)

Once the system is running, you can access these local URLs:

| Page | URL | Description |
| :--- | :--- | :--- |
| **Home Interface** | [http://127.0.0.1:8000/](http://127.0.0.1:8000/) | Basic JSON health/status check. |
| **Interactive Docs** | [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs) | **Swagger UI**: Test your API calls here directly. |
| **Alternative Docs** | [http://127.0.0.1:8000/redoc](http://127.0.0.1:8000/redoc) | **ReDoc**: Clean, organized documentation view. |
| **Health Check** | [http://127.0.0.1:8000/health](http://127.0.0.1:8000/health) | Simple status check for monitoring. |

---

## 💡 Troubleshooting
* **ModuleNotFoundError**: If it says `lettu_backend` or `lettu_vault_ai` not found, make sure you are running `python start.py` from the root folder, not inside a sub-folder.
* **Port in Use**: If you get a "Bind" error, another app is using port `8000`. You can change this in `start.py`.

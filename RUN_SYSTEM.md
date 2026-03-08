# 🚀 How to Run LettuVault

Use this guide for daily development. This assumes you have already done the one-time setup (venv and pip install).

## 1. Activate the Environment

Open PowerShell in the root `LettuVault` folder and run:

```powershell
.\.venv\Scripts\Activate.ps1
```

_You should see `(.venv)` in your prompt._

## 2. Start the System

Run the bootstrapper script:

```powershell
python start.py
```

This starts the **FastAPI Backend** and prepares the **AI System** paths.

---

## 🔗 Quick Links (API Access)

Once the system is running, you can access these local URLs:

| Page                 | URL                                                          | Description                                        |
| :------------------- | :----------------------------------------------------------- | :------------------------------------------------- |
| **Home Interface**   | [http://127.0.0.1:8000/](http://127.0.0.1:8000/)             | Basic JSON health/status check.                    |
| **Interactive Docs** | [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)     | **Swagger UI**: Test your API calls here directly. |
| **Alternative Docs** | [http://127.0.0.1:8000/redoc](http://127.0.0.1:8000/redoc)   | **ReDoc**: Clean, organized documentation view.    |
| **Health Check**     | [http://127.0.0.1:8000/health](http://127.0.0.1:8000/health) | Simple status check for monitoring.                |

---

## 🔐 Security Information

The system now has **Production-Level Security** enabled. Some endpoints (like the hardware data routes) require an **API Key**.

- **Header Name**: `X-API-KEY`
- **Default Key**: `lettuce-master-key-2024` (Change this in `.env`!)

To test a protected route in Swagger (`/docs`), click the **Authorize** button (🔒) and enter the key.

---

## 💾 Database Migrations (Simplified)

I've created shortcuts so you don't have to remember long commands. Whenever you change your models in `database.py`:

1.  **Generate a Migration**:
    ```powershell
    db-migrate "Added a new column"
    ```
2.  **Apply the Change**:
    ```powershell
    db-upgrade
    ```

---

## 💡 Troubleshooting

- **ModuleNotFoundError**: If it says `lettu_backend` or `lettu_vault_ai` not found, make sure you are running `python start.py` from the root folder, not inside a sub-folder.
- **Port in Use**: If you get a "Bind" error, another app is using port `8000`. You can change this in `start.py`.

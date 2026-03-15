# How to Run LettuVault

Use this guide for daily development.

## 1. Activate the Environment

```powershell
.\.venv\Scripts\Activate.ps1
```

You should see `(.venv)` in your prompt.

## 2. Start the Full System (Recommended)

```powershell
lettu_vault_start
```

This launches an interactive **TUI** (Terminal UI) in your VS Code terminal with **4 live log feeds**:

| Tab | Color | What it does |
|---|---|---|
| **BROKER** | Yellow | Local MQTT message hub on `127.0.0.1:1883` |
| **BACKEND** | Green | FastAPI server on `http://localhost:8000` |
| **MQTT** | Cyan | Listens for AI & Sensor data, saves to database |
| **AI** | Magenta | Camera + YOLO AI detection with 3s stability check |

**Controls:**
- `j` — Switch to next tab
- `k` — Switch to previous tab
- `q` — Quit and stop all services

---

## Understanding the 3-Second Safety Rule

The AI will **only save** a detection to the database if:
1. The object is continuously visible for **3000ms (3 seconds)**
2. Brief disappearances under **600ms** are tolerated (Grace Period)
3. Data is sent **once per stable event** (no duplicate flooding)

You'll see this in the AI log tab:
```
Object detected! [0/3000ms]
Stability Check: 600/3000ms
Stability Check: 1200/3000ms
...
Stability Reached: 3000/3000ms. Data Sent!
```

---

## MQTT Topics

| Topic | Publisher | Subscriber | Stored In |
|---|---|---|---|
| `lettuvault/ai` | AI Camera (`predict.py`) | `mqtt_service.py` | `ai_scans` table |
| `lettuvault/sensors` | ESP32 Hardware | `mqtt_service.py` | `sensor_readings` table |

---

## Quick Links (Backend Running)

| Page | URL |
|---|---|
| API Health | http://127.0.0.1:8000/ |
| Live Dashboard | http://127.0.0.1:8000/dashboard |
| Swagger API Docs | http://127.0.0.1:8000/docs |
| Hardware Simulator | http://127.0.0.1:8000/simulator |

---

## Security

- **Header Name**: `X-API-KEY`
- **Default Key**: `lettuce-master-key-2024`
- Change it in your `.env` file

---

## Troubleshooting

| Problem | Solution |
|---|---|
| `lettu_vault_start` not found | Run `pip install -e .` with `.venv` active |
| Port 8000 already in use | `netstat -ano \| findstr :8000` then `taskkill /F /PID <id>` |
| BROKER tab shows errors | Wait a few seconds — broker needs time to boot |
| AI tab stuck | Check if camera is connected (index `0`) |

---
trigger: always_on
---

# AI System Rules — LettuVault
# Package: lettu_vault_ai
# Location: ai_system/src/lettu_vault_ai/

---

## Directory Structure

```
ai_system/src/lettu_vault_ai/
├── predict.py   — Main loop: camera → YOLO → debounce → MQTT publish
└── config.py    — AI-specific overrides (camera index, confidence, model path)
```

---

## Detection Classes

| Class | Scan Type |
|---|---|
| `lettuce`, `strawberry` | `produce` — one-shot, triggered by MQTT command |
| `worms`, `wilting` | `condition` — continuous background monitoring |

---

## Stability & Debounce Rules

- Object must be **continuously visible for 3 seconds** before MQTT publish fires.
- Brief disappearances of **< 600ms** are forgiven (grace period).
- Data is sent **once per stable event** — no duplicate flooding.
- A **10-second debounce** per scan type is enforced in `ai_handler.py` on the backend side.
- **DO NOT change** the 3-second stability check or 600ms grace period without explicit user approval.

---

## Code Rules

- `predict.py` MUST declare `global PRODUCE_SCAN_REQUESTED, scan_start_time` at the very top of `run_live_camera()`. Removing this line causes an `UnboundLocalError` crash loop.
- Model path resolution MUST use `PROJECT_ROOT` imported from `lettu_backend.core.config`. Never use manual `__file__` tree climbing (`os.path.dirname(os.path.dirname(...))`) to find model weights.
- MQTT broker settings come from `settings.MQTT_BROKER` / `settings.MQTT_PORT`. AI-specific overrides may come from `ai_cfg` (config.py in the ai package).
- The `train_thesis.py` script MUST also use `PROJECT_ROOT` from `lettu_backend.core.config` — never hardcode user paths like `C:\Users\Raiz\...`.

---

## MQTT Communication

- **Publishes to:** `lettuvault/ai` (detection results with base64 image)
- **Subscribes to:** `lettuvault/control` (listens for `TRIGGER_PRODUCE_SCAN` command)

### Published Payload Format

```json
{
  "api_key": "<X_API_KEY from .env>",
  "scan_type": "produce | condition",
  "worm_count": 0,
  "confidence_score": 0.87,
  "image_b64": "<base64 JPG>",
  "label": "1 lettuce",
  "produce_type": "Lettuce | Strawberry | Empty / Unknown | null"
}
```

---

## Configuration

All runtime settings come from `.env` via `settings`. AI-specific overrides (camera index, model path, confidence threshold) live in `ai_system/src/lettu_vault_ai/config.py`.

```python
CONFIDENCE_THRESHOLD = 0.2   # 0.0 = detect everything, 1.0 = very strict
CAMERA_INDEX = 0             # Default webcam
STABILITY_SECONDS = 3.0
GRACE_PERIOD_SECONDS = 0.6
MODEL_PATH = None            # Set to override auto-discovery
```

---

## Running

```powershell
# As part of the full system (recommended)
lettu_vault_start

# Standalone
python -m lettu_vault_ai.predict
```

# AI System — LettuVault

Handles real-time camera detection using YOLOv8 and publishes results to the local MQTT broker.

---

## What it does

1. Opens the webcam (index `0`)
2. Runs each frame through the custom YOLOv8 model (`lettuce_strawberry_v12`)
3. Applies a **3-second stability check** before sending data
4. Publishes detection results to `lettuvault/ai` topic on the local MQTT broker

---

## Running (Recommended: use the unified launcher)

```powershell
lettu_vault_start
```

This starts the AI as the `[AI]` tab in the TUI.

**Or run standalone:**
```powershell
python -m lettu_vault_ai.predict
```

---

## Configuration

All settings are at the top of `src/lettu_vault_ai/predict.py`:

```python
# Adjust detection sensitivity (0.0 = everything, 1.0 = strict)
CONFIDENCE_THRESHOLD = 0.2

# MQTT settings (read from .env via config.py)
MQTT_BROKER  = settings.MQTT_BROKER        # default: 127.0.0.1
MQTT_PORT    = settings.MQTT_PORT          # default: 1883
MQTT_TOPIC   = settings.MQTT_TOPIC_AI      # default: lettuvault/ai
```

---

## Detection Classes

| Class | Description |
|---|---|
| `lettuce` | Healthy lettuce plant |
| `wilting` | Wilting/unhealthy lettuce |
| `worms` | Pest/worm detected |
| `strawberry` | Strawberry plant |

---

## Stability Check Logic

```
Object detected! [0/3000ms]         ← Timer starts
Stability Check: 600/3000ms         ← Progress update every 300ms
Stability Check: 1200/3000ms
...
Stability Reached: 3000/3000ms. Data Sent!   ← MQTT publish fires
```

- Object must be **continuously visible for 3 seconds**
- Brief disappearances of **< 600ms** are forgiven (grace period)
- Data is sent **once per stable event** to avoid duplicates

---

## Training

```powershell
cd ai_system
python train_thesis.py
```

Model weights will be saved to `runs/lettuce_strawberry_v12/weights/best.pt`.

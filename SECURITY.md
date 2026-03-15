# LettuVault Security Architecture

---

## 1. Hardware Security (ESP32)

ESP32 uses **API Key Authentication** — lightweight and hardware-friendly.

- **Header**: `X-API-KEY`
- **Default Key**: `lettuce-master-key-2024`  
- **Change it**: Edit `X_API_KEY` in your `.env` file

---

## 2. Mobile App Security (Flutter)

Flutter uses **JWT (JSON Web Tokens)**.

- **OAuth2 Password Bearer**: Standard login flow
- **Stateless**: No session storage needed
- **Token Expiration**: Auto-expires after 7 days

---

## 3. MQTT Security

The local broker (`127.0.0.1:1883`) uses **anonymous connections** by design for local development.

> For production deployment: set `MQTT_BROKER` in `.env` to a private broker address and add `username_pw_set()` in both `mqtt_service.py` and `predict.py`.

---

## 4. Data Safety

- **Password Hashing**: Bcrypt via `passlib` — never stores plain-text passwords
- **Environment Variables**: All secrets in `.env` (gitignored)
- **CORS**: Configured to allow Flutter app communication

---

## Environment Configuration (`.env`)

```bash
PROJECT_NAME="LettuVault API"
VERSION="0.1.0"
SECRET_KEY="replace-this-with-a-random-hex-string"   # openssl rand -hex 32
X_API_KEY="lettuce-master-key-2024"
DATABASE_URL="sqlite:///data/lettu_vault.db"

# MQTT Settings
MQTT_BROKER="127.0.0.1"            # Change to "broker.hivemq.com" for public
MQTT_PORT=1883
MQTT_TOPIC_SENSORS="lettuvault/sensors"
MQTT_TOPIC_AI="lettuvault/ai"
```

### Setup for a Teammate:
1. Copy the template: `cp .env.example .env`
2. Adjust `SECRET_KEY` and `X_API_KEY`
3. **Never commit `.env`** — it is in `.gitignore`

---

## Testing Protected Routes

1. Start the system: `lettu_vault_start`
2. Open [Swagger UI](http://127.0.0.1:8000/docs)
3. Click **Authorize** (top right)
4. Enter your `X_API_KEY` value from `.env`

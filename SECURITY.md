# 🛡️ LettuVault Security Architecture

This document explains the **Production-Level Security** implemented in the LettuVault system. We use a dual-layer security approach to handle both **Hardware (IoT)** and **Mobile App** connections.

---

## 1. 🔑 Hardware Security (ESP32)

For the ESP32 hardware, we use **API Key Authentication**. This is lightweight and doesn't require the hardware to handle complex login/session logic.

- **Header**: `X-API-KEY`
- **Mechanism**: The backend checks for the presence of this header in every request from the hardware.
- **Benefit**: Scopes access only to recognized devices.

---

## 2. 📱 Mobile App Security (Flutter)

For the Flutter mobile application, we use **JWT (JSON Web Tokens)**. This is the industry standard for secure modern applications.

- **OAuth2 Password Bearer**: Standardized login flow.
- **Stateless**: The server doesn't need to store sessions in a database, making it faster and more scalable.
- **Token Expiration**: Tokens expire automatically after a set time (default: 7 days) to minimize risk if a device is lost.

---

## 3. 🔒 Data Safety

- **Password Hashing**: We NEVER store plain-text passwords. We use the **Bcrypt** algorithm (via `passlib`) to salt and hash passwords before they enter the database.
- **Environment Variables**: All secret keys are stored in a `.env` file, which is kept separate from the source code.
- **CORS (Cross-Origin Resource Sharing)**: Configured to allow secure communication between the Flutter Web/App and the Backend API.

---

## 📋 Environment Configuration (`.env`)

The system expects an `.env` file in the root folder to manage its configuration.

### 🏠 How to Setup for Teammates:

1.  **Copy the template**: `cp .env.example .env`
2.  **Adjust the values**: Change the `SECRET_KEY` and `X_API_KEY` to your local development preferences.
3.  **DO NOT COMMIT**: The `.env` file is already in our `.gitignore` to prevent leaking secret keys to GitHub.

---

## 📋 How to Manage Keys

1.  **Open `.env`**: Located in the root folder.
2.  **Change `X_API_KEY`**: Set this to a unique string for your hardware.
3.  **Change `SECRET_KEY`**: In a real production deployment, generate a random 32-character hex string (e.g., using `openssl rand -hex 32`).

---

## 🛠️ Testing Protected Routes

1.  Run the system: `python start.py`
2.  Open [Swagger UI](http://127.0.0.1:8000/docs).
3.  Any route with a 🔒 icon requires authorization.
4.  Click **Authorize** at the top right, enter the key from your `.env` file, and you are ready to test!

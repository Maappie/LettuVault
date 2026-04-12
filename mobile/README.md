# Mobile — LettuVault (Flutter)
# Owner: Meyvn
# Status: Work In Progress

---

## Overview

Flutter mobile app for monitoring and configuring the LettuVault greenhouse system.
Connects to the FastAPI backend over the local network (or future cloud deployment).

---

## Current Status

| Feature | Status |
|---|---|
| Login / JWT Authentication | ❌ Not built |
| Live Sensor Dashboard (real API) | 🟡 Simulation only |
| AI Scan Results Screen | ❌ Not built |
| System Config (set T/H/P from app) | ❌ Not built |
| Threshold Alerts (push notifications) | ✅ Done |
| Dark / Light Theme | ✅ Done |
| CSV Sensor Logging | ✅ Done |
| Detail Charts per Sensor | ✅ Done |
| VPD Calculation | ✅ Done |

---

## Clean Architecture Design

The app follows **Feature-First Clean Architecture** with three strict layers per feature.

```
Presentation Layer  →  Domain Layer  →  Data Layer
(UI / Controllers)     (Models)         (Repositories / API)
```

### Target Folder Structure

```
lib/
├── main.dart                        — App entry, theme, routing
├── app/
│   ├── router.dart                  — GoRouter route definitions
│   └── theme.dart                   — Light/Dark ThemeData
│
├── core/
│   ├── constants.dart               — kBaseUrl, kApiPrefix, headers
│   ├── api_client.dart              — HTTP wrapper (injects auth headers)
│   ├── auth_token_store.dart        — SharedPreferences: save/load JWT
│   └── exceptions.dart             — ApiException, AuthException
│
├── features/
│   ├── auth/                        — Login screen + JWT flow
│   ├── dashboard/                   — Live T/H/P sensor cards + charts
│   ├── ai_scans/                    — AI detection results + images
│   └── system_config/               — Set temperature, humidity, pressure
│
└── shared/
    ├── widgets/                     — Reusable: sensor_card, loading_overlay
    └── models/                      — api_response.dart (generic wrapper)
```

Each feature folder has:
```
feature_name/
├── data/         — Repository (HTTP calls, JSON parsing)
├── domain/       — Pure Dart model classes
└── presentation/ — Screen + Controller (ValueNotifier state)
```

---

## Navigation (GoRouter)

| Route | Screen | Auth |
|---|---|---|
| `/login` | LoginScreen | Public |
| `/` | HomeScreen (Dashboard) | Required |
| `/detail/:sensor` | DetailScreen | Required |
| `/scans` | AI Scans Screen | Required |
| `/config` | System Config Screen | Required |

---

## Authentication

- **Flow:** OAuth2 Password Bearer (POST `/api/v1/login` → JWT)
- **Token Storage:** `SharedPreferences` via `auth_token_store.dart`
- **Token Expiry:** 7 days
- **Header:** `Authorization: Bearer <token>`
- **On 401:** Clear token → redirect to `/login`

---

## Backend API Contract

| Method | Route | Auth Header | Notes |
|---|---|---|---|
| POST | `/api/v1/login` | None | Returns `access_token` |
| GET | `/api/v1/sensor-readings` | Bearer JWT | Latest readings |
| GET | `/api/v1/ai-scans` | Bearer JWT | Detection history |
| GET | `/api/v1/system-config` | X-API-KEY | Current setpoints |
| POST | `/api/v1/system-config` | X-API-KEY | Update setpoints |

**Base URL:** Configurable in `core/constants.dart`. Default for local dev: `http://192.168.X.X:8000`

---

## Environment & Configuration (For Developers)

When moving between active development, testing, and production, check the parameters in `lib/src/core/constants.dart`:

1. **`kDevMode` Toggle:**
   - **`true`**: UI error messages will display raw exceptions and stack traces (e.g., `[DEV ERROR] SocketException: ...`). Essential for debugging API routing limits or hardware crashes.
   - **`false`**: UI displays clean, user-friendly fallback phrases. Toggle this to `false` before compiling the final production APK.

2. **`kCloudBaseUrl` Targeting:**
   - **Local Testing (Phone):** Set to your laptop's Wi-Fi IP address + port 8001 (e.g., `http://192.168.100.20:8001`) to hit your locally running `cloud-server`.
   - **Production:** Set to the public Render domain (e.g., `https://lettuvault.onrender.com`).
   - *Note: Android Emulators use `http://10.0.2.2:8001` to loopback to the host machine.*

---

## State Management

Use **`ValueNotifier` + `ListenableBuilder`** (no external packages):
- One `*Controller` per screen
- Controllers expose `ValueNotifier` properties for loading, data, and errors
- Screens are dumb — they only read from controllers and call methods
- No HTTP calls inside widgets or screens directly

---

## Key Dependencies (pubspec.yaml)

| Package | Purpose |
|---|---|
| `fl_chart` | Sensor history charts |
| `syncfusion_flutter_gauges` | VPD and sensor gauges |
| `http` | API networking |
| `flutter_local_notifications` | Push alerts for thresholds |
| `shared_preferences` | Persist JWT, theme, thresholds |
| `intl` | Date/time formatting |
| `path_provider` | CSV log file storage |

---

## Running

```bash
# From project root
cd mobile/LettuVault_Unfinished

# Get dependencies
flutter pub get

# Run on connected device or emulator
flutter run

# Build APK
flutter build apk --release
```

---

## Development Notes

- Simulation mode currently ON by default (`_simulateSensors = true` in `main.dart`) — disable this when wiring the real API
- The `SensorNetworkAdapter` polls `http://10.0.2.2:5000/sensor` (Android emulator loopback) — this must be replaced with the real backend URL and proper auth
- Alert notification threshold hysteresis is ±1.0 unit — do not remove (prevents spam)

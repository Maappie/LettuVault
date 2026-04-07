# Mobile App Architecture — LettuVault
# Framework: Flutter (Dart)
# Owner: Meyvn

---

## ⚠️ Agent Rule: Hands Off Policy

> The AI agent **MUST NOT modify any file** inside `mobile/` unless the user (Renz) **explicitly requests it** and confirms it is safe. If a backend change could break the mobile API contract (routes, auth scheme, response shape), **warn the user explicitly** before proceeding.

---

## Clean Architecture Overview

The mobile app follows a **Feature-First Clean Architecture** with three strict layers:

```
Presentation  →  Domain  →  Data
(UI/Widgets)     (Logic)     (API/Storage)
```

Each feature folder contains all three layers for that feature. Nothing bleeds across features except shared domain models.

---

## Target Folder Structure

```
lib/
├── main.dart                        — App entry point, theme, routing, notification init
├── app/
│   ├── router.dart                  — GoRouter route definitions
│   └── theme.dart                   — Light/Dark ThemeData
│
├── core/
│   ├── constants.dart               — API base URL, topic names, timeouts
│   ├── api_client.dart              — http wrapper (adds X-API-KEY / Bearer header)
│   ├── auth_token_store.dart        — SharedPreferences: save/load JWT token
│   └── exceptions.dart              — ApiException, AuthException, NetworkException
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   └── auth_repository.dart     — POST /api/v1/login → returns JWT
│   │   ├── domain/
│   │   │   └── user_token.dart          — Model: accessToken, expiresAt
│   │   └── presentation/
│   │       ├── login_screen.dart
│   │       └── login_controller.dart
│   │
│   ├── dashboard/
│   │   ├── data/
│   │   │   └── sensor_repository.dart   — GET /api/v1/sensor-readings
│   │   ├── domain/
│   │   │   └── sensor_reading.dart      — Model: id, timestamp, temperature, humidity, pressure, device_id
│   │   └── presentation/
│   │       ├── home_screen.dart         — Live T/H/P cards, VPD gauge, trend arrows
│   │       ├── detail_screen.dart       — fl_chart history per sensor
│   │       └── dashboard_controller.dart
│   │
│   ├── ai_scans/
│   │   ├── data/
│   │   │   └── scan_repository.dart     — GET /api/v1/ai-scans
│   │   ├── domain/
│   │   │   └── ai_scan.dart             — Model: id, timestamp, worm_count, confidence_score, label, image, produce_type
│   │   └── presentation/
│   │       ├── scans_screen.dart        — List of detections with images
│   │       └── scans_controller.dart
│   │
│   └── system_config/
│       ├── data/
│       │   └── config_repository.dart   — GET/POST /api/v1/system-config
│       ├── domain/
│       │   └── system_config.dart       — Model: set_temperature, set_humidity, set_pressure
│       └── presentation/
│           ├── config_screen.dart       — Sliders for setpoints, Save button
│           └── config_controller.dart
│
└── shared/
    ├── widgets/
    │   ├── sensor_card.dart             — Reusable T/H/P card widget
    │   ├── loading_overlay.dart         — Full-screen loading spinner
    │   └── error_snackbar.dart          — Standard error snackbar helper
    └── models/
        └── api_response.dart            — Generic wrapper: data, error, isLoading
```

---

## Layer Responsibilities

### 1. Data Layer (Repositories)
- Makes HTTP calls via `core/api_client.dart`
- Parses JSON into domain models
- Handles `ApiException` and rethrows clean domain errors
- **Never imports Flutter widgets**

### 2. Domain Layer (Models)
- Pure Dart classes (`fromJson` / `toJson`)
- No Flutter dependencies
- Shared across features only via `shared/models/`

### 3. Presentation Layer (Screens + Controllers)
- Controllers hold state (`ValueNotifier` or `ChangeNotifier`)
- Screens are dumb — they only read from controllers and call methods
- No direct HTTP calls in screens — always through controllers → repositories

---

## API Integration Rules

### Base URL
```dart
// core/constants.dart
const String kBaseUrl = 'http://192.168.X.X:8000'; // Set to server IP
const String kApiPrefix = '/api/v1';
```

### Authentication
- **Hardware routes** use `X-API-KEY` header
- **User routes** use `Authorization: Bearer <JWT>` header
- Token stored in `SharedPreferences` via `auth_token_store.dart`
- On 401 response → clear token and redirect to `/login`

### API Client Pattern
```dart
// core/api_client.dart
class ApiClient {
  Future<Map<String, dynamic>> get(String endpoint) async { ... }
  Future<Map<String, dynamic>> post(String endpoint, Map body) async { ... }
  // Automatically injects the correct auth header based on current token state
}
```

---

## Navigation

Use **GoRouter** for declarative routing:

| Route | Screen | Auth Required |
|---|---|---|
| `/login` | LoginScreen | No |
| `/` | HomeScreen (Dashboard) | Yes |
| `/detail/:sensor` | DetailScreen | Yes |
| `/scans` | AIScansScreen | Yes |
| `/config` | SystemConfigScreen | Yes |

---

## Notification Rules

- Threshold alerts fired from `dashboard_controller.dart` only
- Use `flutter_local_notifications` — already in `pubspec.yaml`
- Hysteresis buffer of ±1.0 unit to prevent notification spam (already implemented in current code — keep this pattern)
- Alert channels: `critical_alerts` for sensor warnings

---

## State Management

Use **`ValueNotifier` + `ListenableBuilder`** (no external state management packages):
- Lightweight and already native to Flutter
- One `*Controller` per screen that exposes `ValueNotifier` properties
- Controllers are created above the widget tree and passed down

---

## What Needs To Be Built

| Feature | Status | Notes |
|---|---|---|
| Auth (Login / JWT) | ❌ Not built | Priority 1 — blocks everything else |
| Dashboard (Sensor readings) | 🟡 Partial | Simulation exists, needs real API wiring |
| AI Scans screen | ❌ Not built | Priority 2 |
| System Config screen | ❌ Not built | Priority 3 — set T/H/P from app |
| Network Adapter → real API | 🟡 Partial | Currently hardcoded to emulator URL |
| App ID rename | ❌ Not done | `my_new_app` → `com.lettuvault.app` |
| GoRouter navigation | ❌ Not built | Currently using index-based nav container |

---

## Backend API Contract (DO NOT CHANGE without mobile awareness)

| Method | Route | Response Key Fields |
|---|---|---|
| POST | `/api/v1/login` | `access_token`, `token_type` |
| GET | `/api/v1/sensor-readings` | `id`, `temperature`, `humidity`, `pressure`, `device_id`, `timestamp` |
| GET | `/api/v1/ai-scans` | `id`, `worm_count`, `confidence_score`, `label`, `image`, `produce_type`, `timestamp` |
| GET | `/api/v1/system-config` | `set_temperature`, `set_humidity`, `set_pressure` |
| POST | `/api/v1/system-config` | same fields |

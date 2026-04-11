
# Mobile App Architecture — LettuVault
# Framework: Flutter (Dart)
# Owner: Meyvn

---

## ⚠️ Agent Rule: Hands Off Policy

> The AI agent **MUST NOT modify any file** inside `mobile/` unless the user (Renz) **explicitly requests it** and confirms it is safe. If a backend change could break the mobile API contract (routes, auth scheme, response shape), **warn the user explicitly** before proceeding.

---

## Clean Architecture Overview

The mobile app follows a **Feature-First Clean Architecture** with strict layer separation:

```
Presentation  →  Controller  →  Domain  →  Data
(Screen + Widgets)  (Logic)    (Models)  (Repos/Services)
```

Each feature folder contains all three layers for that feature (screens, widgets, controller, model). Nothing bleeds across features except shared domain models and shared widgets.

---

## Directory Structure

```
lib/
├── main.dart                              — ~30 lines: init + runApp only
├── app/
│   ├── app.dart                           — MaterialApp, routing, theme wiring
│   ├── theme.dart                         — ThemeData definitions (light + dark)
│   └── app_notifiers.dart                 — Global ValueNotifiers (themeNotifier)
│
├── core/
│   ├── constants.dart                     — Non-secret app-wide constants
│   ├── app_mode.dart                      — AppMode enum + appModeNotifier
│   ├── api_client.dart                    — HTTP wrapper (auth headers)
│   ├── secure_storage.dart                — flutter_secure_storage wrapper
│   └── exceptions.dart                    — ApiException, NetworkException
│
├── features/
│   ├── dashboard/
│   │   ├── screens/
│   │   │   └── dashboard_screen.dart      — Full dashboard screen (StatelessWidget)
│   │   └── widgets/
│   │       ├── sensor_summary_card.dart   — T/H/P animated summary card
│   │       ├── api_status_banner.dart     — Live/offline/error status banner
│   │       └── camera_preview_card.dart   — Live camera placeholder card
│   │
│   ├── detail/
│   │   ├── screens/
│   │   │   └── sensor_detail_screen.dart  — Full sensor detail screen (StatefulWidget)
│   │   └── widgets/
│   │       ├── chart_card.dart            — Labeled chart with mode switcher
│   │       └── metric_row.dart            — Target / Avg / Trend row
│   │
│   ├── settings/
│   │   ├── controllers/
│   │   │   └── settings_controller.dart   — ChangeNotifier: thresholds, sys config, alerts
│   │   ├── screens/
│   │   │   └── settings_drawer.dart       — The app Drawer (consumes SettingsController)
│   │   └── widgets/
│   │       ├── connection_mode_tile.dart  — Online/Offline mode toggle card
│   │       ├── threshold_sliders.dart     — Alert threshold sliders + save button
│   │       └── sys_config_panel.dart      — System config sliders + preset chips
│   │
│   ├── setup/
│   │   └── screens/
│   │       └── setup_offline_screen.dart  — First-run offline credentials wizard
│   │
│   └── logs/
│       └── screens/
│           └── log_status_screen.dart     — CSV logging status + share button
│
├── navigation/
│   └── main_navigator.dart                — Bottom nav container, screen routing, splash/setup overlay
│
├── services/
│   ├── notification_service.dart          — Init, permission request, zone-based notify/cancel
│   ├── connectivity_service.dart          — switchToOffline / switchToOnline (wifi_iot + prefs)
│   ├── sensor_polling_service.dart        — Timer-based polling: env repo + config repo calls
│   ├── csv_logger_service.dart            — getStorageDir, logToCSV, clearLogs helpers
│   └── background_service.dart           — flutter_background_service init + isolate handler
│
└── shared/
    ├── models/
    │   ├── sensor_reading.dart            — SensorReading(double value, DateTime time)
    │   ├── internal_environment_reading.dart
    │   └── system_config.dart
    ├── repositories/
    │   ├── environment_repository.dart    — GET /api/v1/internal-environment
    │   └── config_repository.dart         — GET/POST /api/v1/system-config
    └── widgets/
        ├── app_top_bar.dart               — buildTopBar(context, title)
        ├── radial_gauge.dart              — buildRadial(...) — Syncfusion gauge widget
        ├── sensor_chart.dart              — buildChart(...) — fl_chart line chart widget
        ├── status_pill.dart               — buildPill(context, message, color)
        ├── metric_card.dart               — buildMetricBig and buildMetric widgets
        └── about_dialog.dart              — showAppAboutDialog(context)
```

---

## Layer Responsibilities

### `main.dart` (~30 lines)
- `WidgetsFlutterBinding.ensureInitialized()`
- Seed secure storage defaults
- Init background service
- Call `runApp(const LettuVaultApp())`

### `app/app.dart`
- `LettuVaultApp` is a `StatelessWidget`
- Wraps `MaterialApp` in `ValueListenableBuilder<ThemeMode>`
- Home: `MainNavigator(key: MainNavigator.navKey)`

### `app/theme.dart`
- `AppTheme.light()` → `ThemeData`
- `AppTheme.dark()` → `ThemeData`
- All color/font/shape token definitions live here — **never inline**

### `app/app_notifiers.dart`
- `final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);`

### Feature Screens (Presentation Layer)
- Screens are **dumb** — they only call methods on services/controllers and build widgets
- Screens MUST NOT contain business logic, polling loops, or persistence calls
- Screens MUST NOT be longer than ~150 lines

### Feature Widgets
- Every distinct UI component inside a screen is its **own Widget class** in a `widgets/` subfolder
- Widgets accept only the data they need via constructor parameters
- Widgets MUST NOT call repositories or services directly

### Controllers (`ChangeNotifier`)
- Hold mutable UI state that is shared across multiple widgets in a feature
- Example: `SettingsController` holds threshold values, draft values, sys config state
- Exposed via `ChangeNotifierProvider` or passed down as constructor arg

### Services
- Pure Dart classes (no widgets, no context)
- Handle side effects: network, storage, notifications, connectivity
- Consumed by controllers and the navigator

---

## Navigation

Index-based `BottomNavigationBar` managed by `MainNavigator`:

| Index | Screen | Note |
|---|---|---|
| 0 | DashboardScreen | Main landing |
| 1 | SensorDetailScreen (Temp) | Passes temp data |
| 2 | SensorDetailScreen (Humidity) | Passes humidity data |
| 3 | SensorDetailScreen (Pressure) | Passes pressure data |

Overlays managed by `MainNavigator`:
- `SplashScreen` (startup loading)
- `SetupOfflineScreen` (first-run wizard)
- Mode-switching loading overlay

---

## State Management

Use **`ValueNotifier` + `ListenableBuilder`** for simple reactive state.
Use **`ChangeNotifier`** for feature-level controllers (e.g., `SettingsController`).
No external state management packages (no Provider, no Riverpod).

Rules:
- `ValueNotifier<T>` for single, simple values (themeMode, appMode)
- `ChangeNotifier` for controllers with multiple related fields (thresholds, sys config)
- `StatefulWidget` only when local ephemeral UI state is needed (animation controllers, form drafts)

---

## Theming Rule

> **ALL colors, border radii, font sizes, and spacing values MUST come from `AppTheme` or `Theme.of(context)`.**
> Hardcoded values like `Color(0xFF...)`, `Colors.blue`, `BorderRadius.circular(12)`, etc. are NOT allowed in screen or widget files.
> Define a constant or token in `app/theme.dart` instead.

---

## Widget Decomposition Rule

> A screen file is for **composition only** — it assembles named Widget classes.
> Any UI block that is more than ~30 lines OR can be meaningfully named goes into its own file in the feature's `widgets/` folder.

Examples:
- ✅ `SensorSummaryCard` (sensor_summary_card.dart)
- ✅ `ApiStatusBanner` (api_status_banner.dart)
- ❌ `_buildLargeCard()` inline in screen (too long, should be extracted)

---

## File Length Rules

| File Type | Max Lines |
|---|---|
| `main.dart` | 40 |
| `app/app.dart` | 60 |
| Any screen file | 150 |
| Any widget file | 200 |
| Any controller | 250 |
| Any service | 200 |
| Shared widget helpers | 150 per file |

---

## API Integration Rules

### Base URL
```dart
// core/constants.dart
const String kLocalBaseUrl = 'http://10.42.0.1:8000';
const String kCloudBaseUrl = 'https://lettuvault.onrender.com';
const String kApiPrefix = '/api/v1';
```

### Authentication
- Hardware routes: `X-API-KEY` header
- User routes: `Authorization: Bearer <JWT>` header
- Token stored in `SecureStorage`

---

## Backend API Contract (DO NOT CHANGE without mobile awareness)

| Method | Route | Response Key Fields |
|---|---|---|
| POST | `/api/v1/login` | `access_token`, `token_type` |
| GET | `/api/v1/sensor-readings` | `id`, `temperature`, `humidity`, `pressure`, `device_id`, `timestamp` |
| GET | `/api/v1/ai-scans` | `id`, `worm_count`, `confidence_score`, `label`, `image`, `produce_type`, `timestamp` |
| GET | `/api/v1/system-config` | `set_temperature`, `set_humidity`, `set_pressure` |
| POST | `/api/v1/system-config` | same fields |
| GET | `/api/v1/internal-environment` | `id`, `temperature`, `humidity`, `pressure`, `device_id`, `timestamp` |

---

## What Needs To Be Built

| Feature | Status | Notes |
|---|---|---|
| Auth (Login / JWT) | ❌ Not built | Priority 1 |
| Dashboard (Sensor readings) | 🟢 Refactored | Feature-first structure |
| Sensor Detail screens | 🟢 Refactored | Feature-first structure |
| Settings / Drawer | 🟢 Refactored | SettingsController + decomposed widgets |
| AI Scans screen | ❌ Not built | Priority 2 |
| System Config backend wire | ❌ Not built | Priority 3 |
| App ID rename | ❌ Not done | `my_new_app` → `com.lettuvault.app` |


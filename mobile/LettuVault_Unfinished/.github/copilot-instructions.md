# LettuVault Development Instructions

## Project Overview
LettuVault is an **unfinished Flutter sensor monitoring app** for greenhouse/agriculture environments. It simulates real-time sensor data (temperature, humidity, pressure), displays live charts, triggers critical alerts, and logs readings to CSV.

## Architecture Patterns

### Monolithic Single-File Pattern
All code exists in [lib/main.dart](../lib/main.dart) (~512 lines). **Do NOT refactor into separate files unless explicitly requested** — this is intentional for this phase. When adding features, append to existing widget classes or add new utility methods near the bottom with other `_build*()` helpers.

### Master State Controller (MainNavigationContainerState)
- **Central hub** for sensor data buffers: `tempBuffer`, `humidityBuffer`, `pressureBuffer` (max 5 readings each)
- Manages 5 screens via bottom navigation + drawer menu
- Runs `_processSensorData()` every 10 seconds via Timer (not actual sensor hardware yet)
- Controlled alerts toggle via `_alertsEnabled` flag in drawer

### Data Model & Buffering
```dart
class SensorReading { final double value; final DateTime time; }
```
Rolling-window buffer logic in `_updateBuffer()`: **Add new reading → Remove oldest if buffer.length > 5 → Calculate rolling average.** Use this pattern when implementing new sensors.

### Sensor Data Simulation
Currently uses `Random().nextDouble() * (±0.5)` for realistic drift. Replace with actual sensor integration (HTTP API calls, Bluetooth, etc.) by modifying `_processSensorData()` and the data simulation logic.

## UI Components & Data Flow

| Screen | Widget | Data Source | Purpose |
|--------|--------|-------------|---------|
| Home (incomplete) | `HomeScreen` | All 3 sensor values + averages | Overview dashboard (NOT YET IMPLEMENTED) |
| Temperature | `DetailScreen` | `currentTemp`, `tempBuffer` | Detailed temp with radial gauge & 5-sample timeline |
| Humidity | `DetailScreen` | `currentHum`, `humidityBuffer` | Same UI, low-threshold critical alert (`isLowCrit: true`) |
| Pressure | `DetailScreen` | `currentPres`, `pressureBuffer` | Same UI, high-threshold alert |
| Logs | `LogStatusScreen` | None | Displays CSV logging status |

**Key UI Helpers** (bottom of main.dart):
- `_buildRadial()` — Syncfusion gauge showing current value vs threshold
- `_buildChart()` — fl_chart LineChart with 5-point timeline (last 5 samples)
- `_buildTopBar()`, `_buildPill()`, `_buildMetric()` — Standardized dark-theme components

## Critical Workflows

### Adding a New Sensor Type
1. Create new buffer in `MainNavigationContainerState`: `List<SensorReading> newSensorBuffer = [];`
2. Add current value variable: `double currentNewSensor = 0.0;`, `avgNewSensor = 0.0;`
3. Update `_processSensorData()` to simulate/fetch data and update buffer via `_updateBuffer()`
4. Create new `DetailScreen` tab in `screens[]` list with correct threshold & unit
5. Add BottomNavigationBarItem in bottom bar
6. Increment bottom bar `type: BottomNavigationBarType.fixed` if needed for 6+ tabs

### CSV Logging Flow
- **Triggered**: Every 10 seconds in `_processSensorData()` → calls `_logToCSV()`
- **Storage**: External storage path from `getExternalStorageDirectory()` → `sensor_log.csv`
- **Format**: `timestamp, sensorName, value` (appended, not overwritten)
- **Clearing**: `_clearLogs()` deletes file, triggered from drawer settings

### Critical Alert Thresholds
Logic in `_processSensorData()`:
- **Temperature**: `currentTemp > 40°C` fires notification (high threshold)
- **Humidity**: `currentHum < 50%` fires alert (low threshold, set by `isLowCrit: true`)
- Uses hysteresis pattern: `_tempAlertSent` flag prevents spam (resets when `temp <= 38`)
- Notifications only sent if `_alertsEnabled` toggle is ON (drawer)

## Custom Styling & Assets

**Dark Theme Colors**:
- Primary: `#1E1E1E` (dark backgrounds)
- Scaffold: `#121212` (main background)
- Accent: `Colors.blueAccent` (interactive elements)
- Alerts: `Colors.red` (critical), `Colors.green` (stable)

**Custom Fonts** (in pubspec.yaml):
- `Google` (default) — GoogleSansCode variable weight
- `Montserrat` — Fallback sans-serif
- `Corinthia`, `IndieFlowers` — Stylistic elements (if needed)

**Required Asset**:
- `assets/profile.jpg` — Avatar image in top-right of each detail screen (NOT present, add placeholder handling if missing)

## Key Dependencies & Integration Points

| Package | Usage | Status |
|---------|-------|--------|
| `fl_chart` (^1.1.1) | 5-sample timeline charts | ✅ Active |
| `syncfusion_flutter_gauges` (^32.2.3) | Radial gauges | ✅ Active |
| `path_provider` | CSV file storage location | ✅ Active |
| `intl` | Date/time formatting in charts | ✅ Active |
| `flutter_local_notifications` | Critical alert popups | ✅ Active (Android only currently) |
| `http` (^1.1.0) | **Imported but unused** — will be needed for real sensor API | ⏳ Future |

## Incomplete Features & TODOs

### HomeScreen Widget (CRITICAL)
**Referenced in line 140 but NOT IMPLEMENTED.** Need to create `class HomeScreen extends StatelessWidget` with:
- Constructor params: `t` (temp), `h` (humidity), `p` (pressure), `at` (avg temp), `ah` (avg humidity), `ap` (avg pressure)
- Display all 3 sensor values with color-coded status badges
- Example: Use `_buildSectionHeader()` + `_buildLargeCard()` pattern for clean layout
- Place widget definition **before** the "REUSABLE UI HELPERS" section comment

### Real Sensor Integration
- Replace Random data in `_processSensorData()` with actual sensor reads (HTTP API, BLE, etc.)
- If using HTTP, implement in separate async method called from timer loop
- Add error handling for failed sensor connections

### iOS Notification Support
- Currently only Android notifications configured
- Add iOS initialization in `_initializeNotifications()` with DarwinInitializationSettings

## Testing & Debugging Tips

**Run app**:
```bash
flutter run
```

**View CSV logs** (during/after run):
- Android: Check `getExternalStorageDirectory()` path (usually `/sdcard/Android/data/`)
- File: `sensor_log.csv` with format `timestamp, sensor_name, value`

**Simulate threshold alerts**:
- Modify constants in `_processSensorData()`: Change `40` to `25` for immediate temp alert
- Toggle alerts ON/OFF in app drawer to verify hysteresis logic

**Hot reload during development**:
- Safe: UI changes, threshold values, colors
- **UNSAFE**: Timer interval, buffer logic, data model — use hot restart instead

## Code Style & Conventions
- **Widget naming**: `_buildX()` for private helper widgets; PascalCase for classes
- **State updates**: Always use `setState(() { ... })` for reactive UI changes
- **Comments**: Use `// ---` section headers to organize logical blocks (see main.dart pattern)
- **Error handling**: Wrap file I/O in try-catch with `debugPrint()` for error messages
- **Spacing**: 2-space indentation, follow Flutter lints in `analysis_options.yaml`

## References & Next Steps
1. **First task**: Implement missing `HomeScreen` widget (copy pattern from `DetailScreen`)
2. **Second task**: Add iOS notification support + test on device
3. **Third task**: Integrate real API endpoint for sensor data (replace Random simulation)
4. **Profile image**: Provide or create `assets/profile.jpg` placeholder

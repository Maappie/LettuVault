// LettuVault — Core Constants
//
// Non-secret configuration values.
// All secrets (API keys, passwords) live in SecureStorage — NOT here.

// ── Offline Mode (Local Raspberry Pi AP) ──────────────────────────────────────
// The backend server address when connected to the Pi's Access Point.
// 10.42.0.1 is the default gateway IP assigned by Linux NetworkManager Hotspots.
const String kLocalBaseUrl = 'http://10.42.0.1:8000';

// ── Online Mode (Cloud Server) ─────────────────────────────
// Pointing to your deployed cloud URL.
const String kCloudBaseUrl = 'https://lettuvault.onrender.com';

// ── API Prefix ─────────────────────────────────────────────────────────────────
// Must match settings.API_V1_STR on both backends.
const String kApiPrefix = '/api/v1';

// ── Pi Access Point ───────────────────────────────────────────────────────────
// The default SSID pre-filled in the offline setup screen.
const String kDefaultPiSsid = 'LettuVault-01';

// ── Polling Intervals ────────────────────────────────────────────────────────
// How often the dashboard polls for new readings (seconds).
const int kDashboardPollIntervalSeconds = 10;

// ── Dynamic UI Tolerances ────────────────────────────────────────────────────
// How far a sensor reading can drift from the target before the card turns red.

// Temperature
const double kTempTolerance    = 1.5;
const double kTempMaxDeviation = 5.0;

// Humidity
const double kHumTolerance    = 3.0;
const double kHumMaxDeviation = 10.0;

// Pressure
const double kPresTolerance    = 20.0;
const double kPresMaxDeviation = 100.0;

// ── Developer Mode ──────────────────────────────────────────────────────────
// Set this to true to see raw network exceptions in the UI instead of user-friendly errors.
const bool kDevMode = true;

// ── Onboarding: Home Wi-Fi Step ───────────────────────────────────────
// true  → Home Wi-Fi step is mandatory. Skip button is hidden.
//         Use for production releases where cloud sync is required.
// false → Home Wi-Fi step shows a 'Skip for now' button.
//         Use during laptop/development when Pi is not yet on a real home router.
const bool kHomeWifiStepEnabled = false;

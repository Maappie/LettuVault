/// LettuVault — Core Constants
///
/// Non-secret configuration values.
/// All secrets (API keys, passwords) live in SecureStorage — NOT here.

// ── Offline Mode (Local Raspberry Pi AP) ──────────────────────────────────────
// The backend server address when connected to the Pi's Access Point.
// Update this if the Pi's AP assigns a different IP to itself.
const String kLocalBaseUrl = 'http://192.168.68.144:8000';

// ── Online Mode (Render Cloud Server) ─────────────────────────────────────────
// The public Render deployment URL. No IP needed — always the same domain.
const String kCloudBaseUrl = 'https://lettuvault.onrender.com';

// ── API Prefix ─────────────────────────────────────────────────────────────────
// Must match settings.API_V1_STR on both backends.
const String kApiPrefix = '/api/v1';

// ── Pi Access Point ───────────────────────────────────────────────────────────
// The default SSID pre-filled in the offline setup screen.
const String kDefaultPiSsid = 'LettuVault-01';

// ── Polling Intervals ────────────────────────────────────────────────────────
// How often the dashboard polls for new readings (seconds).
const int kDashboardPollIntervalSeconds = 5;

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

/// LettuVault — Core Constants
///
/// Central place for API base URL, prefix, and auth headers.
/// Change [kBaseUrl] to your backend server's LAN IP for real device testing.

// The backend server address.
// For Android emulator: 'http://10.0.2.2:8000'
// For real device on same WiFi: 'http://192.168.X.X:8000'
const String kBaseUrl = 'http://192.168.68.144:8000';

// API version prefix — must match settings.API_V1_STR on the backend
const String kApiPrefix = '/api/v1';

// Hardware API Key — must match X_API_KEY in the backend .env
const String kApiKey = 'lettuce-master-key-2024';

// Polling interval for sensor dashboard (seconds)
const int kDashboardPollIntervalSeconds = 5;

// --- DYNAMIC UI TOLERANCES ---
// How far a sensor reading can drift from the target before the card starts turning red.
// The intensity of the red color maxes out when it hits the "Max Deviation".

// Temperature
const double kTempTolerance = 1.5; // No color change if within ± 1.5
const double kTempMaxDeviation = 5.0; // Reddest color if off by ± 5.0 or more

// Humidity
const double kHumTolerance = 3.0; // No color change if within ± 3.0
const double kHumMaxDeviation = 10.0; // Reddest color if off by ± 10.0 or more

// Pressure (using absolute difference for precision)
const double kPresTolerance = 20.0; // No color change if within ± 2.0 hPa (approx 0.2%)
const double kPresMaxDeviation = 100.0; // Reddest color if off by ± 10.0 hPa (approx 1.0%)

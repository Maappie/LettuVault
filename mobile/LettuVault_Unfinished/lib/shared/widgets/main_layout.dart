// DEPRECATED — superseded by the feature-first architecture.
//
// This file used a `part` directive approach which is no longer the pattern.
// The MainNavigationContainer has been split into:
//   - lib/navigation/main_navigator.dart  (navigation + orchestration)
//   - lib/services/sensor_polling_service.dart (data + polling)
//   - lib/services/connectivity_service.dart (wifi switching)
//   - lib/features/settings/ (settings drawer + controller)
//
// This file is kept for reference only and will be removed in the next cleanup pass.

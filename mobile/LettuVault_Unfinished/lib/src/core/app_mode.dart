import 'package:flutter/foundation.dart';

/// app_mode.dart — Global app connectivity mode
///
/// Online = fetch from Render cloud server
/// Offline = fetch from local Raspberry Pi AP backend
///
/// Use [appModeNotifier] anywhere in the app to read or switch the current mode.

enum AppMode { online, offline }

/// Global ValueNotifier — listen to this to react to mode changes.
final ValueNotifier<AppMode> appModeNotifier = ValueNotifier(AppMode.online);

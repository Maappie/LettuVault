import 'package:flutter/material.dart';

/// Global ValueNotifier for the app-wide theme mode.
/// Listened to by [LettuVaultApp] to rebuild MaterialApp on change.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

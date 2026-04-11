import 'package:flutter/material.dart';

/// AppTheme — Single source of truth for all visual tokens.
///
/// Rules:
/// - All colors, font sizes, border radii, and shadows must be defined here.
/// - Screen and widget files MUST use Theme.of(context) or AppTheme constants.
/// - Never hardcode Color(0xFF...) or Colors.blue in screen/widget files.
abstract class AppTheme {
  // ── Brand colours ────────────────────────────────────────────────────────
  static const Color brandGreen   = Color(0xFF4ADE80);
  static const Color brandBlue    = Color(0xFF3B82F6);
  static const Color brandOrange  = Color(0xFFF97316);
  static const Color brandRed     = Color(0xFFEF4444);
  static const Color brandAmber   = Color(0xFFF59E0B);

  // ── Zone colours (sensor status) ────────────────────────────────────────
  static const Color zoneGreen    = Color(0xFF22C55E);
  static const Color zoneOrange   = Color(0xFFF97316);
  static const Color zoneRed      = Color(0xFFEF4444);

  // ── Border radius tokens ─────────────────────────────────────────────────
  static const double radiusCard  = 20.0;
  static const double radiusPill  = 50.0;
  static const double radiusChip  = 10.0;

  // ── Spacing tokens ───────────────────────────────────────────────────────
  static const double spaceSm     = 8.0;
  static const double spaceMd     = 16.0;
  static const double spaceLg     = 24.0;

  // ─────────────────────────────────────────────────────────────────────────

  static ThemeData light() {
    const seed = Color(0xFF3B82F6);
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
      primaryColor: Colors.blue.shade700,
      scaffoldBackgroundColor: const Color(0xFFF6F8FA),
      cardColor: Colors.white,
      fontFamily: 'Google',
      useMaterial3: true,
    );
  }

  static ThemeData dark() {
    const seed = Color(0xFF3B82F6);
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
      primaryColor: const Color(0xFF1E1E1E),
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardColor: const Color(0xFF1E1E1E),
      fontFamily: 'Google',
      useMaterial3: true,
    );
  }
}

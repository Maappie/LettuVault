import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Singleton plugin instance — used by NotificationService and anywhere
/// that needs to cancel/show notifications directly.
final FlutterLocalNotificationsPlugin localNotif =
    FlutterLocalNotificationsPlugin();

/// NotificationService — handles all push-notification concerns.
///
/// Responsibilities:
///   - initialize() — plugin setup + Android 13 permission
///   - checkZone() — compute zone (green/orange/red), fire / cancel notification
///
/// It is stateless apart from [_lastZone] which tracks the previous zone
/// per sensor key so we only notify on transitions.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// Zone tracking: 0=green, 1=orange, 2=red.
  /// Only fires a notification when the zone changes.
  final Map<String, int> _lastZone = {'temp': 0, 'hum': 0, 'pres': 0};

  // ── Initialization ───────────────────────────────────────────────────────

  Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await localNotif.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: darwinInit),
    );

    // Android 13+ runtime permission
    final androidImpl = localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();

    // Battery optimisation exclusion (keeps background service alive)
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    debugPrint('[NotifService] Initialized.');
  }

  // ── Zone-based alerting ──────────────────────────────────────────────────

  /// Computes the zone for [value] and fires/cancels a notification
  /// only when the zone transitions. Safe to call on every poll tick.
  void checkZone({
    required String key,
    required String sensorName,
    required String readingStr,
    required int notifId,
    required double value,
    required double target,
    required double tolerance,
    required double maxDev,
    required bool useDefaultThresholds,
    required double customLow,
    required double customHigh,
  }) {
    final int zone = _computeZone(
      value: value,
      target: target,
      tolerance: tolerance,
      maxDev: maxDev,
      useDefaultThresholds: useDefaultThresholds,
      customLow: customLow,
      customHigh: customHigh,
    );

    final int prev = _lastZone[key] ?? 0;
    if (zone == prev) return; // no change — skip
    _lastZone[key] = zone;

    if (zone == 0) {
      localNotif.cancel(id: notifId);
      return;
    }

    final bool isRed = zone == 2;
    localNotif.show(
      id: notifId,
      title: isRed
          ? 'LettuVault Alert 🔴 — Red Zone'
          : 'LettuVault Warning 🟠 — Orange Zone',
      body: isRed
          ? '$sensorName ($readingStr) has entered the Red Zone. Please check the LettuVault immediately!'
          : '$sensorName ($readingStr) is in the Orange Zone. LettuVault is outside the safe range.',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          isRed ? 'lettuvault_red_alerts' : 'lettuvault_orange_alerts',
          isRed ? 'LettuVault Critical Alerts' : 'LettuVault Warnings',
          importance: isRed ? Importance.max : Importance.high,
          priority: isRed ? Priority.max : Priority.high,
          ongoing: isRed,
          autoCancel: !isRed,
          playSound: true,
          enableVibration: true,
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  int _computeZone({
    required double value,
    required double target,
    required double tolerance,
    required double maxDev,
    required bool useDefaultThresholds,
    required double customLow,
    required double customHigh,
  }) {
    if (useDefaultThresholds) {
      final diff = (value - target).abs();
      if (diff <= tolerance) return 0;
      if (diff <= maxDev) return 1;
      return 2;
    } else {
      if (value < customLow || value > customHigh) return 2;
      if ((value - target).abs() <= tolerance) return 0;
      return 1;
    }
  }
}

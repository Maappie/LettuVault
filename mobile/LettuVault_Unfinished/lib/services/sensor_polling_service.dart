import 'dart:async';

import 'package:flutter/material.dart';

import 'package:my_new_app/src/core/constants.dart';
import 'package:my_new_app/src/models/sensor_reading.dart';
import 'package:my_new_app/src/repositories/environment_repository.dart';
import 'package:my_new_app/src/repositories/config_repository.dart';
import 'package:my_new_app/services/notification_service.dart';
import 'package:my_new_app/services/csv_logger_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sensor state snapshot — published to listeners after each poll.
class SensorState {
  final double temp, hum, pres;
  final double avgT, avgH, avgP;
  final double targetTemp, targetHum, targetPres;
  final double tempThresholdLow, tempThresholdHigh;
  final double humThresholdLow, humThresholdHigh;
  final double presThresholdLow, presThresholdHigh;
  final List<SensorReading> tempHistory, humHistory, presHistory;
  final List<SensorReading> tempBuffer, humBuffer, presBuffer;
  final String? apiError;
  final bool systemStandby;

  const SensorState({
    this.temp = 25.0,
    this.hum = 60.0,
    this.pres = 1013.0,
    this.avgT = 25.0,
    this.avgH = 60.0,
    this.avgP = 1013.0,
    this.targetTemp = 25.0,
    this.targetHum = 60.0,
    this.targetPres = 1013.0,
    this.tempThresholdLow = 20.0,
    this.tempThresholdHigh = 30.0,
    this.humThresholdLow = 50.0,
    this.humThresholdHigh = 70.0,
    this.presThresholdLow = 913.0,
    this.presThresholdHigh = 1113.0,
    this.tempHistory = const [],
    this.humHistory = const [],
    this.presHistory = const [],
    this.tempBuffer = const [],
    this.humBuffer = const [],
    this.presBuffer = const [],
    this.apiError,
    this.systemStandby = false,
  });

  SensorState copyWith({
    double? temp,
    double? hum,
    double? pres,
    double? avgT,
    double? avgH,
    double? avgP,
    double? targetTemp,
    double? targetHum,
    double? targetPres,
    double? tempThresholdLow,
    double? tempThresholdHigh,
    double? humThresholdLow,
    double? humThresholdHigh,
    double? presThresholdLow,
    double? presThresholdHigh,
    List<SensorReading>? tempHistory,
    List<SensorReading>? humHistory,
    List<SensorReading>? presHistory,
    List<SensorReading>? tempBuffer,
    List<SensorReading>? humBuffer,
    List<SensorReading>? presBuffer,
    String? apiError,
    bool clearError = false,
    bool? systemStandby,
  }) {
    return SensorState(
      temp: temp ?? this.temp,
      hum: hum ?? this.hum,
      pres: pres ?? this.pres,
      avgT: avgT ?? this.avgT,
      avgH: avgH ?? this.avgH,
      avgP: avgP ?? this.avgP,
      targetTemp: targetTemp ?? this.targetTemp,
      targetHum: targetHum ?? this.targetHum,
      targetPres: targetPres ?? this.targetPres,
      tempThresholdLow: tempThresholdLow ?? this.tempThresholdLow,
      tempThresholdHigh: tempThresholdHigh ?? this.tempThresholdHigh,
      humThresholdLow: humThresholdLow ?? this.humThresholdLow,
      humThresholdHigh: humThresholdHigh ?? this.humThresholdHigh,
      presThresholdLow: presThresholdLow ?? this.presThresholdLow,
      presThresholdHigh: presThresholdHigh ?? this.presThresholdHigh,
      tempHistory: tempHistory ?? this.tempHistory,
      humHistory: humHistory ?? this.humHistory,
      presHistory: presHistory ?? this.presHistory,
      tempBuffer: tempBuffer ?? this.tempBuffer,
      humBuffer: humBuffer ?? this.humBuffer,
      presBuffer: presBuffer ?? this.presBuffer,
      apiError: clearError ? null : (apiError ?? this.apiError),
      systemStandby: systemStandby ?? this.systemStandby,
    );
  }
}

/// SensorPollingService — periodically fetches readings from the API and
/// updates [sensorStateNotifier].
///
/// Also handles:
///  - CSV logging via [CsvLoggerService]
///  - Zone-based notifications via [NotificationService]
///  - Threshold recalculation when in default-threshold mode
class SensorPollingService extends ChangeNotifier {
  SensorPollingService._();
  static final SensorPollingService instance = SensorPollingService._();

  final EnvironmentRepository _envRepo = EnvironmentRepository();
  final ConfigRepository       _configRepo = ConfigRepository();

  SensorState _state = const SensorState();
  SensorState get state => _state;

  Timer? _timer;
  bool _enabled = false;
  bool _useDefaultThresholds = true;
  bool _alertsEnabled = true;

  /// When non-null, _fetchOnce() will NOT change the standby flag until
  /// this time has passed. Prevents stale cloud data from overriding
  /// the user's explicit Turn Off / Turn On action.
  DateTime? _standbyLockedUntil;

  set alertsEnabled(bool v) { _alertsEnabled = v; }
  set useDefaultThresholds(bool v) { _useDefaultThresholds = v; }

  // ── Start / Stop ─────────────────────────────────────────────────────────

  Future<void> start() async {
    _enabled = true;
    await _loadPersistedStandby(); // await so UI is correct before first poll
    _fetchOnce();
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: kDashboardPollIntervalSeconds),
      (_) => _fetchOnce(),
    );
  }

  /// Restores the persisted systemStandby flag so the button shows the correct
  /// state immediately on app open, before the first API poll completes.
  Future<void> _loadPersistedStandby() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool('system_standby') ?? false;

    // Restore the lock timestamp (prevents stale API from overriding on relaunch)
    final lockMs = prefs.getInt('standby_lock_until');
    if (lockMs != null) {
      final lockTime = DateTime.fromMillisecondsSinceEpoch(lockMs);
      if (DateTime.now().isBefore(lockTime)) {
        _standbyLockedUntil = lockTime;
        debugPrint('[Polling] Lock restored until $lockTime');
      }
    }

    if (saved != _state.systemStandby) {
      _state = _state.copyWith(systemStandby: saved);
      notifyListeners();
    }
    debugPrint('[Polling] Persisted standby loaded: $saved');
  }

  /// Persists the standby flag to SharedPreferences (properly awaited).
  Future<void> _saveStandbyState(bool standby) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('system_standby', standby);
      debugPrint('[Polling] Standby state saved: $standby');
    } catch (e) {
      debugPrint('[Polling] Failed to save standby state: $e');
    }
  }

  /// Called immediately when the user taps Turn Off / Turn On so the state
  /// is persisted before the next poll cycle confirms it from the API.
  /// Locks the standby flag for 2 minutes so _fetchOnce() won't override
  /// it with stale cloud data.
  Future<void> setStandby(bool standby) async {
    _standbyLockedUntil = DateTime.now().add(const Duration(seconds: 120));
    _state = _state.copyWith(systemStandby: standby);
    notifyListeners();
    await _saveStandbyState(standby);
    // Also persist the lock timestamp so it survives app restarts
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('standby_lock_until',
        _standbyLockedUntil!.millisecondsSinceEpoch);
    debugPrint('[Polling] Standby locked until $_standbyLockedUntil');
  }

  void stop() {
    _enabled = false;
    _timer?.cancel();
  }

  // ── External inject (from background isolate) ────────────────────────────

  void inject({double? temp, double? hum, double? pres}) {
    _updateReadings(temp: temp, hum: hum, pres: pres);
  }

  // ── Fetch ────────────────────────────────────────────────────────────────

  Future<void> _fetchOnce() async {
    if (!_enabled) return;
    try {
      final reading = await _envRepo.getLatest();
      final config  = await _configRepo.getLatest();

      if (config != null) {
        // Detect standby: latest config row has all-null or all-zero values
        // (all-zero covers old DB rows before columns were made nullable)
        bool _isOff(double? v) => v == null || v == 0.0;
        final isStandby = _isOff(config.temperature) &&
            _isOff(config.humidity) &&
            _isOff(config.pressure);

        // If the user recently toggled standby, don't let the API override it.
        // This prevents stale cloud data from flipping the button back.
        final isLocked = _standbyLockedUntil != null &&
            DateTime.now().isBefore(_standbyLockedUntil!);
        if (isLocked) {
          debugPrint('[Polling] Standby locked — ignoring API standby=$isStandby');
          // Still update targets if system is running and API has valid data
          if (!_state.systemStandby && !isStandby) {
            final tT = config.temperature ?? _state.targetTemp;
            final tH = config.humidity    ?? _state.targetHum;
            final tP = config.pressure    ?? _state.targetPres;
            _state = _state.copyWith(
              targetTemp: tT, targetHum: tH, targetPres: tP,
              tempThresholdLow:  _useDefaultThresholds ? tT - kTempMaxDeviation  : null,
              tempThresholdHigh: _useDefaultThresholds ? tT + kTempMaxDeviation  : null,
              humThresholdLow:   _useDefaultThresholds ? tH - kHumMaxDeviation   : null,
              humThresholdHigh:  _useDefaultThresholds ? tH + kHumMaxDeviation   : null,
              presThresholdLow:  _useDefaultThresholds ? tP - kPresMaxDeviation  : null,
              presThresholdHigh: _useDefaultThresholds ? tP + kPresMaxDeviation  : null,
            );
          }
        } else if (isStandby) {
          _state = _state.copyWith(systemStandby: true);
          await _saveStandbyState(true);
        } else {
          final tT = config.temperature ?? _state.targetTemp;
          final tH = config.humidity    ?? _state.targetHum;
          final tP = config.pressure    ?? _state.targetPres;
          _state = _state.copyWith(
            systemStandby: false,
            targetTemp: tT, targetHum: tH, targetPres: tP,
            tempThresholdLow:  _useDefaultThresholds ? tT - kTempMaxDeviation  : null,
            tempThresholdHigh: _useDefaultThresholds ? tT + kTempMaxDeviation  : null,
            humThresholdLow:   _useDefaultThresholds ? tH - kHumMaxDeviation   : null,
            humThresholdHigh:  _useDefaultThresholds ? tH + kHumMaxDeviation   : null,
            presThresholdLow:  _useDefaultThresholds ? tP - kPresMaxDeviation  : null,
            presThresholdHigh: _useDefaultThresholds ? tP + kPresMaxDeviation  : null,
          );
          await _saveStandbyState(false);
        }
      }

      if (reading != null) {
        _updateReadings(
          temp: reading.temperature,
          hum:  reading.humidity,
          pres: reading.pressure,
        );

        if (_alertsEnabled) _fireZoneNotifications(reading);
      }

      _state = _state.copyWith(clearError: true);
    } catch (e) {
      _state = _state.copyWith(apiError: e.toString());
    }
    notifyListeners();
  }

  // ── Reading update helpers ───────────────────────────────────────────────

  void _updateReadings({double? temp, double? hum, double? pres}) {
    final tBuf  = List<SensorReading>.from(_state.tempBuffer);
    final hBuf  = List<SensorReading>.from(_state.humBuffer);
    final pBuf  = List<SensorReading>.from(_state.presBuffer);
    final tHist = List<SensorReading>.from(_state.tempHistory);
    final hHist = List<SensorReading>.from(_state.humHistory);
    final pHist = List<SensorReading>.from(_state.presHistory);

    double newT = _state.temp, newH = _state.hum, newP = _state.pres;
    double newAvgT = _state.avgT, newAvgH = _state.avgH, newAvgP = _state.avgP;

    if (temp != null) {
      newT = temp;
      newAvgT = _appendBuffer(tBuf, temp);
      _appendHistory(tHist, temp);
      CsvLoggerService.instance.log('Temperature', temp);
    }
    if (hum != null) {
      newH = hum;
      newAvgH = _appendBuffer(hBuf, hum);
      _appendHistory(hHist, hum);
      CsvLoggerService.instance.log('Humidity', hum);
    }
    if (pres != null) {
      newP = pres;
      newAvgP = _appendBuffer(pBuf, pres);
      _appendHistory(pHist, pres);
      CsvLoggerService.instance.log('Pressure', pres);
    }

    _state = _state.copyWith(
      temp: newT, hum: newH, pres: newP,
      avgT: newAvgT, avgH: newAvgH, avgP: newAvgP,
      tempBuffer: tBuf, humBuffer: hBuf, presBuffer: pBuf,
      tempHistory: tHist, humHistory: hHist, presHistory: pHist,
    );
  }

  double _appendBuffer(List<SensorReading> buf, double val) {
    buf.add(SensorReading(val, DateTime.now()));
    if (buf.length > 5) buf.removeAt(0);
    return buf.isEmpty
        ? 0
        : buf.map((e) => e.value).reduce((a, b) => a + b) / buf.length;
  }

  void _appendHistory(List<SensorReading> hist, double val, {int max = 30}) {
    hist.add(SensorReading(val, DateTime.now()));
    if (hist.length > max) hist.removeAt(0);
  }

  // ── Zone notifications ───────────────────────────────────────────────────

  void _fireZoneNotifications(dynamic reading) {
    NotificationService.instance.checkZone(
      key: 'temp', sensorName: 'Temperature',
      readingStr: '${reading.temperature?.toStringAsFixed(1)}°C',
      notifId: 901,
      value: reading.temperature ?? 0,
      target: _state.targetTemp,
      tolerance: kTempTolerance, maxDev: kTempMaxDeviation,
      useDefaultThresholds: _useDefaultThresholds,
      customLow: _state.tempThresholdLow, customHigh: _state.tempThresholdHigh,
    );
    NotificationService.instance.checkZone(
      key: 'hum', sensorName: 'Humidity',
      readingStr: '${reading.humidity?.toStringAsFixed(0)}%',
      notifId: 902,
      value: reading.humidity ?? 0,
      target: _state.targetHum,
      tolerance: kHumTolerance, maxDev: kHumMaxDeviation,
      useDefaultThresholds: _useDefaultThresholds,
      customLow: _state.humThresholdLow, customHigh: _state.humThresholdHigh,
    );
    NotificationService.instance.checkZone(
      key: 'pres', sensorName: 'Pressure',
      readingStr: '${reading.pressure?.toStringAsFixed(0)} hPa',
      notifId: 903,
      value: reading.pressure ?? 0,
      target: _state.targetPres,
      tolerance: kPresTolerance, maxDev: kPresMaxDeviation,
      useDefaultThresholds: _useDefaultThresholds,
      customLow: _state.presThresholdLow, customHigh: _state.presThresholdHigh,
    );
  }
}

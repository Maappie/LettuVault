import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_new_app/app/app_notifiers.dart';
import 'package:my_new_app/services/sensor_polling_service.dart';
import 'package:my_new_app/src/repositories/config_repository.dart';

/// SettingsController — ChangeNotifier for the Settings Drawer.
///
/// Manages: theme, alerts toggle, alert thresholds, and system config.
/// The Drawer and its sub-widgets listen to this controller.
class SettingsController extends ChangeNotifier {
  SettingsController._();
  static final SettingsController instance = SettingsController._();

  final ConfigRepository _configRepo = ConfigRepository();

  // ── Theme ────────────────────────────────────────────────────────────────

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    themeNotifier.value = _isDarkMode ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    notifyListeners();
  }

  // ── Alerts ───────────────────────────────────────────────────────────────

  bool _alertsEnabled = true;
  bool get alertsEnabled => _alertsEnabled;

  void setAlertsEnabled(bool value) {
    _alertsEnabled = value;
    SensorPollingService.instance.alertsEnabled = value;
    notifyListeners();
  }

  // ── Default-threshold mode ────────────────────────────────────────────────

  bool _useDefaultThresholds = true;
  bool get useDefaultThresholds => _useDefaultThresholds;

  Future<void> setUseDefaultThresholds(bool value) async {
    _useDefaultThresholds = value;
    SensorPollingService.instance.useDefaultThresholds = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useDefaultThresholds', value);
    if (!value) {
      // seed drafts from current live thresholds
      final s = SensorPollingService.instance.state;
      _draftTempLow  = s.tempThresholdLow;
      _draftTempHigh = s.tempThresholdHigh;
      _draftHumLow   = s.humThresholdLow;
      _draftHumHigh  = s.humThresholdHigh;
      _draftPresLow  = s.presThresholdLow;
      _draftPresHigh = s.presThresholdHigh;
      _thresholdError = null;
    }
    notifyListeners();
  }

  // ── Custom threshold drafts ───────────────────────────────────────────────

  double _draftTempLow  = 18.0;
  double _draftTempHigh = 28.0;
  double _draftHumLow   = 40.0;
  double _draftHumHigh  = 80.0;
  double _draftPresLow  = 950.0;
  double _draftPresHigh = 1050.0;
  String? _thresholdError;

  double get draftTempLow  => _draftTempLow;
  double get draftTempHigh => _draftTempHigh;
  double get draftHumLow   => _draftHumLow;
  double get draftHumHigh  => _draftHumHigh;
  double get draftPresLow  => _draftPresLow;
  double get draftPresHigh => _draftPresHigh;
  String? get thresholdError => _thresholdError;

  void updateDraft({
    double? tempLow, double? tempHigh,
    double? humLow, double? humHigh,
    double? presLow, double? presHigh,
  }) {
    if (tempLow  != null) _draftTempLow  = tempLow;
    if (tempHigh != null) _draftTempHigh = tempHigh;
    if (humLow   != null) _draftHumLow   = humLow;
    if (humHigh  != null) _draftHumHigh  = humHigh;
    if (presLow  != null) _draftPresLow  = presLow;
    if (presHigh != null) _draftPresHigh = presHigh;
    _thresholdError = null;
    notifyListeners();
  }

  Future<bool> saveCustomThresholds() async {
    final s = SensorPollingService.instance.state;

    // Validate: Low < High
    if (_draftTempLow >= _draftTempHigh) {
      _thresholdError = 'Temp Low must be less than Temp High.';
      notifyListeners(); return false;
    }
    if (_draftHumLow >= _draftHumHigh) {
      _thresholdError = 'Humid Low must be less than Humid High.';
      notifyListeners(); return false;
    }
    if (_draftPresLow >= _draftPresHigh) {
      _thresholdError = 'Pres Low must be less than Pres High.';
      notifyListeners(); return false;
    }
    // Validate: target inside range
    if (s.targetTemp <= _draftTempLow || s.targetTemp >= _draftTempHigh) {
      _thresholdError = 'Target temp must be inside [${_draftTempLow.toStringAsFixed(0)}–${_draftTempHigh.toStringAsFixed(0)}].';
      notifyListeners(); return false;
    }
    if (s.targetHum <= _draftHumLow || s.targetHum >= _draftHumHigh) {
      _thresholdError = 'Target humidity must be inside [${_draftHumLow.toStringAsFixed(0)}–${_draftHumHigh.toStringAsFixed(0)}].';
      notifyListeners(); return false;
    }
    if (s.targetPres <= _draftPresLow || s.targetPres >= _draftPresHigh) {
      _thresholdError = 'Target pressure must be inside [${_draftPresLow.toStringAsFixed(0)}–${_draftPresHigh.toStringAsFixed(0)}].';
      notifyListeners(); return false;
    }

    _thresholdError = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tempThresholdLow',      _draftTempLow);
    await prefs.setDouble('tempThresholdHigh',     _draftTempHigh);
    await prefs.setDouble('humidityThresholdLow',  _draftHumLow);
    await prefs.setDouble('humidityThresholdHigh', _draftHumHigh);
    await prefs.setDouble('pressureThresholdLow',  _draftPresLow);
    await prefs.setDouble('pressureThresholdHigh', _draftPresHigh);
    notifyListeners();
    return true;
  }

  Future<void> loadSavedThresholds() async {
    final prefs = await SharedPreferences.getInstance();
    _useDefaultThresholds = prefs.getBool('useDefaultThresholds') ?? true;
    _draftTempLow  = prefs.getDouble('tempThresholdLow')      ?? 18.0;
    _draftTempHigh = prefs.getDouble('tempThresholdHigh')     ?? 28.0;
    _draftHumLow   = prefs.getDouble('humidityThresholdLow')  ?? 40.0;
    _draftHumHigh  = prefs.getDouble('humidityThresholdHigh') ?? 80.0;
    _draftPresLow  = prefs.getDouble('pressureThresholdLow')  ?? 950.0;
    _draftPresHigh = prefs.getDouble('pressureThresholdHigh') ?? 1050.0;
    notifyListeners();
  }

  // ── System Config ─────────────────────────────────────────────────────────

  bool   _showSysConfig   = false;
  String _selectedPreset  = 'Custom';
  double _sysConfigTemp   = 25.0;
  double _sysConfigHum    = 60.0;
  double _sysConfigPres   = 1013.0;

  bool   _isSavingSysConfig = false;
  String? _sysConfigError;

  bool   get showSysConfig   => _showSysConfig;
  String get selectedPreset  => _selectedPreset;
  double get sysConfigTemp   => _sysConfigTemp;
  double get sysConfigHum    => _sysConfigHum;
  double get sysConfigPres   => _sysConfigPres;
  bool   get isSavingSysConfig => _isSavingSysConfig;
  String? get sysConfigError => _sysConfigError;

  void toggleSysConfig() {
    _showSysConfig = !_showSysConfig;
    notifyListeners();
  }

  void setSysConfigTemp(double v)  { _sysConfigTemp  = v; _selectedPreset = 'Custom'; notifyListeners(); }
  void setSysConfigHum(double v)   { _sysConfigHum   = v; _selectedPreset = 'Custom'; notifyListeners(); }
  void setSysConfigPres(double v)  { _sysConfigPres  = v; _selectedPreset = 'Custom'; notifyListeners(); }

  void applyPreset(String preset) {
    _selectedPreset = preset;
    if (preset == 'Lettuce') {
      _sysConfigTemp = 15.0; _sysConfigHum = 95.0; _sysConfigPres = 900.0;
    } else if (preset == 'Strawberry') {
      _sysConfigTemp = 20.0; _sysConfigHum = 90.0; _sysConfigPres = 1010.0;
    }
    notifyListeners();
  }

  Future<bool> saveSysConfig() async {
    _isSavingSysConfig = true;
    _sysConfigError = null;
    notifyListeners();

    try {
      await _configRepo.saveConfig(
        temperature: _sysConfigTemp,
        humidity: _sysConfigHum,
        pressure: _sysConfigPres,
      );
      _isSavingSysConfig = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSavingSysConfig = false;
      _sysConfigError = e.toString();
      notifyListeners();
      return false;
    }
  }
}

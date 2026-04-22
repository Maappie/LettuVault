import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_iot/wifi_iot.dart';

import 'package:my_new_app/src/core/constants.dart';
import 'package:my_new_app/src/core/secure_storage.dart';
import 'package:my_new_app/shared/repositories/auth_repository.dart';

enum OnboardingStep { localSetup, homeWifi, cloudAuth }

/// OnboardingController — manages the state for the 3-step first-run wizard.
///
/// Step 1 (localSetup)  : connect phone to Pi AP + verify Pi backend is reachable.
/// Step 2 (homeWifi)    : send home router creds to Pi, Pi connects + internet test.
/// Step 3 (cloudAuth)   : signup or login via cloud server, store JWT + email on Pi.
class OnboardingController extends ChangeNotifier {
  OnboardingController._();
  static final OnboardingController instance = OnboardingController._();

  OnboardingStep _step = OnboardingStep.localSetup;
  bool _loading        = false;
  String? _error;
  bool _localSetupSkipped = false;
  bool _localSetupDone    = false;

  OnboardingStep get step              => _step;
  bool           get loading           => _loading;
  String?        get error             => _error;
  bool           get localSetupSkipped => _localSetupSkipped;
  bool           get localSetupDone    => _localSetupDone;

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _setLoading(bool v)       { _loading = v; _error = null; notifyListeners(); }
  void _setError(String? msg)    { _loading = false; _error = msg; notifyListeners(); }
  void _goTo(OnboardingStep step) { _step = step; _error = null; notifyListeners(); }

  void goBack() {
    if (_loading) return;
    if (_step == OnboardingStep.cloudAuth) {
      if (_localSetupSkipped && !kHomeWifiStepEnabled) {
        // Local was skipped AND home wifi was also skipped — go back to start
        _localSetupSkipped = false;
        _goTo(OnboardingStep.localSetup);
      } else {
        // Either local was done, or home wifi step is enabled (always shown)
        _goTo(OnboardingStep.homeWifi);
      }
    } else if (_step == OnboardingStep.homeWifi) {
      _goTo(OnboardingStep.localSetup);
    }
  }

  // ── Step 1: Local Setup ───────────────────────────────────────────────────

  Future<void> connectToLocalPi({
    required String ssid,
    required String password,
  }) async {
    _setLoading(true);

    // Connect phone to Pi AP via wifi_iot
    try {
      final connected = await WiFiForIoTPlugin.connect(
        ssid,
        password: password,
        security: NetworkSecurity.WPA,
        joinOnce: false,
        withInternet: false,
      );
      if (!connected) {
        _setError(
          "Couldn't connect to LettuVault. Make sure the device is powered on and nearby, then try again.",
        );
        return;
      }

      // 🔴 CRITICAL FIX: Force Android to route traffic through this Wi-Fi interface!
      // Without this, Android sees "no internet" on the Hotspot and attempts to route
      // the HTTP API call over Cellular Data, resulting in OS Error 101 (Network Unreachable).
      await WiFiForIoTPlugin.forceWifiUsage(true);
      
    } catch (e) {
      _setError(kDevMode 
        ? "[DEV ERROR] WiFi Plugin failed: $e" 
        : "Couldn't connect to LettuVault. Make sure the device is powered on and nearby.");
      return;
    }

    // Wait a moment for the connection to stabilise
    await Future.delayed(const Duration(seconds: 2));

    // Determine backend URL (saved override or default gateway)
    final prefs   = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('offline_base_url') ?? '';
    final baseUrl  = savedUrl.isNotEmpty ? savedUrl : kLocalBaseUrl;

    // Verify Pi backend is reachable
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        _setError(
          "Connected to Wi-Fi but couldn't reach LettuVault. Try restarting the device.",
        );
        return;
      }
    } catch (e) {
      _setError(kDevMode
        ? "[DEV ERROR] HTTP timeout. Reaching $baseUrl/ failed: $e"
        : "Connected to Wi-Fi but couldn't reach LettuVault. Try restarting the device."
      );
      return;
    }

    // Persist credentials — only save URL if it was a manual override,
    // otherwise let connectivity_service auto-detect on each switch.
    await SecureStorage.savePiCredentials(ssid: ssid, password: password);
    if (savedUrl.isNotEmpty) {
      await prefs.setString('offline_base_url', baseUrl);
    }

    _localSetupDone    = true;
    _localSetupSkipped = false;
    _loading           = false;
    _goTo(OnboardingStep.homeWifi);
  }

  void skipLocalSetup() {
    _localSetupSkipped = true;
    _localSetupDone    = false;
    _error             = null;
    // If Home Wi-Fi step is mandatory (kHomeWifiStepEnabled = true),
    // still show it even when local setup was skipped.
    // If not mandatory, jump straight to cloud auth.
    _goTo(kHomeWifiStepEnabled ? OnboardingStep.homeWifi : OnboardingStep.cloudAuth);
  }

  // ── Step 2: Home WiFi ─────────────────────────────────────────────────────

  Future<void> connectPiHomeWifi({
    required String ssid,
    required String password,
  }) async {
    _setLoading(true);

    final localKey = await SecureStorage.getLocalApiKey() ?? '';
    final prefs    = await SharedPreferences.getInstance();
    final baseUrl  = prefs.getString('offline_base_url') ?? kLocalBaseUrl;

    try {
      final res = await http.post(
        Uri.parse('$baseUrl$kApiPrefix/connect-home-wifi'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-KEY': localKey,
        },
        body: jsonEncode({'ssid': ssid, 'password': password}),
      ).timeout(const Duration(seconds: 35)); // 25s nmcli + 5s internet test + buffer

      if (res.statusCode == 200) {
        _loading = false;
        _goTo(OnboardingStep.cloudAuth);
        return;
      }

      final body   = jsonDecode(res.body) as Map<String, dynamic>? ?? {};
      final detail = body['detail'] as String? ?? 'Something went wrong. Please try again.';
      _setError(detail);
    } catch (e) {
      _setError(kDevMode
        ? "[DEV ERROR] Home WiFi API request to $baseUrl failed: $e"
        : 'LettuVault took too long to respond. Check your connection to it and try again.'
      );
    }
  }

  void skipHomeWifi() {
    _error = null;
    _goTo(OnboardingStep.cloudAuth);
  }

  // ── Step 3: Cloud Auth ────────────────────────────────────────────────────

  Future<bool> signup({required String email, required String password}) async {
    _setLoading(true);
    final err = await AuthRepository.instance.signup(
      email: email, 
      password: password,
      useProxy: !_localSetupSkipped, // Route through Pi if phone has no internet!
    );
    if (err != null) { _setError(err); return false; }
    
    if (_localSetupSkipped) {
      await _pushIdentityToPi(email); // Proxy already does this, so only do it if direct
    }
    _loading = false;
    notifyListeners();
    return true;
  }

  Future<bool> login({required String email, required String password}) async {
    _setLoading(true);
    final err = await AuthRepository.instance.login(
      email: email, 
      password: password,
      useProxy: !_localSetupSkipped, 
    );
    if (err != null) { _setError(err); return false; }
    
    if (_localSetupSkipped) {
      await _pushIdentityToPi(email); 
    }
    _loading = false;
    notifyListeners();
    return true;
  }

  /// Sends the user email to the Pi local backend so sync_engine.py can tag
  /// all future sync payloads with this identity.
  Future<void> _pushIdentityToPi(String email) async {
    if (_localSetupSkipped) return; // Pi not reachable yet
    try {
      final localKey = await SecureStorage.getLocalApiKey() ?? '';
      final prefs    = await SharedPreferences.getInstance();
      final baseUrl  = prefs.getString('offline_base_url') ?? kLocalBaseUrl;
      await http.post(
        Uri.parse('$baseUrl$kApiPrefix/identity'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-KEY': localKey,
        },
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {
      // Non-blocking — we don't fail onboarding if Pi is temporarily unreachable
      debugPrint('[Onboarding] Could not push identity to Pi (non-fatal).');
    }
  }

  void skipCloudAuth() {
    // Can only skip if local setup was done
    _error = null;
    notifyListeners();
  }
}

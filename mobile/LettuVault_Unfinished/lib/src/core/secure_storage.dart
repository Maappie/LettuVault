import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Keys ──────────────────────────────────────────────────────────────────
  static const _kPiSsid         = 'pi_ssid_v2';
  static const _kPiPassword     = 'pi_password_v2';
  static const _kMobileApiKey   = 'mobile_api_key_v2';
  static const _kLocalApiKey    = 'local_api_key_v2';
  static const _kSetupDone      = 'offline_setup_done_v2';
  static const _kOnboardingDone = 'onboarding_done_v1';
  static const _kJwt            = 'cloud_jwt_v1';
  static const _kUserEmail      = 'cloud_user_email_v1';

  // ── Pi AP Credentials ─────────────────────────────────────────────────────
  static Future<void> savePiCredentials({
    required String ssid,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPiSsid, ssid);
    await prefs.setString(_kPiPassword, password);
    await prefs.setBool(_kSetupDone, true);
  }

  static Future<String?> getPiSsid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPiSsid);
  }

  static Future<String?> getPiPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPiPassword);
  }

  static Future<bool> isOfflineSetupDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSetupDone) ?? false;
  }

  static Future<void> clearPiCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPiSsid);
    await prefs.remove(_kPiPassword);
    await prefs.remove(_kSetupDone);
  }

  // ── API Keys ──────────────────────────────────────────────────────────────
  static Future<void> saveMobileApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMobileApiKey, key);
  }

  static Future<String?> getMobileApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kMobileApiKey);
  }

  static Future<void> saveLocalApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocalApiKey, key);
  }

  static Future<String?> getLocalApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLocalApiKey);
  }

  // ── Cloud JWT & User Email ────────────────────────────────────────────────
  static Future<void> saveJwt(String token) async {
    await _storage.write(key: _kJwt, value: token);
  }

  static Future<String?> getJwt() async {
    return await _storage.read(key: _kJwt);
  }

  static Future<void> saveUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserEmail, email);
  }

  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserEmail);
  }

  // ── Onboarding Completion ─────────────────────────────────────────────────
  static Future<bool> isOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboardingDone) ?? false;
  }

  static Future<void> markOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingDone, true);
  }

  // ── Seed defaults on first run ────────────────────────────────────────────
  static Future<void> seedDefaultsIfNeeded() async {
    final mobileKey = await getMobileApiKey();
    if (mobileKey == null) {
      await saveMobileApiKey('LettuVault-Mobile-API-KEY-1231325213!@PLMstudents2026');
    }
    final localKey = await getLocalApiKey();
    if (localKey == null) {
      await saveLocalApiKey('lettuce-master-key-2024');
    }
  }
}

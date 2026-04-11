import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Keys ──────────────────────────────────────────────────────────────────
  static const _kPiSsid       = 'pi_ssid_v2';
  static const _kPiPassword   = 'pi_password_v2';
  static const _kMobileApiKey = 'mobile_api_key_v2';
  static const _kLocalApiKey  = 'local_api_key_v2';
  static const _kSetupDone    = 'offline_setup_done_v2';

  // ── Pi AP Credentials (Using SharedPreferences for high reliability on all ROMs) ──
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

  // ── API Keys (Stored in SharedPreferences for consistency and persistence reliability) ──
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

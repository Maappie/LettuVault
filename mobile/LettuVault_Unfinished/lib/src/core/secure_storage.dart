/// secure_storage.dart — Encrypted local storage for sensitive credentials.
///
/// Stores Pi AP credentials and API keys using flutter_secure_storage
/// (backed by Android Keystore / iOS Keychain).
/// This is the Flutter equivalent of a .env file for secrets.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Keys ──────────────────────────────────────────────────────────────────
  static const _kPiSsid       = 'pi_ssid';
  static const _kPiPassword   = 'pi_password';
  static const _kMobileApiKey = 'mobile_api_key';
  static const _kLocalApiKey  = 'local_api_key';
  static const _kSetupDone    = 'offline_setup_done';

  // ── Pi AP Credentials ─────────────────────────────────────────────────────
  static Future<void> savePiCredentials({
    required String ssid,
    required String password,
  }) async {
    await _storage.write(key: _kPiSsid, value: ssid);
    await _storage.write(key: _kPiPassword, value: password);
    await _storage.write(key: _kSetupDone, value: 'true');
  }

  static Future<String?> getPiSsid() => _storage.read(key: _kPiSsid);
  static Future<String?> getPiPassword() => _storage.read(key: _kPiPassword);
  static Future<bool> isOfflineSetupDone() async {
    final v = await _storage.read(key: _kSetupDone);
    return v == 'true';
  }

  static Future<void> clearPiCredentials() async {
    await _storage.delete(key: _kPiSsid);
    await _storage.delete(key: _kPiPassword);
    await _storage.delete(key: _kSetupDone);
  }

  // ── API Keys ──────────────────────────────────────────────────────────────
  /// Cloud mobile API key (used in Online mode) — X-MOBILE-API-KEY header
  static Future<void> saveMobileApiKey(String key) =>
      _storage.write(key: _kMobileApiKey, value: key);
  static Future<String?> getMobileApiKey() => _storage.read(key: _kMobileApiKey);

  /// Local backend API key (used in Offline mode) — X-API-KEY header
  static Future<void> saveLocalApiKey(String key) =>
      _storage.write(key: _kLocalApiKey, value: key);
  static Future<String?> getLocalApiKey() => _storage.read(key: _kLocalApiKey);

  // ── Seed defaults on first run ────────────────────────────────────────────
  /// Call once at startup to pre-populate keys if they haven't been set yet.
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

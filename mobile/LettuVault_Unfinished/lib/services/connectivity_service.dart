import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_iot/wifi_iot.dart';

import 'package:my_new_app/src/core/app_mode.dart';
import 'package:my_new_app/src/core/constants.dart';
import 'package:my_new_app/src/core/secure_storage.dart';

/// ConnectivityService — manages switching between Online and Offline modes.
///
/// Offline mode connects the phone to the Raspberry Pi's Wi-Fi hotspot and
/// forces Android to route traffic over that interface even without internet.
/// Online mode releases the route lock and disconnects from the Pi AP.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  // ── Online ───────────────────────────────────────────────────────────────

  Future<void> switchToOnline() async {
    // Release Wi-Fi route lock so Android can use Cellular/Internet again
    WiFiForIoTPlugin.forceWifiUsage(false).catchError((_) => false);
    // Disconnect from Pi/hotspot AP
    WiFiForIoTPlugin.disconnect().catchError((e) {
      debugPrint('[Connectivity] disconnect error (ignored): $e');
      return false;
    });
    appModeNotifier.value = AppMode.online;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_mode', 'online');
  }

  // ── Offline ──────────────────────────────────────────────────────────────

  /// Returns `null` on success, or an error message string on failure.
  ///
  /// The [onCancelled] callback is checked after the Wi-Fi connect call
  /// so that the UI can cancel mid-connection.
  Future<String?> switchToOffline({
    required bool Function() isCancelled,
  }) async {
    try {
      final ssid = await SecureStorage.getPiSsid();
      final pass = await SecureStorage.getPiPassword();

      if (ssid == null || pass == null) {
        return 'no_credentials'; // caller shows setup screen
      }

      final connected = await WiFiForIoTPlugin.connect(
        ssid,
        password: pass,
        security: NetworkSecurity.WPA,
        joinOnce: false,
        withInternet: false,
      );

      if (isCancelled()) return null; // cancelled — caller handles UI

      if (connected == true) {
        // Force Android to route through this Wi-Fi even without internet
        await WiFiForIoTPlugin.forceWifiUsage(true);
        await _resolveGateway();
        appModeNotifier.value = AppMode.offline;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('app_mode', 'offline');
        return null; // success
      } else {
        return 'Could not connect. Ensure the LettuVault AP is nearby and the password is correct.';
      }
    } catch (e) {
      return kDevMode 
          ? "[DEV ERROR] WiFi connection exception: $e" 
          : 'A networking error occurred while attempting to connect.';
    }
  }

  // ── Gateway detection ────────────────────────────────────────────────────

  /// Detects and stores the backend gateway URL (phone IP x.x.x.Y → x.x.x.1).
  /// Skips if a manual override is already stored in SharedPreferences.
  Future<void> _resolveGateway() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString('offline_base_url') ?? '';
      if (existing.isNotEmpty) {
        debugPrint('[Connectivity] Using stored URL: $existing');
        return;
      }

      String? gateway;
      for (var iface in await NetworkInterface.list()) {
        for (var addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback &&
              _isPrivateIp(addr.address)) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              parts[3] = '1';
              gateway = parts.join('.');
              break;
            }
          }
        }
        if (gateway != null) break;
      }

      if (gateway != null) {
        await prefs.setString('offline_base_url', 'http://$gateway:8000');
        debugPrint('[Connectivity] Auto-detected gateway: http://$gateway:8000');
      }
    } catch (e) {
      debugPrint('[Connectivity] Gateway detection error: $e');
    }
  }

  bool _isPrivateIp(String ip) {
    if (ip.startsWith('192.168.') || ip.startsWith('10.')) return true;
    final parts = ip.split('.');
    if (parts.length == 4 && parts[0] == '172') {
      final second = int.tryParse(parts[1]) ?? 0;
      if (second >= 16 && second <= 31) return true;
    }
    return false;
  }
}

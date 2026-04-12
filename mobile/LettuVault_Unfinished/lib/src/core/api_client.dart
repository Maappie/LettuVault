import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../core/app_mode.dart';
import '../core/secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mode-aware HTTP wrapper.
///
/// - Online mode  → calls Render cloud server with X-MOBILE-API-KEY
/// - Offline mode → calls local Raspberry Pi backend with X-API-KEY
///
/// Automatically reads the active [appModeNotifier] value on each request,
/// so switching modes mid-session takes effect immediately on the next poll.
class ApiClient {
  /// Build the correct base URL from the current app mode.
  Future<String> get _baseUrl async {
    if (appModeNotifier.value == AppMode.online) {
      return kCloudBaseUrl;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('offline_base_url') ?? kLocalBaseUrl;
  }

  /// Build the correct auth header from the current app mode and secure storage.
  Future<Map<String, String>> _buildHeaders() async {
    final isOnline = appModeNotifier.value == AppMode.online;
    
    if (isOnline) {
      // Cloud server identifies users via JWT for data segregation.
      // Only attach the header if we actually have a token stored.
      final jwt = await SecureStorage.getJwt();
      if (jwt != null && jwt.isNotEmpty) {
        return {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        };
      }
      // No JWT yet (user hasn't logged in to cloud) — send no auth header.
      // The cloud server will respond 403, which the UI surfaces as "not logged in".
      return {'Content-Type': 'application/json'};
    } else {
      // Local Raspberry Pi Pi uses the static hardware API key
      final localKey = await SecureStorage.getLocalApiKey() ?? '';
      return {
        'Content-Type': 'application/json',
        'X-API-KEY': localKey,
      };
    }
  }

  /// GET request to [endpoint] (e.g. '/sensor-readings').
  Future<dynamic> get(String endpoint) async {
    final base = await _baseUrl;
    final url = Uri.parse('$base$kApiPrefix$endpoint');
    final headers = await _buildHeaders();
    final response = await http.get(url, headers: headers).timeout(
      const Duration(seconds: 8),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      throw ApiException('Unauthorized — check your API key', response.statusCode);
    } else {
      throw ApiException('Request failed: ${response.statusCode}', response.statusCode);
    }
  }

  /// POST request to [endpoint] with a JSON [body].
  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final base = await _baseUrl;
    final url = Uri.parse('$base$kApiPrefix$endpoint');
    final headers = await _buildHeaders();
    final response = await http.post(
      url,
      headers: headers,
      body: json.encode(body),
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      throw ApiException('Unauthorized — check your API key', response.statusCode);
    } else {
      throw ApiException('Request failed: ${response.statusCode}', response.statusCode);
    }
  }
}

/// Simple exception class for API errors.
class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

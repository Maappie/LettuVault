import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

/// Lightweight HTTP wrapper that injects the X-API-KEY header on every request.
///
/// This is the single point of contact for all network calls.  All repositories
/// should use this client instead of raw `http.get` / `http.post`.
class ApiClient {
  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'X-API-KEY': kApiKey,
  };

  /// GET request to [endpoint] (e.g. '/internal-environment').
  /// Returns the decoded JSON body.
  Future<dynamic> get(String endpoint) async {
    final url = Uri.parse('$kBaseUrl$kApiPrefix$endpoint');
    final response = await http.get(url, headers: _headers).timeout(
      const Duration(seconds: 6),
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
    final url = Uri.parse('$kBaseUrl$kApiPrefix$endpoint');
    final response = await http.post(
      url,
      headers: _headers,
      body: json.encode(body),
    ).timeout(const Duration(seconds: 6));

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

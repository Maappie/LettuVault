import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:my_new_app/src/core/constants.dart';
import 'package:my_new_app/src/core/secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AuthRepository — handles cloud signup and login.
///
/// Translates server error codes into user-friendly messages.
class AuthRepository {
  AuthRepository._();
  static final AuthRepository instance = AuthRepository._();

  /// Returns `null` on success (token already saved), or a user-friendly error string.
  Future<String?> signup({required String email, required String password, bool useProxy = false}) async {
    return _post('/auth/signup', email: email, password: password, useProxy: useProxy);
  }

  /// Returns `null` on success, or a user-friendly error string.
  Future<String?> login({required String email, required String password, bool useProxy = false}) async {
    return _post('/auth/login', email: email, password: password, useProxy: useProxy);
  }

  Future<String?> _post(String path, {required String email, required String password, bool useProxy = false}) async {
    try {
      final cloudUrl = '$kCloudBaseUrl$kApiPrefix$path';
      
      Uri uri;
      Map<String, String> headers = {'Content-Type': 'application/json'};
      Map<String, dynamic> body;

      if (useProxy) {
        // Route through the local Raspberry Pi proxy because phone has no internet
        final prefs = await SharedPreferences.getInstance();
        final localBase = prefs.getString('offline_base_url') ?? kLocalBaseUrl;
        uri = Uri.parse('$localBase$kApiPrefix/proxy-auth');
        
        final localKey = await SecureStorage.getLocalApiKey() ?? '';
        headers['X-API-KEY'] = localKey;
        
        body = {
          'email': email,
          'password': password,
          'cloud_auth_url': cloudUrl,
        };
      } else {
        // Direct to cloud
        uri = Uri.parse(cloudUrl);
        body = {'email': email, 'password': password};
      }

      final res = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final token = body['access_token'] as String?;
        final resEmail = body['email'] as String? ?? email;
        if (token != null) {
          await SecureStorage.saveJwt(token);
          await SecureStorage.saveUserEmail(resEmail);
        }
        return null; // success
      }

      // Parse error detail
      final errBody = jsonDecode(res.body) as Map<String, dynamic>? ?? {};
      final detail = errBody['detail'] as String? ?? '';

      return _friendlyError(res.statusCode, detail);
    } on http.ClientException catch (e) {
      return kDevMode ? "[DEV ERROR] HTTP Client error: $e" : 'No internet connection. Check your network and try again.';
    } catch (e) {
      return kDevMode ? "[DEV ERROR] Request failed: $e" : 'The connection timed out. Check your internet and try again.';
    }
  }

  String _friendlyError(int status, String detail) {
    if (status == 409 || detail == 'email_taken') {
      return 'That email is already registered. Try signing in instead.';
    }
    if (status == 401 || detail == 'invalid_credentials') {
      return 'Incorrect email or password. Please try again.';
    }
    if (status == 403 || detail == 'account_disabled') {
      return 'Your account has been disabled. Contact support.';
    }
    if (status >= 500) {
      return 'The server is temporarily unavailable. Please try again later.';
    }
    return 'Something went wrong. Please try again.';
  }
}

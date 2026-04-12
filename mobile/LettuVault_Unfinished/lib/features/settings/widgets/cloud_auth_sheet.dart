import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_new_app/shared/repositories/auth_repository.dart';
import 'package:my_new_app/src/core/app_mode.dart';
import 'package:my_new_app/src/core/constants.dart';
import 'package:my_new_app/src/core/secure_storage.dart';

/// CloudAuthSheet — a bottom sheet that lets the user sign up or log in
/// to the cloud server at any point after onboarding.
///
/// Shown from Settings Drawer → "Online Mode Setup".
/// On success, saves JWT + email and calls [onSuccess].
class CloudAuthSheet extends StatefulWidget {
  final VoidCallback? onSuccess;

  const CloudAuthSheet({super.key, this.onSuccess});

  /// Opens this sheet as a modal bottom sheet.
  static Future<void> show(BuildContext context, {VoidCallback? onSuccess}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CloudAuthSheet(onSuccess: onSuccess),
    );
  }

  @override
  State<CloudAuthSheet> createState() => _CloudAuthSheetState();
}

class _CloudAuthSheetState extends State<CloudAuthSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading    = false;
  bool _obscure    = true;
  String? _error;
  String? _loggedInEmail;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {})); // rebuild on tab switch
    _loadExistingEmail();
  }

  Future<void> _loadExistingEmail() async {
    final email = await SecureStorage.getUserEmail();
    final jwt   = await SecureStorage.getJwt();
    if (email != null && email.isNotEmpty && jwt != null && jwt.isNotEmpty && mounted) {
      setState(() => _loggedInEmail = email);
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isSignup = _tab.index == 1;
    final email    = _emailCtrl.text.trim();
    final pass     = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please fill in both fields.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    final useProxy = appModeNotifier.value == AppMode.offline;

    final error = isSignup
        ? await AuthRepository.instance.signup(email: email, password: pass, useProxy: useProxy)
        : await AuthRepository.instance.login(email: email, password: pass, useProxy: useProxy);

    if (!mounted) return;

    if (error != null) {
      setState(() { _loading = false; _error = error; });
    } else {
      // Proxy already saves identity locally, so only push if direct
      if (!useProxy) {
        await _pushIdentityToPi(email);
      }
      setState(() { _loading = false; _loggedInEmail = email; });
      widget.onSuccess?.call();
    }
  }

  /// Silently notifies the local Pi backend of the logged-in email.
  /// Non-fatal — failure is swallowed so the UI never blocks.
  Future<void> _pushIdentityToPi(String email) async {
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
      ).timeout(const Duration(seconds: 6));
      debugPrint('[CloudAuth] Identity pushed to Pi: $email');
    } catch (_) {
      // Non-blocking — Pi may not be reachable if user is on a different network
      debugPrint('[CloudAuth] Could not push identity to Pi (non-fatal).');
    }
  }

  Future<void> _signOut() async {
    await SecureStorage.saveJwt('');
    await SecureStorage.saveUserEmail('');
    if (mounted) setState(() => _loggedInEmail = null);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: _loggedInEmail != null
            ? _buildLoggedIn(scheme)
            : _buildAuthForm(scheme),
      ),
    );
  }

  // ── Already logged in state ───────────────────────────────────────────────

  Widget _buildLoggedIn(ColorScheme scheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _handle(),
        const SizedBox(height: 20),
        Icon(Icons.cloud_done, color: Colors.green.shade400, size: 48),
        const SizedBox(height: 12),
        Text('Signed in to Cloud',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                color: scheme.onSurface)),
        const SizedBox(height: 6),
        Text(_loggedInEmail!,
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6))),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            label: const Text('Sign Out',
                style: TextStyle(color: Colors.redAccent)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _signOut,
          ),
        ),
      ],
    );
  }

  // ── Login / Signup form ───────────────────────────────────────────────────

  Widget _buildAuthForm(ColorScheme scheme) {
    final isSignup = _tab.index == 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _handle(),
        const SizedBox(height: 16),

        // Title
        Row(
          children: [
            Icon(Icons.cloud_outlined, color: scheme.primary, size: 26),
            const SizedBox(width: 10),
            Text('Online Mode Setup',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: scheme.onSurface)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Sign in or create a cloud account to access your data remotely.',
          style: TextStyle(fontSize: 12,
              color: scheme.onSurface.withValues(alpha: 0.55)),
        ),
        const SizedBox(height: 16),

        // Tab bar only (no TabBarView — avoids unbounded height crash)
        TabBar(
          controller: _tab,
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.45),
          indicatorColor: scheme.primary,
          tabs: const [Tab(text: 'Sign In'), Tab(text: 'Sign Up')],
        ),
        const SizedBox(height: 16),

        // Email field
        TextField(
          controller: _emailCtrl,
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),

        // Password field
        TextField(
          controller: _passCtrl,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            isDense: true,
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),

        // Error message
        if (_error != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_error!,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 12)),
              ),
            ],
          ),
        ],

        const SizedBox(height: 20),

        // Submit button — label changes with active tab, NO TabBarView
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _loading
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(
                    isSignup ? 'Create Account' : 'Sign In',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _handle() => Center(
        child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
}

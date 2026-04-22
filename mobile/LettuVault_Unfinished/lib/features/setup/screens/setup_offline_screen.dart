import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_new_app/src/core/constants.dart';
import 'package:my_new_app/src/core/secure_storage.dart';

/// SetupOfflineScreen — first-time offline credentials wizard.
///
/// Shown only when the user has never configured Pi AP credentials.
/// Can be skipped — the app stays in Online mode by default.
class SetupOfflineScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SetupOfflineScreen({super.key, required this.onDone});

  @override
  State<SetupOfflineScreen> createState() => _SetupOfflineScreenState();
}

class _SetupOfflineScreenState extends State<SetupOfflineScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _ssidCtrl = TextEditingController(text: kDefaultPiSsid);
  final _passCtrl = TextEditingController();
  final _ipCtrl   = TextEditingController();

  bool _obscure      = true;
  bool _saving       = false;
  bool _showIpField  = false;
  bool _isLoading    = true;
  bool _isConfigured = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    _ipCtrl.dispose();
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────

  Future<void> _loadExisting() async {
    final ssid = await SecureStorage.getPiSsid();
    final pass = await SecureStorage.getPiPassword();
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('offline_base_url') ?? '';
    if (savedUrl.isNotEmpty) {
      final uri = Uri.tryParse(savedUrl);
      if (uri != null) _ipCtrl.text = uri.host;
    }
    if (ssid != null && ssid.isNotEmpty && pass != null) {
      _ssidCtrl.text = ssid;
      _passCtrl.text = pass;
      setState(() { _isConfigured = true; _isLoading = false; });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await SecureStorage.savePiCredentials(
      ssid: _ssidCtrl.text.trim(),
      password: _passCtrl.text,
    );
    final overrideIp = _ipCtrl.text.trim();
    final prefs = await SharedPreferences.getInstance();
    if (overrideIp.isNotEmpty) {
      await prefs.setString('offline_base_url', 'http://$overrideIp:8000');
    } else {
      // Clear the stored URL so auto-detection kicks in
      await prefs.remove('offline_base_url');
    }
    setState(() => _saving = false);
    widget.onDone();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final bgColor      = isDark ? const Color(0xFF0A150C) : const Color(0xFFF6F8FA);
    final cardColor    = isDark ? const Color(0xFF0D2010) : Colors.white;
    final primaryGreen = isDark ? const Color(0xFF4ADE80) : Colors.green.shade600;
    final textColor    = isDark ? Colors.white : Colors.black87;
    final subColor     = isDark ? const Color(0xFF9CA3AF) : Colors.black54;
    final borderColor  = isDark ? const Color(0xFF1E3A22) : Colors.green.shade200;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(child: CircularProgressIndicator(color: primaryGreen)),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: _isConfigured
              ? _ConfiguredView(
                  ssid: _ssidCtrl.text,
                  primaryGreen: primaryGreen,
                  textColor: textColor,
                  subColor: subColor,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  isDark: isDark,
                  onEdit: () => setState(() => _isConfigured = false),
                  onDone: widget.onDone,
                )
              : _FormView(
                  formKey: _formKey,
                  ssidCtrl: _ssidCtrl,
                  passCtrl: _passCtrl,
                  ipCtrl: _ipCtrl,
                  obscure: _obscure,
                  saving: _saving,
                  showIpField: _showIpField,
                  isDark: isDark,
                  primaryGreen: primaryGreen,
                  textColor: textColor,
                  subColor: subColor,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  onToggleObscure: () => setState(() => _obscure = !_obscure),
                  onToggleIp: () => setState(() => _showIpField = !_showIpField),
                  onSave: _save,
                  onSkip: widget.onDone,
                ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ConfiguredView extends StatelessWidget {
  final String ssid;
  final Color primaryGreen, textColor, subColor, cardColor, borderColor;
  final bool isDark;
  final VoidCallback onEdit, onDone;

  const _ConfiguredView({
    required this.ssid,
    required this.primaryGreen,
    required this.textColor,
    required this.subColor,
    required this.cardColor,
    required this.borderColor,
    required this.isDark,
    required this.onEdit,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 60),
        Icon(Icons.wifi_protected_setup, color: primaryGreen, size: 80),
        const SizedBox(height: 24),
        Text(
          'Offline Mode Configured',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 12),
        Text(
          'Your phone is currently set to connect to:',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: subColor),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: isDark
                ? null
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.router, color: primaryGreen, size: 20),
              const SizedBox(width: 12),
              Text(
                ssid,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: primaryGreen),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.edit, size: 20),
            label: const Text('Change Configuration',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen.withValues(alpha: 0.15),
              foregroundColor: primaryGreen,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onEdit,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: onDone,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: isDark ? const Color(0xFF0A150C) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Back to Dashboard',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }
}

class _FormView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController ssidCtrl, passCtrl, ipCtrl;
  final bool obscure, saving, showIpField, isDark;
  final Color primaryGreen, textColor, subColor, cardColor, borderColor;
  final VoidCallback onToggleObscure, onToggleIp, onSave, onSkip;

  const _FormView({
    required this.formKey,
    required this.ssidCtrl,
    required this.passCtrl,
    required this.ipCtrl,
    required this.obscure,
    required this.saving,
    required this.showIpField,
    required this.isDark,
    required this.primaryGreen,
    required this.textColor,
    required this.subColor,
    required this.cardColor,
    required this.borderColor,
    required this.onToggleObscure,
    required this.onToggleIp,
    required this.onSave,
    required this.onSkip,
  });

  InputDecoration _inputDeco({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? const Color(0xFF6B7280) : Colors.black38),
        prefixIcon: Icon(icon, color: primaryGreen, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      );

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
          color: isDark ? const Color(0xFFD1FAE5) : primaryGreen,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: primaryGreen.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.wifi_find, color: primaryGreen, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('App Config',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 4),
                    Text('Set AP connection',
                        style: TextStyle(fontSize: 13, color: subColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),

          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryGreen.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: primaryGreen.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: primaryGreen, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Offline mode connects your phone directly to the '
                    "Raspberry Pi's Wi-Fi Access Point for real-time "
                    'local monitoring — no internet required.',
                    style: TextStyle(fontSize: 13, color: subColor, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // SSID
          _label('Wi-Fi Network Name (SSID)'),
          const SizedBox(height: 8),
          TextFormField(
            controller: ssidCtrl,
            style: TextStyle(color: textColor),
            decoration: _inputDeco(hint: 'e.g. LettuVault-01', icon: Icons.router),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Enter the Pi SSID' : null,
          ),
          const SizedBox(height: 20),

          // Password
          _label('Wi-Fi Password'),
          const SizedBox(height: 8),
          TextFormField(
            controller: passCtrl,
            obscureText: obscure,
            style: TextStyle(color: textColor),
            decoration: _inputDeco(
              hint: 'Enter password',
              icon: Icons.lock_outline,
              suffix: IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_off : Icons.visibility,
                  color: subColor,
                ),
                onPressed: onToggleObscure,
              ),
            ),
            validator: (v) =>
                v == null || v.isEmpty ? 'Enter the Wi-Fi password' : null,
          ),

          // IP override
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onToggleIp,
            child: Row(
              children: [
                Icon(Icons.tune, size: 14, color: subColor),
                const SizedBox(width: 6),
                Text(
                  'Backend IP Override (optional)',
                  style: TextStyle(
                    fontSize: 12, color: subColor,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(showIpField ? Icons.expand_less : Icons.expand_more,
                    size: 14, color: subColor),
              ],
            ),
          ),
          if (showIpField) ...[
            const SizedBox(height: 8),
            Text(
              'Leave blank to auto-detect (recommended for Pi). '
              "Only fill this if auto-detect fails — e.g. enter your laptop's Wi-Fi IP like 192.168.68.144.",
              style: TextStyle(fontSize: 11, color: subColor, height: 1.4),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: ipCtrl,
              style: TextStyle(color: textColor),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputDeco(
                hint: 'e.g. 192.168.68.144  (blank = auto)',
                icon: Icons.dns_outlined,
              ),
            ),
          ],
          const SizedBox(height: 40),

          // Save
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: saving ? null : onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: isDark ? const Color(0xFF0A150C) : Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: saving
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? const Color(0xFF0A150C) : Colors.white,
                      ),
                    )
                  : const Text('Save & Continue',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),

          // Skip
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: onSkip,
              child: Text(
                ssidCtrl.text == kDefaultPiSsid && passCtrl.text.isEmpty
                    ? 'Skip — stay in Online mode'
                    : 'Cancel',
                style: TextStyle(color: subColor, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

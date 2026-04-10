import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/secure_storage.dart';

/// First-time offline mode setup screen.
///
/// Shown only once when the user has never configured the Pi AP credentials.
/// They can skip it — the app stays in Online mode by default.
class SetupOfflineScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SetupOfflineScreen({super.key, required this.onDone});

  @override
  State<SetupOfflineScreen> createState() => _SetupOfflineScreenState();
}

class _SetupOfflineScreenState extends State<SetupOfflineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ssidCtrl = TextEditingController(text: kDefaultPiSsid);
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _saving = false;

  @override
  void dispose() {
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await SecureStorage.savePiCredentials(
      ssid: _ssidCtrl.text.trim(),
      password: _passCtrl.text,
    );
    setState(() => _saving = false);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A150C),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // ── Header ─────────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ADE80).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF4ADE80).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(Icons.wifi_find,
                          color: Color(0xFF4ADE80), size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Set Up Offline Mode',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Connect to the LettuVault Pi AP',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 36),

                // ── Info card ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ADE80).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF4ADE80).withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          color: Color(0xFF4ADE80), size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Offline mode connects your phone directly to the '
                          'Raspberry Pi\'s Wi-Fi Access Point for real-time '
                          'local monitoring — no internet required.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9CA3AF),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── SSID field ────────────────────────────────────────────
                _fieldLabel('Wi-Fi Network Name (SSID)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _ssidCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(
                    hint: 'e.g. LettuVault-01',
                    icon: Icons.router,
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter the Pi SSID' : null,
                ),

                const SizedBox(height: 20),

                // ── Password field ────────────────────────────────────────
                _fieldLabel('Wi-Fi Password'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(
                    hint: 'Enter password',
                    icon: Icons.lock_outline,
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: const Color(0xFF6B7280),
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Enter the Wi-Fi password' : null,
                ),

                const SizedBox(height: 40),

                // ── Save button ───────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4ADE80),
                      foregroundColor: const Color(0xFF0A150C),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF0A150C)),
                          )
                        : const Text(
                            'Save & Continue',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Skip button ───────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: widget.onDone,
                    child: const Text(
                      'Skip — stay in Online mode',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFFD1FAE5),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      );

  InputDecoration _inputDecoration(
          {required String hint, required IconData icon}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF6B7280)),
        prefixIcon: Icon(icon, color: const Color(0xFF4ADE80), size: 20),
        filled: true,
        fillColor: const Color(0xFF0D2010),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFF1E3A22)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFF1E3A22)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFF4ADE80), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      );
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_new_app/src/core/constants.dart';
import 'package:my_new_app/features/onboarding/controllers/onboarding_controller.dart';
import 'package:my_new_app/features/onboarding/widgets/onboarding_widgets.dart';

/// StepLocalSetup — Step 1 of onboarding.
///
/// Shows Pi AP setup instructions + SSID/Password form.
/// User can Connect (verifies Pi backend reachable) or Skip (disables offline mode).
class StepLocalSetup extends StatefulWidget {
  final OnboardingController ctrl;
  const StepLocalSetup({super.key, required this.ctrl});

  @override
  State<StepLocalSetup> createState() => _StepLocalSetupState();
}

class _StepLocalSetupState extends State<StepLocalSetup> {
  final _formKey   = GlobalKey<FormState>();
  final _ssidCtrl  = TextEditingController(text: kDefaultPiSsid);
  final _passCtrl  = TextEditingController();
  final _ipCtrl    = TextEditingController();
  bool _obscure    = true;
  bool _showIpHint = false;

  @override
  void dispose() {
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    _ipCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final green  = isDark ? const Color(0xFF4ADE80) : Colors.green.shade600;
    final sub    = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // ── Header ─────────────────────────────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.wifi_find, color: green, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Connect to LettuVault',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface)),
                  Text('Step 1 of 3', style: TextStyle(fontSize: 12, color: sub)),
                ],
              )),
            ]),
            const SizedBox(height: 20),

            OnboardingInfoCard(
              icon: Icons.lightbulb_outline,
              color: green,
              text: 'Make sure your LettuVault device is powered on. '
                    'It broadcasts its own Wi-Fi network — connect below.',
            ),
            const SizedBox(height: 24),

            OnboardingFieldLabel('Wi-Fi Network Name (SSID)', color: green),
            const SizedBox(height: 6),
            OnboardingTextField(
              controller: _ssidCtrl,
              hint: 'e.g. LettuVault-01',
              icon: Icons.router,
              accentColor: green,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the SSID' : null,
            ),
            const SizedBox(height: 16),

            OnboardingFieldLabel('Wi-Fi Password', color: green),
            const SizedBox(height: 6),
            OnboardingTextField(
              controller: _passCtrl,
              hint: 'Enter password',
              icon: Icons.lock_outline,
              accentColor: green,
              obscureText: _obscure,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                    color: sub, size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Enter the Wi-Fi password' : null,
            ),
            const SizedBox(height: 10),

            // ── IP override ────────────────────────────────────────────────
            GestureDetector(
              onTap: () => setState(() => _showIpHint = !_showIpHint),
              child: Row(children: [
                Icon(Icons.tune, size: 13, color: sub),
                const SizedBox(width: 5),
                Text('Backend IP override (advanced)',
                    style: TextStyle(fontSize: 12, color: sub,
                        decoration: TextDecoration.underline)),
                Icon(_showIpHint ? Icons.expand_less : Icons.expand_more,
                    size: 14, color: sub),
              ]),
            ),
            if (_showIpHint) ...[
              const SizedBox(height: 8),
              Text(
                "Leave blank to auto-detect. Only fill this if the connection fails.",
                style: TextStyle(fontSize: 11, color: sub, height: 1.4),
              ),
              const SizedBox(height: 6),
              OnboardingTextField(
                controller: _ipCtrl,
                hint: 'e.g. 192.168.68.144 (blank = auto)',
                icon: Icons.dns_outlined,
                accentColor: green,
                keyboardType: TextInputType.number,
              ),
            ],

            if (widget.ctrl.error != null) ...[
              const SizedBox(height: 16),
              OnboardingErrorBox(widget.ctrl.error!),
            ],
            const SizedBox(height: 28),

            OnboardingPrimaryButton(
              label: 'Connect to LettuVault',
              color: green,
              icon: Icons.wifi,
              loading: widget.ctrl.loading,
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                final ip = _ipCtrl.text.trim();
                if (ip.isNotEmpty) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('offline_base_url', 'http://$ip:8000');
                }
                await widget.ctrl.connectToLocalPi(
                  ssid: _ssidCtrl.text.trim(),
                  password: _passCtrl.text,
                );
              },
            ),
            const SizedBox(height: 12),

            Center(
              child: TextButton(
                onPressed: widget.ctrl.loading ? null : widget.ctrl.skipLocalSetup,
                child: Text('Skip — use remote/online mode only',
                    style: TextStyle(fontSize: 13, color: sub)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

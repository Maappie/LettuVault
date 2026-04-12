import 'package:flutter/material.dart';
import 'package:my_new_app/features/onboarding/controllers/onboarding_controller.dart';
import 'package:my_new_app/features/onboarding/widgets/onboarding_widgets.dart';
import 'package:my_new_app/src/core/constants.dart';

/// StepHomeWifi — Step 2 of onboarding.
///
/// Lets the user provide their home router credentials.
/// The Pi will connect its USB WiFi adapter (wlan1) and verify internet access.
class StepHomeWifi extends StatefulWidget {
  final OnboardingController ctrl;
  const StepHomeWifi({super.key, required this.ctrl});

  @override
  State<StepHomeWifi> createState() => _StepHomeWifiState();
}

class _StepHomeWifiState extends State<StepHomeWifi> {
  final _formKey  = GlobalKey<FormState>();
  final _ssidCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure   = true;

  @override
  void dispose() {
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final blue   = isDark ? const Color(0xFF60A5FA) : Colors.blue.shade600;
    final sub    = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.home_outlined, color: blue, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Connect to Home Wi-Fi',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface)),
                  Text('Step 2 of 3', style: TextStyle(fontSize: 12, color: sub)),
                ],
              )),
            ]),
            const SizedBox(height: 20),

            OnboardingInfoCard(
              icon: Icons.sync_alt,
              color: blue,
              text: 'This connects LettuVault to your home internet so it can '
                    'automatically sync data to the cloud. Make sure the Pi is still powered on.',
            ),
            const SizedBox(height: 24),

            OnboardingFieldLabel('Home Wi-Fi Name (SSID)', color: blue),
            const SizedBox(height: 6),
            OnboardingTextField(
              controller: _ssidCtrl,
              hint: 'e.g. MyHomeWiFi',
              icon: Icons.wifi,
              accentColor: blue,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your Wi-Fi name' : null,
            ),
            const SizedBox(height: 16),

            OnboardingFieldLabel('Home Wi-Fi Password', color: blue),
            const SizedBox(height: 6),
            OnboardingTextField(
              controller: _passCtrl,
              hint: 'Enter password',
              icon: Icons.lock_outline,
              accentColor: blue,
              obscureText: _obscure,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                    color: sub, size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Enter your Wi-Fi password' : null,
            ),

            if (widget.ctrl.loading) ...[
              const SizedBox(height: 16),
              OnboardingInfoCard(
                icon: Icons.hourglass_top,
                color: blue,
                text: 'Connecting LettuVault to your home network and verifying '
                      'internet access. This may take up to 30 seconds.',
              ),
            ],

            if (widget.ctrl.error != null) ...[
              const SizedBox(height: 16),
              OnboardingErrorBox(widget.ctrl.error!),
            ],

            const SizedBox(height: 28),

            OnboardingPrimaryButton(
              label: 'Connect to Home Wi-Fi',
              color: blue,
              icon: Icons.wifi_tethering,
              loading: widget.ctrl.loading,
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                await widget.ctrl.connectPiHomeWifi(
                  ssid: _ssidCtrl.text.trim(),
                  password: _passCtrl.text,
                );
              },
            ),
            const SizedBox(height: 12),

            // Skip button — hidden when kHomeWifiStepEnabled = true (production).
            if (!kHomeWifiStepEnabled)
              Center(
                child: TextButton(
                  onPressed: widget.ctrl.loading ? null : widget.ctrl.skipHomeWifi,
                  child: Text('Skip for now', style: TextStyle(fontSize: 13, color: sub)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

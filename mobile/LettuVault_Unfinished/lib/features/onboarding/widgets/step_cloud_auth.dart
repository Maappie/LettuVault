import 'package:flutter/material.dart';
import 'package:my_new_app/features/onboarding/controllers/onboarding_controller.dart';
import 'package:my_new_app/features/onboarding/widgets/onboarding_widgets.dart';

/// StepCloudAuth — Step 3 of onboarding.
///
/// Sign Up or Sign In via the cloud server.
/// Mandatory when Local Setup was skipped; optional otherwise.
class StepCloudAuth extends StatefulWidget {
  final OnboardingController ctrl;
  final bool mandatory;
  final VoidCallback onComplete;

  const StepCloudAuth({
    super.key,
    required this.ctrl,
    required this.mandatory,
    required this.onComplete,
  });

  @override
  State<StepCloudAuth> createState() => _StepCloudAuthState();
}

class _StepCloudAuthState extends State<StepCloudAuth>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  final _signupFormKey = GlobalKey<FormState>();
  final _loginFormKey  = GlobalKey<FormState>();
  final _signupEmail   = TextEditingController();
  final _signupPass    = TextEditingController();
  final _loginEmail    = TextEditingController();
  final _loginPass     = TextEditingController();
  bool _signupObscure  = true;
  bool _loginObscure   = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _signupEmail.dispose();
    _signupPass.dispose();
    _loginEmail.dispose();
    _loginPass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final purple = isDark ? const Color(0xFFA78BFA) : Colors.deepPurple.shade400;
    final sub    = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // ── Header ───────────────────────────────────────────────────────
          Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.cloud_outlined, color: purple, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Remote Access',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface)),
                Text('Step 3 of 3', style: TextStyle(fontSize: 12, color: sub)),
              ],
            )),
          ]),
          const SizedBox(height: 16),

          widget.mandatory
              ? OnboardingInfoCard(
                  icon: Icons.info_outline,
                  color: Colors.orange,
                  text: 'Since you skipped Local Setup, you can only Sign In to an existing remote account to access your data.',
                )
              : OnboardingInfoCard(
                  icon: Icons.cloud_done_outlined,
                  color: purple,
                  text: 'Create an account to view your data remotely. Keep the Pi turned on and make sure you are connected, your credentials will be saved to it.',
                ),
          const SizedBox(height: 20),

          // ── Tab bar ───────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabs,
              indicator: BoxDecoration(
                color: purple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: purple,
              unselectedLabelColor: sub,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [Tab(text: 'Sign Up'), Tab(text: 'Sign In')],
            ),
          ),
          const SizedBox(height: 24),

          // ── Tab content ───────────────────────────────────────────────────
          SizedBox(
            height: 360,
            child: TabBarView(
              controller: _tabs,
              children: [
                // Sign Up
                widget.mandatory
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'Sign Up is blocked.\nRemote access setup can only be done if the local setup is finished.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      )
                    : _AuthForm(
                        formKey:  _signupFormKey,
                        emailCtrl: _signupEmail,
                        passCtrl:  _signupPass,
                        obscure:   _signupObscure,
                        onToggle:  () => setState(() => _signupObscure = !_signupObscure),
                        accentColor: purple,
                        sub:       sub,
                        loading:   widget.ctrl.loading,
                        error:     widget.ctrl.error,
                        submitLabel: 'Create Account',
                        submitIcon:  Icons.person_add_outlined,
                        passHint:    'Choose a password',
                        passValidator: (v) =>
                            (v == null || v.length < 6) ? 'At least 6 characters' : null,
                        onSubmit: () async {
                          if (!_signupFormKey.currentState!.validate()) return;
                          final ok = await widget.ctrl.signup(
                            email: _signupEmail.text.trim(),
                            password: _signupPass.text,
                          );
                          if (ok && mounted) widget.onComplete();
                        },
                      ),
                // Sign In
                _AuthForm(
                  formKey:  _loginFormKey,
                  emailCtrl: _loginEmail,
                  passCtrl:  _loginPass,
                  obscure:   _loginObscure,
                  onToggle:  () => setState(() => _loginObscure = !_loginObscure),
                  accentColor: purple,
                  sub:       sub,
                  loading:   widget.ctrl.loading,
                  error:     widget.ctrl.error,
                  submitLabel: 'Sign In',
                  submitIcon:  Icons.login,
                  passHint:    'Your password',
                  passValidator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter your password' : null,
                  onSubmit: () async {
                    if (!_loginFormKey.currentState!.validate()) return;
                    final ok = await widget.ctrl.login(
                      email: _loginEmail.text.trim(),
                      password: _loginPass.text,
                    );
                    if (ok && mounted) widget.onComplete();
                  },
                ),
              ],
            ),
          ),

          // ── Skip (optional only) ──────────────────────────────────────────
          if (!widget.mandatory) ...[
            Center(
              child: TextButton(
                onPressed: widget.ctrl.loading ? null : widget.onComplete,
                child: Text('Skip — set up later in Settings',
                    style: TextStyle(fontSize: 13, color: sub)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Auth form (shared for sign-up and sign-in) ────────────────────────────────

class _AuthForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl, passCtrl;
  final bool obscure, loading;
  final String? error;
  final Color accentColor, sub;
  final VoidCallback onToggle, onSubmit;
  final String submitLabel, passHint;
  final IconData submitIcon;
  final String? Function(String?)? passValidator;

  const _AuthForm({
    required this.formKey,
    required this.emailCtrl,
    required this.passCtrl,
    required this.obscure,
    required this.onToggle,
    required this.accentColor,
    required this.sub,
    required this.loading,
    required this.error,
    required this.submitLabel,
    required this.submitIcon,
    required this.passHint,
    required this.passValidator,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OnboardingFieldLabel('Email', color: accentColor),
          const SizedBox(height: 6),
          OnboardingTextField(
            controller: emailCtrl,
            hint: 'your@email.com',
            icon: Icons.email_outlined,
            accentColor: accentColor,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || !v.contains('@'))
                ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 14),
          OnboardingFieldLabel('Password', color: accentColor),
          const SizedBox(height: 6),
          OnboardingTextField(
            controller: passCtrl,
            hint: passHint,
            icon: Icons.lock_outline,
            accentColor: accentColor,
            obscureText: obscure,
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
                  color: sub, size: 20),
              onPressed: onToggle,
            ),
            validator: passValidator,
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            OnboardingErrorBox(error!),
          ],
          const SizedBox(height: 20),
          OnboardingPrimaryButton(
            label: submitLabel,
            color: accentColor,
            icon: submitIcon,
            loading: loading,
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }
}

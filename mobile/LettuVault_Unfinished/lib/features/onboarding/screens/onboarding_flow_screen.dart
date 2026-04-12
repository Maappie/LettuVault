import 'package:flutter/material.dart';
import 'package:my_new_app/features/onboarding/controllers/onboarding_controller.dart';
import 'package:my_new_app/features/onboarding/widgets/step_local_setup.dart';
import 'package:my_new_app/features/onboarding/widgets/step_home_wifi.dart';
import 'package:my_new_app/features/onboarding/widgets/step_cloud_auth.dart';
import 'package:my_new_app/src/core/secure_storage.dart';

/// OnboardingFlowScreen — top-level 3-step wizard shown on first launch.
///
/// Controls which step widget is visible and drives [OnboardingController].
/// Calls [onComplete] when the user finishes or skips all steps.
class OnboardingFlowScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingFlowScreen({super.key, required this.onComplete});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  final _ctrl = OnboardingController.instance;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_rebuild);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  Future<void> _finish() async {
    await SecureStorage.markOnboardingDone();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF090E12) : const Color(0xFFF4F6FA);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _ctrl.step != OnboardingStep.localSetup
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
                onPressed: _ctrl.loading ? null : _ctrl.goBack,
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Step progress indicator ──────────────────────────────────
            _StepProgressBar(currentStep: _ctrl.step),

            // ── Step content ─────────────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: _buildStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_ctrl.step) {
      case OnboardingStep.localSetup:
        return StepLocalSetup(key: const ValueKey('local'), ctrl: _ctrl);

      case OnboardingStep.homeWifi:
        return StepHomeWifi(key: const ValueKey('wifi'), ctrl: _ctrl);

      case OnboardingStep.cloudAuth:
        return StepCloudAuth(
          key: const ValueKey('auth'),
          ctrl: _ctrl,
          mandatory: _ctrl.localSetupSkipped,
          onComplete: _finish,
        );
    }
  }
}

// ── Step progress bar ─────────────────────────────────────────────────────────

class _StepProgressBar extends StatelessWidget {
  final OnboardingStep currentStep;
  const _StepProgressBar({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final steps = [
      (icon: Icons.wifi_find,      label: 'Local',  step: OnboardingStep.localSetup),
      (icon: Icons.home_outlined,  label: 'Home Wi-Fi', step: OnboardingStep.homeWifi),
      (icon: Icons.cloud_outlined, label: 'Account', step: OnboardingStep.cloudAuth),
    ];

    final colors = [
      isDark ? const Color(0xFF4ADE80) : Colors.green.shade600,
      isDark ? const Color(0xFF60A5FA) : Colors.blue.shade600,
      isDark ? const Color(0xFFA78BFA) : Colors.deepPurple.shade400,
    ];

    final idx = OnboardingStep.values.indexOf(currentStep);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            // ── Connector line ────────────────────────────────────────────
            final lineIdx = i ~/ 2;
            final done    = lineIdx < idx;
            return Expanded(
              child: Container(
                height: 2,
                color: done
                    ? colors[lineIdx].withValues(alpha: 0.6)
                    : (isDark ? Colors.white12 : Colors.black12),
              ),
            );
          }
          // ── Step dot ──────────────────────────────────────────────────
          final si      = i ~/ 2;
          final isDone  = si < idx;
          final isActive = si == idx;
          final color   = colors[si];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width:  isActive ? 38 : 30,
                height: isActive ? 38 : 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? color : (isDone ? color.withValues(alpha: 0.3) : Colors.transparent),
                  border: Border.all(
                    color: isActive || isDone ? color : (isDark ? Colors.white24 : Colors.black26),
                    width: isActive ? 2.5 : 1.5,
                  ),
                ),
                child: Icon(
                  isDone ? Icons.check : steps[si].icon,
                  size: isActive ? 18 : 14,
                  color: isActive
                      ? Colors.white
                      : (isDone ? color : (isDark ? Colors.white38 : Colors.black38)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[si].label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? color : (isDark ? Colors.white38 : Colors.black38),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

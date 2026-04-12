import 'dart:math';
import 'package:flutter/material.dart';

/// Animated splash/loading screen shown during app startup.
///
/// Replaces the old static loading screen with a premium orbiting
/// animation around the LettuVault logo.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _rotation = Tween<double>(begin: 0, end: 2 * pi).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A150C),
      child: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Orbiting ring around logo ─────────────────────────────
                SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer rotating dashed ring with glowing dot
                      Transform.rotate(
                        angle: _rotation.value,
                        child: CustomPaint(
                          size: const Size(160, 160),
                          painter: _OrbitPainter(),
                        ),
                      ),
                      // Inner glow circle
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0D2010),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4ADE80).withValues(alpha: 0.3),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                      ),
                      // Logo
                      ClipOval(
                        child: Image.asset(
                          'assets/lettuvault_icon.png',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.eco,
                            color: Color(0xFF4ADE80),
                            size: 48,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // ── App name ──────────────────────────────────────────────
                const Text(
                  'LettuVault',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4ADE80),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Smart Postharvest Storage System',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.5),
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 48),

                // ── Loading dots ──────────────────────────────────────────
                _LoadingDots(controller: _ctrl),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Orbit ring painter ─────────────────────────────────────────────────────────
class _OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Dashed ring
    final ringPaint = Paint()
      ..color = const Color(0xFF4ADE80).withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, radius, ringPaint);

    // Glowing leading dot at top of ring
    final dotPaint = Paint()
      ..color = const Color(0xFF4ADE80)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(center.dx, center.dy - radius), 7, dotPaint);

    // Solid dot on top
    final solidDot = Paint()..color = const Color(0xFF4ADE80);
    canvas.drawCircle(Offset(center.dx, center.dy - radius), 4, solidDot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Bouncing dots indicator ────────────────────────────────────────────────────
class _LoadingDots extends StatelessWidget {
  final AnimationController controller;
  const _LoadingDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (controller.value + i * 0.25) % 1.0;
            final opacity = (sin(phase * 2 * pi) * 0.5 + 0.5).clamp(0.2, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4ADE80).withValues(alpha: opacity),
              ),
            );
          }),
        );
      },
    );
  }
}

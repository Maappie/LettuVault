import 'dart:math';
import 'package:flutter/material.dart';
import '../widgets/helpers.dart';

class HomeScreen extends StatelessWidget {
  final double t, h, p;
  final double targetT, targetH, targetP;
  final double trendT, trendH, trendP;
  final double tempDanger, humDanger, presDanger;
  final String? apiError;
  final bool apiPolling;

  const HomeScreen({
    super.key,
    required this.t,
    required this.h,
    required this.p,
    required this.targetT,
    required this.targetH,
    required this.targetP,
    this.trendT = 0.0,
    this.trendH = 0.0,
    this.trendP = 0.0,
    this.tempDanger = 0.0,
    this.humDanger = 0.0,
    this.presDanger = 0.0,
    this.apiError,
    this.apiPolling = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        buildTopBar(context, "Dashboard"),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              // API connection status banner
              if (apiError != null)
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('Connection Error', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                        content: SingleChildScrollView(
                          child: SelectableText(
                            apiError!,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.cloud_off, color: Colors.redAccent, size: 18),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                "Backend unreachable — tap for details",
                                style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.redAccent, size: 16),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          apiError!.length > 120 ? '${apiError!.substring(0, 120)}…' : apiError!,
                          style: TextStyle(
                            color: Colors.redAccent.withValues(alpha: 0.8),
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (apiPolling && apiError == null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_done, color: Colors.green, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Live — connected to backend",
                          style: TextStyle(color: Colors.green.withValues(alpha: 0.9), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              buildSectionHeader("ENVIRONMENTAL DATA"),
              _buildLargeCard(
                context,
                "Temperature: ${t.toStringAsFixed(1)}°C",
                "Target: ${targetT.toStringAsFixed(1)}°C",
                dangerLevel: tempDanger,
                trend: trendT,
              ),
              _buildLargeCard(
                context,
                "Humidity: ${h.toStringAsFixed(0)}%",
                "Target: ${targetH.toStringAsFixed(0)}%",
                dangerLevel: humDanger,
                trend: trendH,
              ),
              _buildLargeCard(
                context,
                "Pressure: ${p.toStringAsFixed(1)} hPa",
                "Target: ${targetP.toStringAsFixed(1)} hPa",
                dangerLevel: presDanger,
                trend: trendP,
              ),

              buildSectionHeader("LIVE CAMERA"),
              _buildCameraCard(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLargeCard(BuildContext context, String t1, String t2, {double dangerLevel = 0.0, double? trend}) => AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: dangerLevel > 0.0
              ? Color.lerp(Theme.of(context).cardColor, Colors.red.withValues(alpha: 0.15), dangerLevel)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(30),
          boxShadow: dangerLevel > 0.0
              ? [BoxShadow(color: Colors.red.withValues(alpha: 0.15 * dangerLevel), blurRadius: 6 + (12 * dangerLevel), spreadRadius: 2 * dangerLevel)]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
          border: dangerLevel > 0.0 ? Border.all(color: Colors.redAccent.withValues(alpha: 0.4 * dangerLevel)) : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t1, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 6),
                  Text(t2, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                ],
              ),
            ),

            if (trend != null)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 420),
                transitionBuilder: (child, anim) {
                  final offset = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(anim);
                  return SlideTransition(position: offset, child: FadeTransition(opacity: anim, child: child));
                },
                child: Container(
                  key: ValueKey<String>(trend.toStringAsFixed(2)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.difference_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 6),
                      // numeric delta
                      Text(
                        '${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(1)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _buildCameraCard(BuildContext context) => Container(
        height: min(200, MediaQuery.of(context).size.height * 0.25),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: Text(
            "Live Stream Simulation",
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
        ),
      );
}

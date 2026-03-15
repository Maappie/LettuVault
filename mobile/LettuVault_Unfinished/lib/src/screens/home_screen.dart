import 'dart:math';
import 'package:flutter/material.dart';
import '../widgets/helpers.dart';

class HomeScreen extends StatelessWidget {
  final double t, h, p, at, ah, ap;
  final double vpd;
  final double trendT, trendH, trendP;
  final bool isTempCritical, isHumCritical, isPresCritical;

  const HomeScreen({
    super.key,
    required this.t,
    required this.h,
    required this.p,
    required this.at,
    required this.ah,
    required this.ap,
    required this.vpd,
    this.trendT = 0.0,
    this.trendH = 0.0,
    this.trendP = 0.0,
    this.isTempCritical = false,
    this.isHumCritical = false,
    this.isPresCritical = false,
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
              buildSectionHeader("ENVIRONMENTAL DATA"),
              _buildLargeCard(
                context,
                "Temperature: ${t.toStringAsFixed(1)}°C",
                "Avg: ${at.toStringAsFixed(1)}°C",
                highlight: isTempCritical,
                trend: trendT,
              ),
              _buildLargeCard(
                context,
                "Humidity: ${h.toStringAsFixed(0)}%",
                "Avg: ${ah.toStringAsFixed(0)}%",
                highlight: isHumCritical,
                trend: trendH,
              ),
              _buildLargeCard(
                context,
                "Pressure: ${p.toStringAsFixed(1)} hPa",
                "Avg: ${ap.toStringAsFixed(1)} hPa",
                highlight: isPresCritical,
                trend: trendP,
              ),

              // VPD card (moved from DetailScreen)
              _buildLargeCard(
                context,
                "VPD: ${vpd.toStringAsFixed(3)} kPa",
                "Vapor Pressure Deficit",
              ),

              buildSectionHeader("LIVE CAMERA"),
              _buildCameraCard(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLargeCard(BuildContext context, String t1, String t2, {bool highlight = false, double? trend}) => AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: highlight ? Colors.red.withOpacity(0.06) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(30),
          boxShadow: highlight
              ? [BoxShadow(color: Colors.red.withOpacity(0.08), blurRadius: 18, spreadRadius: 2)]
              : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
          border: highlight ? Border.all(color: Colors.redAccent.withOpacity(0.25)) : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t1, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 6),
                  Text(t2, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
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
                    color: trend >= 0 ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFE6E9EE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // icon with small pop
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.9, end: 1.0),
                        duration: const Duration(milliseconds: 420),
                        builder: (context, scale, child) => Transform.scale(
                          scale: scale,
                          child: Icon(
                            trend >= 0 ? Icons.trending_up : Icons.trending_down,
                            size: 16,
                            color: trend >= 0 ? Colors.greenAccent : Colors.redAccent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // numeric count-up animation
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: trend),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (context, val, _) => Text(
                          '${val >= 0 ? '+' : ''}${val.toStringAsFixed(1)}',
                          style: TextStyle(
                            color: trend >= 0 ? Colors.greenAccent : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
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
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
          ),
        ),
      );
}

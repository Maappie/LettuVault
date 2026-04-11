import 'package:flutter/material.dart';

/// SensorSummaryCard — animated card showing a sensor value vs. its target.
///
/// The card background color and glow lerp from neutral → red based on [dangerLevel].
/// A trend delta badge appears on the right when [trend] is provided.
class SensorSummaryCard extends StatelessWidget {
  final String valueLabel;
  final String targetLabel;
  final double dangerLevel;
  final double? trend;

  const SensorSummaryCard({
    super.key,
    required this.valueLabel,
    required this.targetLabel,
    this.dangerLevel = 0.0,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = dangerLevel > 0.0
        ? Color.lerp(
            Theme.of(context).cardColor,
            Colors.red.withValues(alpha: 0.15),
            dangerLevel,
          )
        : Theme.of(context).cardColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: dangerLevel > 0.0
            ? [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.15 * dangerLevel),
                  blurRadius: 6 + (12 * dangerLevel),
                  spreadRadius: 2 * dangerLevel,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                ),
              ],
        border: dangerLevel > 0.0
            ? Border.all(
                color: Colors.redAccent.withValues(alpha: 0.4 * dangerLevel),
              )
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valueLabel,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  targetLabel,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          if (trend != null) _TrendBadge(trend: trend!),
        ],
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  final double trend;
  const _TrendBadge({required this.trend});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      transitionBuilder: (child, anim) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.15), end: Offset.zero,
        ).animate(anim);
        return SlideTransition(
          position: offset,
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      child: Container(
        key: ValueKey<String>(trend.toStringAsFixed(2)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
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
    );
  }
}

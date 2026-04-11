import 'package:flutter/material.dart';

import 'package:my_new_app/shared/widgets/metric_card.dart';
import 'package:my_new_app/src/models/sensor_reading.dart';

/// MetricRow — shows the Target / Avg / Trend metric cards side-by-side.
///
/// All three slots are [Flexible] so they shrink gracefully on small screens.
class MetricRow extends StatelessWidget {
  final double target, avg, current;
  final String unit;
  final List<SensorReading> buffer;

  const MetricRow({
    super.key,
    required this.target,
    required this.avg,
    required this.current,
    required this.unit,
    required this.buffer,
  });

  @override
  Widget build(BuildContext context) {
    final double trend =
        buffer.isNotEmpty ? current - buffer.first.value : 0.0;
    final Color trendColor =
        trend >= 0 ? Colors.greenAccent : Colors.redAccent;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MetricCard(
                label: 'Config',
                value: target,
                unit: unit,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(height: 4),
              Text(
                'Target',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MetricCard(
                label: 'Avg',
                value: avg,
                unit: unit,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(height: 4),
              Text(
                'Rolling',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MetricCard(
                label: 'Trend',
                value: trend,
                unit: unit,
                color: trendColor,
              ),
              const SizedBox(height: 4),
              Text(
                'Change',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

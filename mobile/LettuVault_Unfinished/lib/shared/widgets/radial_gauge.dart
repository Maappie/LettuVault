import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

/// RadialGauge — Syncfusion radial gauge with green/orange/red zones.
///
/// Parameters:
///   [value]    — Current reading
///   [min]/[max]— Axis extents
///   [greenLow]/[greenHigh] — Safe zone boundaries (±tolerance from target)
///   [redLow]/[redHigh]     — Alert boundary (outside → red zone)
///   [unit]     — Display unit string (e.g. '°C', '%', 'hPa')
///   [size]     — Widget size (width == height)
class RadialGauge extends StatelessWidget {
  final double value;
  final double min, max;
  final double greenLow, greenHigh;
  final double redLow, redHigh;
  final String unit;
  final double size;

  const RadialGauge({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.greenLow,
    required this.greenHigh,
    required this.redLow,
    required this.redHigh,
    this.unit = '',
    this.size = 170,
  });

  @override
  Widget build(BuildContext context) {
    final theme      = Theme.of(context);
    final cardBg     = theme.cardColor;
    final labelColor = theme.colorScheme.onSurface.withValues(alpha: 0.7);
    final clampedV   = value.clamp(min, max);
    final isAlert    = value < redLow || value > redHigh;
    final valueColor = isAlert ? Colors.redAccent : theme.colorScheme.onSurface;

    // Clamp all zone boundaries to the axis
    final rLow  = redLow.clamp(min, max);
    final gLow  = greenLow.clamp(min, max);
    final gHigh = greenHigh.clamp(min, max);
    final rHigh = redHigh.clamp(min, max);

    return SizedBox(
      width: size,
      height: size,
      child: SfRadialGauge(
        axes: <RadialAxis>[
          RadialAxis(
            minimum: min,
            maximum: max,
            interval: (max - min) > 100 ? 50.0 : 10.0,
            startAngle: 140,
            endAngle: 40,
            showLabels: true,
            showLastLabel: true,
            showTicks: true,
            onLabelCreated: (args) {
              args.text = double.parse(args.text).toInt().toString();
            },
            axisLabelStyle: GaugeTextStyle(fontSize: 10, color: labelColor),
            axisLineStyle: AxisLineStyle(
              thickness: 0.2,
              thicknessUnit: GaugeSizeUnit.factor,
              color: theme.brightness == Brightness.dark
                  ? Colors.white10
                  : const Color(0xFFF1F5F9),
            ),
            ranges: <GaugeRange>[
              GaugeRange(startValue: min,   endValue: rLow,  color: Colors.red.withValues(alpha: 0.85),    startWidth: 0.2, endWidth: 0.2, sizeUnit: GaugeSizeUnit.factor),
              GaugeRange(startValue: rLow,  endValue: gLow,  color: Colors.orange.withValues(alpha: 0.8),  startWidth: 0.2, endWidth: 0.2, sizeUnit: GaugeSizeUnit.factor),
              GaugeRange(startValue: gLow,  endValue: gHigh, color: Colors.green.withValues(alpha: 0.85),  startWidth: 0.2, endWidth: 0.2, sizeUnit: GaugeSizeUnit.factor),
              GaugeRange(startValue: gHigh, endValue: rHigh, color: Colors.orange.withValues(alpha: 0.8),  startWidth: 0.2, endWidth: 0.2, sizeUnit: GaugeSizeUnit.factor),
              GaugeRange(startValue: rHigh, endValue: max,   color: Colors.red.withValues(alpha: 0.85),    startWidth: 0.2, endWidth: 0.2, sizeUnit: GaugeSizeUnit.factor),
            ],
            pointers: <GaugePointer>[
              NeedlePointer(
                value: clampedV,
                needleLength: 0.65,
                needleColor: theme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
                knobStyle: KnobStyle(
                  knobRadius: 0.07,
                  color: theme.brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                ),
                enableAnimation: true,
                animationDuration: 1100,
                animationType: AnimationType.easeOutBack,
              ),
            ],
            annotations: <GaugeAnnotation>[
              GaugeAnnotation(
                positionFactor: 0.8,
                angle: 90,
                widget: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isAlert
                          ? Colors.redAccent.withValues(alpha: 0.5)
                          : (theme.brightness == Brightness.dark
                              ? Colors.white10
                              : const Color(0xFFE6E9EE)),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'LIVE READING',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: labelColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '${value.toInt()}$unit',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: valueColor,
                        ),
                      ),
                      if (isAlert)
                        const Text(
                          'CRITICAL',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

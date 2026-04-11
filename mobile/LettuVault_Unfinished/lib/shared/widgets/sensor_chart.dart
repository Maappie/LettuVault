import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:my_new_app/src/models/sensor_reading.dart';

/// SensorChart — fl_chart line chart for sensor history.
///
/// Shows "Initializing Data..." if [buffer] is empty.
/// Supports a configurable [height] for responsive layouts.
class SensorChart extends StatelessWidget {
  final List<SensorReading> buffer;
  final Color color;
  final String unit;
  final String title;
  final double? height;

  const SensorChart({
    super.key,
    required this.buffer,
    required this.color,
    required this.unit,
    this.title = '',
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme         = Theme.of(context);
    final textPrimary   = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurface.withOpacity(0.7);
    final cardBg        = theme.cardColor;

    if (buffer.isEmpty) {
      return Container(
        height: height ?? 220,
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            'Initializing Data...',
            style: TextStyle(color: textSecondary),
          ),
        ),
      );
    }

    final count = buffer.length;
    final maxX  = count > 1 ? (count - 1).toDouble() : 4.0;
    final minY  = (buffer.map((e) => e.value).reduce(min) - 2).floorToDouble();
    final maxY  = (buffer.map((e) => e.value).reduce(max) + 5).ceilToDouble();

    int labelInterval = 1;
    if (count > 20) labelInterval = (count / 6).ceil();
    else if (count > 8) labelInterval = 2;

    return Container(
      height: height ?? 360,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.fromLTRB(10, 14, 20, 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: LineChart(
        LineChartData(
          minX: 0, maxX: maxX, minY: minY, maxY: maxY,
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:   AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              axisNameWidget: Text(
                'Time',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: labelInterval.toDouble(),
                getTitlesWidget: (v, m) {
                  final i = v.round();
                  if (i < 0 || i >= buffer.length) return const Text('');
                  return Text(
                    DateFormat('HH:mm').format(buffer[i].time),
                    style: TextStyle(fontSize: 10, color: textPrimary),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: Text(
                unit,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textSecondary),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                interval: (maxY - minY) / 4,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(1),
                  style: TextStyle(fontSize: 10, color: textPrimary),
                ),
              ),
            ),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                final idx = s.x.toInt();
                if (idx < 0 || idx >= buffer.length) return null;
                final r = buffer[idx];
                return LineTooltipItem(
                  '${DateFormat('HH:mm:ss').format(r.time)}\n${r.value.toStringAsFixed(2)} $unit',
                  TextStyle(
                    color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).whereType<LineTooltipItem>().toList(),
            ),
            handleBuiltInTouches: true,
          ),
          lineBarsData: [
            LineChartBarData(
              spots: buffer.asMap().entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value.value))
                  .toList(),
              isCurved: true,
              color: color,
              barWidth: 3,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.45), color.withValues(alpha: 0.05)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

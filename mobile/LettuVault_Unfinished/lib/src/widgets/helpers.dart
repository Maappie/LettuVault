import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../models/sensor_reading.dart';

// Public helper widgets (renamed from private to allow cross-file use)
Widget buildTopBar(BuildContext context, String t) => Container(
      padding: const EdgeInsets.only(top: 50, left: 10, right: 20, bottom: 20),
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.menu_rounded, color: Theme.of(context).colorScheme.onSurface, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
          Expanded(
            child: Text(
              t,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          // Spacer to keep title centered (matches IconButton width)
          const SizedBox(width: 48),
        ],
      ),
    );


// greenLow/greenHigh: the inner ±tolerance safe zone boundary
// redLow/redHigh: the outer alert threshold boundary (orange is between these and green)
Widget buildRadial(BuildContext context, double v, double min, double max,
    double greenLow, double greenHigh, double redLow, double redHigh,
    {String unit = '', double size = 170}) {
  final double clampedV = v.clamp(min, max);
  final bool isAlert = v < redLow || v > redHigh;

  final theme = Theme.of(context);
  final cardBg = theme.cardColor;
  final labelColor = theme.colorScheme.onSurface.withOpacity(0.7);
  final valueColor = isAlert ? Colors.redAccent : theme.colorScheme.onSurface;

  // Clamp all boundaries to the axis [min, max]
  final double rLow  = redLow.clamp(min, max);
  final double gLow  = greenLow.clamp(min, max);
  final double gHigh = greenHigh.clamp(min, max);
  final double rHigh = redHigh.clamp(min, max);

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
          onLabelCreated: (AxisLabelCreatedArgs args) {
            args.text = double.parse(args.text).toInt().toString();
          },
          axisLabelStyle: GaugeTextStyle(fontSize: 10, color: labelColor),
          axisLineStyle: AxisLineStyle(
            thickness: 0.2,
            thicknessUnit: GaugeSizeUnit.factor,
            color: theme.brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF1F5F9),
          ),
          ranges: <GaugeRange>[
            // RED: min → redLow
            GaugeRange(startValue: min, endValue: rLow,
                color: Colors.red.withOpacity(0.85),
                startWidth: 0.2, endWidth: 0.2, sizeUnit: GaugeSizeUnit.factor),
            // ORANGE: redLow → greenLow
            GaugeRange(startValue: rLow, endValue: gLow,
                color: Colors.orange.withOpacity(0.8),
                startWidth: 0.2, endWidth: 0.2, sizeUnit: GaugeSizeUnit.factor),
            // GREEN: greenLow → greenHigh
            GaugeRange(startValue: gLow, endValue: gHigh,
                color: Colors.green.withOpacity(0.85),
                startWidth: 0.2, endWidth: 0.2, sizeUnit: GaugeSizeUnit.factor),
            // ORANGE: greenHigh → redHigh
            GaugeRange(startValue: gHigh, endValue: rHigh,
                color: Colors.orange.withOpacity(0.8),
                startWidth: 0.2, endWidth: 0.2, sizeUnit: GaugeSizeUnit.factor),
            // RED: redHigh → max
            GaugeRange(startValue: rHigh, endValue: max,
                color: Colors.red.withOpacity(0.85),
                startWidth: 0.2, endWidth: 0.2, sizeUnit: GaugeSizeUnit.factor),
          ],

          pointers: <GaugePointer>[
            NeedlePointer(
              value: clampedV,
              needleLength: 0.65,
              needleColor: theme.brightness == Brightness.dark ? Colors.white : Colors.black87,
              knobStyle: KnobStyle(
                knobRadius: 0.07,
                color: theme.brightness == Brightness.dark ? Colors.white : Colors.black87,
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
                color: isAlert ? Colors.redAccent.withOpacity(0.5) : (theme.brightness == Brightness.dark ? Colors.white10 : const Color(0xFFE6E9EE)),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
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
                  '${v.toInt()}$unit',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
                ),
                if (isAlert)
                  const Text(
                    "CRITICAL",
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

Widget buildChart(BuildContext context,
  List<SensorReading> buf,
  Color col,
  String unit, {
  String title = "Temperature",
  double? height,
}) {
  final theme = Theme.of(context);
  final textPrimary = theme.colorScheme.onSurface;
  final textSecondary = theme.colorScheme.onSurface.withOpacity(0.7);
  final cardBg = theme.cardColor;

  // Return a card with a responsive/default height so the parent can scroll
  if (buf.isEmpty) {
    return Container(
      height: height ?? 220,
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(child: Text("Initializing Data...", style: TextStyle(color: textSecondary))),
    );
  } else {
    final int count = buf.length;
    final double maxX = count > 1 ? (count - 1).toDouble() : 4.0;
    final double minY = (buf.map((e) => e.value).reduce(min) - 2).floorToDouble();
    final double maxY = (buf.map((e) => e.value).reduce(max) + 5).ceilToDouble();

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
          minX: 0,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              axisNameWidget: Text(
                "Time",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: textSecondary,
                ),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: labelInterval.toDouble(),
                getTitlesWidget: (v, m) {
                  final int i = v.round();
                  if (i < 0 || i >= buf.length) return const Text("");
                  final ts = DateFormat('HH:mm').format(buf[i].time);
                  return Text(ts, style: TextStyle(fontSize: 10, color: textPrimary));
                },
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: Text(
                unit,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: textSecondary,
                ),
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
              getTooltipItems: (spots) {
                return spots.map((s) {
                  final idx = s.x.toInt();
                  if (idx < 0 || idx >= buf.length) return null;
                  final reading = buf[idx];
                  final time = DateFormat('HH:mm:ss').format(reading.time);
                  return LineTooltipItem(
                    '$time\n${reading.value.toStringAsFixed(2)} $unit',
                    TextStyle(color: theme.brightness == Brightness.dark ? Colors.white : Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                  );
                }).whereType<LineTooltipItem>().toList();
              },
            ),
            handleBuiltInTouches: true,
          ),
          lineBarsData: [
            LineChartBarData(
              spots: buf.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
              isCurved: true,
              color: col,
              barWidth: 3,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [col.withValues(alpha: 0.45), col.withValues(alpha: 0.05)],
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

Widget buildPill(BuildContext context, String m, Color c) => AnimatedContainer(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.all(15),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(50),
        boxShadow: m == 'CRITICAL'
            ? [BoxShadow(color: c.withOpacity(0.12), blurRadius: 12, spreadRadius: 1)]
            : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        border: m == 'CRITICAL' ? Border.all(color: c.withOpacity(0.25), width: 1.0) : null,
      ),
      child: Center(
        child: Text(m, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.dark ? c : c)),
      ),
    );

Widget buildMetric(BuildContext context, String l) => ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 56, maxWidth: 120, minHeight: 56, maxHeight: 120),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Center(
          child: Text(
            l,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ),
    );

// keep the helper even if unused
Widget buildMetricBig(BuildContext context, String label, double val, String unit, Color color) => ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 80, maxWidth: 160, minHeight: 80, maxHeight: 160),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('${val.toStringAsFixed(1)}$unit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ),
          ],
        ),
      ),
    );


// Simple app startup loading screen shown while the app performs async initialization.
Widget buildLoadingScreen(BuildContext context, {String message = 'Starting LettuVault...'}) {
  final theme = Theme.of(context);
  return Container(
    color: theme.scaffoldBackgroundColor,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: theme.cardColor,
            backgroundImage: const AssetImage('assets/profile.jpg'),
          ),
          const SizedBox(height: 16),
          Text(
            'LettuVault',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7))),
          const SizedBox(height: 18),
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary)),
        ],
      ),
    ),
  );
}

void showAppAboutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("About LettuVault"),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Ensures the dialog isn't taller than needed
          children: [
            const Text(
              "LettuVault v1.1.5",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              "A real-time sensor monitoring app for greenhouse and agricultural environments.",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              "Features:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 8.0, top: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("• Real-time Sensor Monitoring"),
                  Text("• Customizable Alert Thresholds"),
                  Text("• Live Timeline Charts"),
                  Text("• CSV Data Logging"),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(),
            ),
            const Text(
              "The Team:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            buildTeamMember("Banate, Jeraldine", "AI Training"),
            buildTeamMember("Cariazo, Vaan Meyvn", "UI/UX"),
            buildTeamMember("Malidas, Hasnayrah", "UI/UX"),
            buildTeamMember("Mapa, Renz Daneco", "Backend Logic"),
            buildTeamMember("Mortera, Rhiza Rhean", "AI Training"),
            const SizedBox(height: 16),
            const Text(
              "Made for precision agriculture.",
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Close"),
        ),
      ],
    ),
  );
}

Widget buildTeamMember(String name, String role) {
  return Padding(
    padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
    child: Text(
      "$name — $role",
      style: const TextStyle(fontSize: 13),
    ),
  );
}

Widget buildSectionHeader(String title) => Padding(
      padding: const EdgeInsets.only(top: 10, left: 20, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blueAccent,
        ),
      ),
    );

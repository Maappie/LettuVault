import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/sensor_reading.dart';
import '../widgets/helpers.dart';

enum ChartMode { live, short, log }

class DetailScreen extends StatefulWidget {
  final String title, unit;
  final double val, avg;
  final double lowerThreshold, upperThreshold;
  final List<SensorReading> buffer;
  final List<SensorReading>? historyBuffer;
  final Color color;
  final bool isLowCrit;

  const DetailScreen({
    super.key,
    required this.title,
    required this.val,
    required this.avg,
    required this.buffer,
    this.historyBuffer,
    required this.unit,
    required this.color,
    required this.lowerThreshold,
    required this.upperThreshold,
    this.isLowCrit = false,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  ChartMode _mode = ChartMode.live;
  List<SensorReading> _logBuffer = [];
  bool _loadingLog = false;

  Future<void> _loadLogs() async {
    setState(() => _loadingLog = true);
    try {
      Directory? dir;
      try {
        dir = await getExternalStorageDirectory();
      } catch (_) {
        dir = await getApplicationDocumentsDirectory();
      }
      if (dir == null) throw Exception('Storage unavailable');
      final file = File('${dir.path}/sensor_log.csv');
      if (!await file.exists()) {
        setState(() {
          _logBuffer = [];
          _loadingLog = false;
        });
        return;
      }

      final lines = await file.readAsLines();
      final List<SensorReading> parsed = [];
      for (final line in lines) {
        final parts = line.split(',');
        if (parts.length < 3) continue;
        final ts = parts[0].trim();
        final sensor = parts[1].trim();
        final value = double.tryParse(parts[2].trim()) ?? double.nan;
        if (sensor.toLowerCase() != widget.title.toLowerCase()) continue;
        try {
          final dt = DateFormat('yyyy-MM-dd HH:mm:ss').parse(ts);
          parsed.add(SensorReading(value, dt));
        } catch (_) {}
      }

      setState(() {
        _logBuffer = parsed.length > 30 ? parsed.sublist(parsed.length - 30) : parsed;
        _loadingLog = false;
      });
    } catch (e) {
      debugPrint('Log read error: $e');
      setState(() => _loadingLog = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isCrit = widget.val < widget.lowerThreshold || widget.val > widget.upperThreshold;
    // final double trend = widget.buffer.isNotEmpty ? widget.val - widget.buffer.first.value : 0.0;

    double minVal, maxVal;
    if (widget.buffer.isNotEmpty) {
      final values = widget.buffer.map((e) => e.value).toList()..add(widget.val);
      double minV = min(values.reduce(min), widget.lowerThreshold);
      double maxV = max(values.reduce(max), widget.upperThreshold);

      final double span = (maxV - minV).abs();
      double pad = span * 0.3;
      if (pad == 0.0) pad = widget.title == "Pressure" ? 10.0 : 5.0;

      minVal = minV - pad;
      maxVal = maxV + pad;
      if (widget.title == "Pressure") {
        minVal = minVal.clamp(800.0, 2000.0);
        maxVal = maxVal.clamp(900.0, 2000.0);
      }
    } else {
      minVal = widget.title == "Pressure" ? 900.0 : 0.0;
      maxVal = widget.title == "Pressure" ? 1100.0 : 100.0;
    }

    List<SensorReading> chartBuffer;
    switch (_mode) {
      case ChartMode.short:
        chartBuffer = widget.historyBuffer ?? widget.buffer;
        break;
      case ChartMode.log:
        chartBuffer = _logBuffer;
        break;
      default:
        chartBuffer = widget.buffer;
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildTopBar(context, widget.title),
            const SizedBox(height: 8),
            buildPill(context, isCrit ? "CRITICAL" : "STABLE", isCrit ? Colors.red : Colors.green),
            const SizedBox(height: 12),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 6.0),
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFE6E9EE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Builder(builder: (ctx) {
                    final double gaugeSize = min(MediaQuery.of(ctx).size.width * 0.6, 320);
                    return Center(
                      child: buildRadial(
                        context,
                        widget.val,
                        minVal,
                        maxVal,
                        widget.lowerThreshold,
                        widget.upperThreshold,
                        unit: widget.unit,
                        size: gaugeSize,
                      ),
                    );
                  }),

const SizedBox(height: 12),

Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 🚀 Changed to spaceEvenly
  children: [
    // 1. Current Metric
    Flexible( // 🚀 Changed Expanded to Flexible
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildMetricBig(context, "Now", widget.val, widget.unit, Theme.of(context).colorScheme.onSurface),
          const SizedBox(height: 4),
          Text("Live", 
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),

    // 2. Average Metric
    Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildMetricBig(context, "Avg", widget.avg, widget.unit, Theme.of(context).colorScheme.onSurface),
          const SizedBox(height: 4),
          Text("Rolling", 
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),

    // 3. Trend Metric
    Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(builder: (_) {
            final double trend = widget.buffer.isNotEmpty 
                ? widget.val - widget.buffer.first.value 
                : 0.0;
            final Color trendColor = trend >= 0 ? Colors.greenAccent : Colors.redAccent;

            return buildMetricBig(context, "Trend", trend, widget.unit, trendColor);
          }),
          const SizedBox(height: 4),
          Text("Change", 
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  ],
),

                ],
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 6.0, bottom: 8.0),
                  child: Text(
                    "Timeline",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                SegmentedButton<ChartMode>(
                  segments: const [
                    ButtonSegment(value: ChartMode.live, label: Text('Live')),
                    ButtonSegment(value: ChartMode.short, label: Text('Short')),
                    ButtonSegment(value: ChartMode.log, label: Text('Logs')),
                  ],
                  selected: <ChartMode>{_mode},
                  onSelectionChanged: (s) async {
                    setState(() => _mode = s.first);
                    if (_mode == ChartMode.log) await _loadLogs();
                  },
                ),
              ],
            ),

            const SizedBox(height: 8),

            if (_mode == ChartMode.log && _loadingLog)
              Container(
                height: 220,
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(child: CircularProgressIndicator()),
              )
            else if (_mode == ChartMode.log && _logBuffer.isEmpty)
              Container(
                height: 160,
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(child: Text('No logged data for this sensor', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)))),
              )
            else
              // make chart height responsive to available screen height
              buildChart(
                context,
                chartBuffer,
                widget.color,
                widget.unit,
                title: widget.title,
                height: min(420.0, MediaQuery.of(context).size.height * 0.45),
              ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  // // keep the small metric helper for consistency with main UI
  // Widget _buildMetricItem(String label, double value, String unit, Color color, String sub, {bool isTrend = false}) {
  //   return Column(
  //     mainAxisSize: MainAxisSize.min,
  //     children: [
  //       Container(
  //         width: 95,
  //         height: 90,
  //         decoration: BoxDecoration(
  //           color: const Color(0xFF121212),
  //           borderRadius: BorderRadius.circular(18),
  //           border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
  //         ),
  //         child: Column(
  //           mainAxisAlignment: MainAxisAlignment.center,
  //           children: [
  //             Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
  //             const SizedBox(height: 6),
  //             Text(
  //               isTrend 
  //                 ? "${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}$unit"
  //                 : "${value.toStringAsFixed(1)}$unit",
  //               style: TextStyle(
  //                 fontSize: 15, 
  //                 fontWeight: FontWeight.bold, 
  //                 color: color
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //       const SizedBox(height: 8),
  //       Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 11)),
  //     ],
  //   );
  // }
}
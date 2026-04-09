import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/sensor_reading.dart';
import '../widgets/helpers.dart';
import '../core/constants.dart';

enum ChartMode { live, short, log }

class DetailScreen extends StatefulWidget {
  final String title, unit;
  final double val, avg;
  final double lowerThreshold, upperThreshold;
  final List<SensorReading> buffer;
  final List<SensorReading>? historyBuffer;
  final Color color;
  final bool isLowCrit;
  final double target;
  final bool useDefaultThresholds;

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
    required this.target,
    this.isLowCrit = false,
    this.useDefaultThresholds = true,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}


class _DetailScreenState extends State<DetailScreen> {
  ChartMode _mode = ChartMode.live;
  List<SensorReading> _logBuffer = [];
  bool _loadingLog = false;
  // Lazy-load state: byte offset in CSV where the NEXT "load earlier" starts scanning from.
  // -1 means we haven't loaded yet; 0 means we've reached the beginning of the file.
  int _logFileOffset = -1;
  bool _hasMoreLogs = false;
  static const int _kLogChunkSize = 50;

  /// Reads up to [_kLogChunkSize] matching lines from the END of the CSV,
  /// working backwards from [startOffset]. Never loads the full file into RAM.
  Future<List<SensorReading>> _readChunkBackwards(RandomAccessFile raf, int startOffset) async {
    final String sensorKey = widget.title.toLowerCase();
    final List<SensorReading> found = [];
    int pos = startOffset;
    const int bufSize = 8192; // 8 KB read window

    // We accumulate raw bytes coming from the file end, then split by newlines
    final List<int> rawTrail = [];

    while (pos > 0 && found.length < _kLogChunkSize) {
      final int readFrom = (pos - bufSize).clamp(0, pos);
      final int readLen = pos - readFrom;
      await raf.setPosition(readFrom);
      final chunk = await raf.read(readLen);
      // Prepend to our accumulator (we're reading backwards)
      rawTrail.insertAll(0, chunk);
      pos = readFrom;

      // Split currently collected bytes into lines and try to parse
      final String text = String.fromCharCodes(rawTrail);
      final List<String> lines = text.split('\n');

      // The first element may be incomplete (we cut mid-line) — keep it for next iteration
      // unless pos == 0 (beginning of file, no more data above)
      final int start = pos > 0 ? 1 : 0;
      for (int i = lines.length - 1; i >= start; i--) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final parts = line.split(',');
        if (parts.length < 3) continue;
        final String sensor = parts[1].trim().toLowerCase();
        if (sensor != sensorKey) continue;
        try {
          final dt = DateFormat('yyyy-MM-dd HH:mm:ss').parse(parts[0].trim());
          final value = double.tryParse(parts[2].trim());
          if (value != null && !value.isNaN) {
            found.add(SensorReading(value, dt));
            if (found.length >= _kLogChunkSize) break;
          }
        } catch (_) {}
      }
      // Keep the possibly-incomplete leading fragment for next outer iteration
      if (pos > 0 && lines.isNotEmpty) {
        rawTrail.clear();
        rawTrail.addAll(lines[0].codeUnits);
      }
    }
    // found is newest-first (we read backwards), reverse to chronological order
    return found.reversed.toList();
  }

  Future<void> _loadLogs() async {
    setState(() { _loadingLog = true; _logBuffer = []; _logFileOffset = -1; _hasMoreLogs = false; });
    try {
      Directory? dir;
      try { dir = await getExternalStorageDirectory(); } catch (_) {
        dir = await getApplicationDocumentsDirectory();
      }
      if (dir == null) throw Exception('Storage unavailable');
      final file = File('${dir.path}/sensor_log.csv');
      if (!await file.exists()) { setState(() => _loadingLog = false); return; }

      final raf = await file.open();
      final int fileLen = await raf.length();
      final chunk = await _readChunkBackwards(raf, fileLen);
      // Store offset so "load earlier" knows where to continue
      // We approximate: find how far back we went by file position of the oldest record
      // Simpler: use remaining byte estimate — not perfect but works for this scale
      await raf.close();

      setState(() {
        _logBuffer = chunk;
        _logFileOffset = fileLen; // will be refined per-load below
        _hasMoreLogs = chunk.length >= _kLogChunkSize;
        _loadingLog = false;
      });
    } catch (e) {
      debugPrint('Log read error: $e');
      setState(() => _loadingLog = false);
    }
  }

  Future<void> _loadMoreLogs() async {
    if (_loadingLog || !_hasMoreLogs || _logFileOffset <= 0) return;
    setState(() => _loadingLog = true);
    try {
      Directory? dir;
      try { dir = await getExternalStorageDirectory(); } catch (_) {
        dir = await getApplicationDocumentsDirectory();
      }
      if (dir == null) throw Exception('Storage unavailable');
      final file = File('${dir.path}/sensor_log.csv');
      if (!await file.exists()) { setState(() => _loadingLog = false); return; }

      // Estimate byte offset: subtract average line size * chunk size as a heuristic
      // Each CSV line ≈ 40 bytes; go back _kLogChunkSize * 2 * 40 bytes from last oldest record
      final raf = await file.open();
      final int newOffset = (_logFileOffset - (_kLogChunkSize * 80)).clamp(0, _logFileOffset);
      final chunk = await _readChunkBackwards(raf, newOffset);
      await raf.close();

      setState(() {
        // Prepend older records; deduplicate by timestamp
        final existing = _logBuffer.map((e) => e.time).toSet();
        final fresh = chunk.where((r) => !existing.contains(r.time)).toList();
        _logBuffer = [...fresh, ..._logBuffer];
        _logFileOffset = newOffset;
        _hasMoreLogs = chunk.length >= _kLogChunkSize && newOffset > 0;
        _loadingLog = false;
      });
    } catch (e) {
      debugPrint('Load more error: $e');
      setState(() => _loadingLog = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    // final double trend = widget.buffer.isNotEmpty ? widget.val - widget.buffer.first.value : 0.0;

    double minVal = 0.0, maxVal = 100.0;
    double tol = 0.0;

    if (widget.title == "Temperature") {
      minVal = 0.0;
      maxVal = 60.0;
      tol = kTempTolerance;
    } else if (widget.title == "Humidity") {
      minVal = 50.0;
      maxVal = 100.0;
      tol = kHumTolerance;
    } else if (widget.title == "Pressure") {
      minVal = 800.0;
      maxVal = 1100.0;
      tol = kPresTolerance;
    }

    // Gauge zone boundaries:
    // Green  = target ± tolerance (always, both modes)
    // Orange = between green edge and the alert threshold boundary (custom or default maxDev)
    // Red    = outside the threshold boundary
    final double greenLow  = widget.target - tol;
    final double greenHigh = widget.target + tol;
    final double redLow;
    final double redHigh;

    if (widget.useDefaultThresholds) {
      // Default: red zone starts at the constants-defined max deviation
      double maxDev;
      if (widget.title == "Temperature") {
        maxDev = kTempMaxDeviation;
      } else if (widget.title == "Humidity") {
        maxDev = kHumMaxDeviation;
      } else {
        maxDev = kPresMaxDeviation;
      }
      redLow  = widget.target - maxDev;
      redHigh = widget.target + maxDev;
    } else {
      // Custom: red zone starts exactly at the user's saved alert thresholds
      redLow  = widget.lowerThreshold;
      redHigh = widget.upperThreshold;
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

    final double bottomPad = MediaQuery.of(context).padding.bottom + 16.0;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(left: 14.0, right: 14.0, top: 8.0, bottom: bottomPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildTopBar(context, widget.title),
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
                    final double screenW = MediaQuery.of(ctx).size.width;
                    final double screenH = MediaQuery.of(ctx).size.height;
                    // Scale gauge size by both width and height to prevent stretching on cramped screens
                    final double gaugeSize = min(screenW * 0.55, min(screenH * 0.35, 320.0));
                    
                    return Center(
                      child: buildRadial(
                        context,
                        widget.val,
                        minVal,
                        maxVal,
                        greenLow,
                        greenHigh,
                        redLow,
                        redHigh,
                        unit: widget.unit,
                        size: gaugeSize,
                      ),
                    );
                  }),

const SizedBox(height: 12),

Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 🚀 Changed to spaceEvenly
  children: [
    // 1. Target (Config) Metric
    Flexible( // 🚀 Changed Expanded to Flexible
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildMetricBig(context, "Config", widget.target, widget.unit, Theme.of(context).colorScheme.onSurface),
          const SizedBox(height: 4),
          Text("Target", 
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 10),
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

            Builder(
              builder: (context) {
                // Ensure the chart's slot never changes height during loading states!
                // This completely prevents the UI from scrolling back to the top.
                final double chartResponsiveHeight = min(420.0, MediaQuery.of(context).size.height * 0.45);

                if (_mode == ChartMode.log && _loadingLog) {
                  return Container(
                    height: chartResponsiveHeight,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  );
                } else if (_mode == ChartMode.log && _logBuffer.isEmpty) {
                  return Container(
                    height: chartResponsiveHeight,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        'No logged data for this sensor',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                      ),
                    ),
                  );
                } else {
                  return buildChart(
                    context,
                    chartBuffer,
                    widget.color,
                    widget.unit,
                    title: widget.title,
                    height: chartResponsiveHeight,
                  );
                }
              },
            ),

            // Load Earlier button — only shown in Logs mode
            if (_mode == ChartMode.log)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: _loadingLog
                      ? const SizedBox(height: 28, width: 28, child: CircularProgressIndicator(strokeWidth: 2))
                      : _hasMoreLogs
                          ? OutlinedButton.icon(
                              icon: const Icon(Icons.history, size: 16),
                              label: const Text('Load Earlier', style: TextStyle(fontSize: 13)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _loadMoreLogs,
                            )
                          : Text(
                              _logBuffer.isEmpty ? '' : 'All records loaded',
                              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                            ),
                ),
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
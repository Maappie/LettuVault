import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'package:my_new_app/src/core/constants.dart';
import 'package:my_new_app/src/models/sensor_reading.dart';
import 'package:my_new_app/shared/widgets/app_top_bar.dart';
import 'package:my_new_app/shared/widgets/radial_gauge.dart';
import 'package:my_new_app/features/detail/widgets/chart_card.dart';
import 'package:my_new_app/features/detail/widgets/metric_row.dart';

/// SensorDetailScreen — full-page view for a single sensor.
///
/// Shows a radial gauge, Target/Avg/Trend row, and a timeline chart
/// with Live / Short / Logs mode. Log pagination is handled internally.
class SensorDetailScreen extends StatefulWidget {
  final String title, unit;
  final double val, avg;
  final double lowerThreshold, upperThreshold;
  final List<SensorReading> buffer;
  final List<SensorReading>? historyBuffer;
  final Color color;
  final bool isLowCrit;
  final double target;
  final bool useDefaultThresholds;

  const SensorDetailScreen({
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
  State<SensorDetailScreen> createState() => _SensorDetailScreenState();
}

class _SensorDetailScreenState extends State<SensorDetailScreen> {
  ChartMode _mode = ChartMode.live;

  // ── Log pagination state ────────────────────────────────────────────
  List<SensorReading> _logBuffer   = [];
  bool _loadingLog    = false;
  int  _logFileOffset = -1;
  bool _hasMoreLogs   = false;
  static const int _kLogChunkSize = 50;

  // ── Log file reading ────────────────────────────────────────────────

  Future<List<SensorReading>> _readChunkBackwards(
      RandomAccessFile raf, int startOffset) async {
    final String sensorKey = widget.title.toLowerCase();
    final List<SensorReading> found = [];
    int pos = startOffset;
    const int bufSize = 8192;
    final List<int> rawTrail = [];

    while (pos > 0 && found.length < _kLogChunkSize) {
      final int readFrom = (pos - bufSize).clamp(0, pos);
      final int readLen  = pos - readFrom;
      await raf.setPosition(readFrom);
      final chunk = await raf.read(readLen);
      rawTrail.insertAll(0, chunk);
      pos = readFrom;

      final String text = String.fromCharCodes(rawTrail);
      final List<String> lines = text.split('\n');

      final int start = pos > 0 ? 1 : 0;
      for (int i = lines.length - 1; i >= start; i--) {
        final line  = lines[i].trim();
        if (line.isEmpty) continue;
        final parts = line.split(',');
        if (parts.length < 3) continue;
        final String sensor = parts[1].trim().toLowerCase();
        if (sensor != sensorKey) continue;
        try {
          final dt    = DateFormat('yyyy-MM-dd HH:mm:ss').parse(parts[0].trim());
          final value = double.tryParse(parts[2].trim());
          if (value != null && !value.isNaN) {
            found.add(SensorReading(value, dt));
            if (found.length >= _kLogChunkSize) break;
          }
        } catch (_) {}
      }
      if (pos > 0 && lines.isNotEmpty) {
        rawTrail.clear();
        rawTrail.addAll(lines[0].codeUnits);
      }
    }
    return found.reversed.toList();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _loadingLog    = true;
      _logBuffer     = [];
      _logFileOffset = -1;
      _hasMoreLogs   = false;
    });
    try {
      Directory? dir;
      try { dir = await getExternalStorageDirectory(); }
      catch (_) { dir = await getApplicationDocumentsDirectory(); }
      if (dir == null) throw Exception('Storage unavailable');

      final file = File('${dir.path}/sensor_log.csv');
      if (!await file.exists()) { setState(() => _loadingLog = false); return; }

      final raf     = await file.open();
      final fileLen = await raf.length();
      final chunk   = await _readChunkBackwards(raf, fileLen);
      await raf.close();

      setState(() {
        _logBuffer     = chunk;
        _logFileOffset = fileLen;
        _hasMoreLogs   = chunk.length >= _kLogChunkSize;
        _loadingLog    = false;
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
      try { dir = await getExternalStorageDirectory(); }
      catch (_) { dir = await getApplicationDocumentsDirectory(); }
      if (dir == null) throw Exception('Storage unavailable');

      final file = File('${dir.path}/sensor_log.csv');
      if (!await file.exists()) { setState(() => _loadingLog = false); return; }

      final raf       = await file.open();
      final newOffset = (_logFileOffset - (_kLogChunkSize * 80)).clamp(0, _logFileOffset);
      final chunk     = await _readChunkBackwards(raf, newOffset);
      await raf.close();

      setState(() {
        final existing = _logBuffer.map((e) => e.time).toSet();
        final fresh    = chunk.where((r) => !existing.contains(r.time)).toList();
        _logBuffer     = [...fresh, ..._logBuffer];
        _logFileOffset = newOffset;
        _hasMoreLogs   = chunk.length >= _kLogChunkSize && newOffset > 0;
        _loadingLog    = false;
      });
    } catch (e) {
      debugPrint('Load more error: $e');
      setState(() => _loadingLog = false);
    }
  }

  // ── Gauge zone helpers ──────────────────────────────────────────────

  _GaugeZones _computeZones() {
    double minVal, maxVal, tol;
    if (widget.title == 'Temperature') {
      minVal = 0; maxVal = 60; tol = kTempTolerance;
    } else if (widget.title == 'Humidity') {
      minVal = 50; maxVal = 100; tol = kHumTolerance;
    } else {
      minVal = 800; maxVal = 1100; tol = kPresTolerance;
    }

    final greenLow  = widget.target - tol;
    final greenHigh = widget.target + tol;
    double redLow, redHigh;

    if (widget.useDefaultThresholds) {
      final maxDev = widget.title == 'Temperature'
          ? kTempMaxDeviation
          : widget.title == 'Humidity'
              ? kHumMaxDeviation
              : kPresMaxDeviation;
      redLow  = widget.target - maxDev;
      redHigh = widget.target + maxDev;
    } else {
      redLow  = widget.lowerThreshold;
      redHigh = widget.upperThreshold;
    }

    return _GaugeZones(
      minVal: minVal, maxVal: maxVal,
      greenLow: greenLow, greenHigh: greenHigh,
      redLow: redLow, redHigh: redHigh,
    );
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final z           = _computeZones();
    final bottomPad   = MediaQuery.of(context).padding.bottom + 16.0;
    final gaugeSize   = min(
      MediaQuery.of(context).size.width * 0.55,
      min(MediaQuery.of(context).size.height * 0.35, 320.0),
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTopBar(title: widget.title),
          Padding(
            padding: EdgeInsets.only(
                left: 14, right: 14, bottom: bottomPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),

                // ── Gauge + metrics card ───────────────────────────────
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(
                      vertical: 18, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white10
                          : const Color(0xFFE6E9EE),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Gauge
                      Center(
                        child: RadialGauge(
                          value:     widget.val,
                          min:       z.minVal,
                          max:       z.maxVal,
                          greenLow:  z.greenLow,
                          greenHigh: z.greenHigh,
                          redLow:    z.redLow,
                          redHigh:   z.redHigh,
                          unit:      widget.unit,
                          size:      gaugeSize,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Target / Avg / Trend
                      MetricRow(
                        target:  widget.target,
                        avg:     widget.avg,
                        current: widget.val,
                        unit:    widget.unit,
                        buffer:  widget.buffer,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Timeline chart ─────────────────────────────────────
                ChartCard(
                  buffer:        widget.buffer,
                  historyBuffer: widget.historyBuffer,
                  logBuffer:     _logBuffer,
                  color:         widget.color,
                  unit:          widget.unit,
                  title:         widget.title,
                  mode:          _mode,
                  loadingLog:    _loadingLog,
                  hasMoreLogs:   _hasMoreLogs,
                  onModeChanged: (m) async {
                    setState(() => _mode = m);
                    if (m == ChartMode.log) await _loadLogs();
                  },
                  onLoadMore: _loadMoreLogs,
                ),

                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Value object ──────────────────────────────────────────────────────────────

class _GaugeZones {
  final double minVal, maxVal;
  final double greenLow, greenHigh;
  final double redLow, redHigh;
  const _GaugeZones({
    required this.minVal,  required this.maxVal,
    required this.greenLow, required this.greenHigh,
    required this.redLow,  required this.redHigh,
  });
}

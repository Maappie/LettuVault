import 'dart:math';

import 'package:flutter/material.dart';

import 'package:my_new_app/shared/widgets/sensor_chart.dart';
import 'package:my_new_app/src/models/sensor_reading.dart';

/// ChartCard — sensor timeline chart with a Live / Short / Logs mode switcher.
///
/// Log loading is managed internally; [onRequestLogs] is called when the
/// user switches to Logs mode so the parent can supply [logBuffer].
///
/// In Logs mode the "Load Earlier" button calls [onLoadMore].
class ChartCard extends StatelessWidget {
  final List<SensorReading> buffer;
  final List<SensorReading>? historyBuffer;
  final List<SensorReading> logBuffer;
  final Color color;
  final String unit;
  final String title;
  final ChartMode mode;
  final bool loadingLog;
  final bool hasMoreLogs;
  final ValueChanged<ChartMode> onModeChanged;
  final VoidCallback onLoadMore;

  const ChartCard({
    super.key,
    required this.buffer,
    this.historyBuffer,
    required this.logBuffer,
    required this.color,
    required this.unit,
    required this.title,
    required this.mode,
    required this.loadingLog,
    required this.hasMoreLogs,
    required this.onModeChanged,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    final double chartH =
        min(420.0, MediaQuery.of(context).size.height * 0.45);

    final List<SensorReading> chartBuffer = switch (mode) {
      ChartMode.short => historyBuffer ?? buffer,
      ChartMode.log   => logBuffer,
      _               => buffer,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header row: label + segmented mode switcher ───────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 6.0, bottom: 8.0),
              child: Text(
                'Timeline',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            SegmentedButton<ChartMode>(
              segments: const [
                ButtonSegment(value: ChartMode.live,  label: Text('Live')),
                ButtonSegment(value: ChartMode.short, label: Text('Short')),
                ButtonSegment(value: ChartMode.log,   label: Text('Logs')),
              ],
              selected: {mode},
              onSelectionChanged: (s) => onModeChanged(s.first),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ── Chart body ────────────────────────────────────────────────
        if (mode == ChartMode.log && loadingLog)
          _LoadingPlaceholder(height: chartH)
        else if (mode == ChartMode.log && logBuffer.isEmpty)
          _EmptyLogPlaceholder(height: chartH)
        else
          SensorChart(
            key: ValueKey(mode),
            buffer: chartBuffer,
            color:  color,
            unit:   unit,
            title:  title,
            height: chartH,
          ),

        // ── Load Earlier (log mode only) ──────────────────────────────
        if (mode == ChartMode.log)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: loadingLog
                  ? const SizedBox(
                      height: 28, width: 28,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : hasMoreLogs
                      ? OutlinedButton.icon(
                          icon: const Icon(Icons.history, size: 16),
                          label: const Text('Load Earlier',
                              style: TextStyle(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: onLoadMore,
                        )
                      : Text(
                          logBuffer.isEmpty ? '' : 'All records loaded',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.4),
                          ),
                        ),
            ),
          ),
      ],
    );
  }
}

// ── Mode enum (shared with SensorDetailScreen) ────────────────────────────────
enum ChartMode { live, short, log }

// ── Private placeholder widgets ───────────────────────────────────────────────

class _LoadingPlaceholder extends StatelessWidget {
  final double height;
  const _LoadingPlaceholder({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyLogPlaceholder extends StatelessWidget {
  final double height;
  const _EmptyLogPlaceholder({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          'No logged data for this sensor',
          style: TextStyle(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:my_new_app/shared/widgets/app_top_bar.dart';
import 'package:my_new_app/shared/widgets/metric_card.dart';
import 'package:my_new_app/features/dashboard/widgets/api_status_banner.dart';
import 'package:my_new_app/features/dashboard/widgets/sensor_summary_card.dart';
import 'package:my_new_app/features/dashboard/widgets/produce_scan_button.dart';
import 'package:my_new_app/features/dashboard/widgets/recent_scans_widget.dart';
import 'package:my_new_app/features/dashboard/widgets/recent_condition_scans_widget.dart';
import 'package:my_new_app/src/repositories/ai_repository.dart';

/// DashboardScreen — main landing screen.
///
/// Displays current T/H/P readings, connection status, and camera preview.
/// All data is passed in from [MainNavigator] which owns the sensor state.
class DashboardScreen extends StatelessWidget {
  final double t, h, p;
  final double targetT, targetH, targetP;
  final double trendT, trendH, trendP;
  final double tempDanger, humDanger, presDanger;
  final String? apiError;
  final bool apiPolling;

  const DashboardScreen({
    super.key,
    required this.t,
    required this.h,
    required this.p,
    required this.targetT,
    required this.targetH,
    required this.targetP,
    this.trendT = 0.0,
    this.trendH = 0.0,
    this.trendP = 0.0,
    this.tempDanger = 0.0,
    this.humDanger = 0.0,
    this.presDanger = 0.0,
    this.apiError,
    this.apiPolling = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AppTopBar(title: 'Dashboard'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              ApiStatusBanner(apiError: apiError, isPolling: apiPolling),
              SectionHeader('ENVIRONMENTAL DATA'),
              SensorSummaryCard(
                valueLabel: 'Temperature: ${t.toStringAsFixed(1)}°C',
                targetLabel: 'Target: ${targetT.toStringAsFixed(1)}°C',
                dangerLevel: tempDanger,
                trend: trendT,
              ),
              SensorSummaryCard(
                valueLabel: 'Humidity: ${h.toStringAsFixed(0)}%',
                targetLabel: 'Target: ${targetH.toStringAsFixed(0)}%',
                dangerLevel: humDanger,
                trend: trendH,
              ),
              SensorSummaryCard(
                valueLabel: 'Pressure: ${p.toStringAsFixed(1)} hPa',
                targetLabel: 'Target: ${targetP.toStringAsFixed(1)} hPa',
                dangerLevel: presDanger,
                trend: trendP,
              ),
              SectionHeader('SCANS & ACTIONS'),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  children: [
                    Expanded(child: const ProduceScanButton()),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TestCameraButtonWidget(),
                    ),
                  ],
                ),
              ),
              SectionHeader('PRODUCE SCANS'),
              const RecentProduceScansWidget(),
              SectionHeader('CONDITION SCANS (WORMS & WILTING)'),
              const RecentConditionScansWidget(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}

class _TestCameraButtonWidget extends StatefulWidget {
  @override
  State<_TestCameraButtonWidget> createState() => _TestCameraButtonWidgetState();
}

class _TestCameraButtonWidgetState extends State<_TestCameraButtonWidget> {
  final AiRepository _repo = AiRepository();
  bool _isRequesting = false;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        foregroundColor: Theme.of(context).colorScheme.onSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: _isRequesting ? null : () async {
        setState(() => _isRequesting = true);
        try {
          await _repo.testCamera();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Test Camera Triggered!'), backgroundColor: Colors.green),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
            );
          }
        } finally {
          if (mounted) {
            setState(() => _isRequesting = false);
          }
        }
      },
      icon: _isRequesting 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.camera_alt),
      label: Text(
        _isRequesting ? 'REQ...' : 'VIEW INSIDE',
        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

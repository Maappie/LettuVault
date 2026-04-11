import 'package:flutter/material.dart';

import 'package:my_new_app/shared/widgets/app_top_bar.dart';
import 'package:my_new_app/shared/widgets/metric_card.dart';
import 'package:my_new_app/features/dashboard/widgets/api_status_banner.dart';
import 'package:my_new_app/features/dashboard/widgets/sensor_summary_card.dart';
import 'package:my_new_app/features/dashboard/widgets/camera_preview_card.dart';

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
              SectionHeader('LIVE CAMERA'),
              const CameraPreviewCard(),
            ],
          ),
        ),
      ],
    );
  }
}

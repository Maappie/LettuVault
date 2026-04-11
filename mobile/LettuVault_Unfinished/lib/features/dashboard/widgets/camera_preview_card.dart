import 'dart:math';

import 'package:flutter/material.dart';

/// CameraPreviewCard — placeholder card for the Live Camera feed.
class CameraPreviewCard extends StatelessWidget {
  const CameraPreviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: min(200, MediaQuery.of(context).size.height * 0.25),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Center(
        child: Text(
          'Live Stream Simulation',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

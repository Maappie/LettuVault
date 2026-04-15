import 'dart:math';

import 'package:flutter/material.dart';
import '../../../../src/repositories/ai_repository.dart';

/// CameraPreviewCard — placeholder card for the Live Camera feed.
class CameraPreviewCard extends StatefulWidget {
  const CameraPreviewCard({super.key});

  @override
  State<CameraPreviewCard> createState() => _CameraPreviewCardState();
}

class _CameraPreviewCardState extends State<CameraPreviewCard> {
  final AiRepository _repo = AiRepository();
  bool _isRequesting = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: min(200, MediaQuery.of(context).size.height * 0.25),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Live Stream Simulation',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isRequesting ? null : () async {
              setState(() => _isRequesting = true);
              try {
                await _repo.testCamera();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Test Camera Snapshot Triggered!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
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
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.camera_alt),
            label: Text(_isRequesting ? 'Requesting...' : 'View Inside'),
          ),
        ],
      ),
    );
  }
}

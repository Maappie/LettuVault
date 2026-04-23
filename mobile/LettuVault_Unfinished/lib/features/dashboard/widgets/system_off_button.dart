import 'package:flutter/material.dart';

import 'package:my_new_app/src/core/api_client.dart';
import 'package:my_new_app/services/sensor_polling_service.dart';

/// SystemToggleButton — turns the system OFF or ON depending on current state.
///
/// OFF  → calls POST /system-off  (works offline + online via command relay)
/// ON   → calls POST /trigger-produce-scan (same relay, both modes)
class SystemToggleButton extends StatefulWidget {
  /// Whether the system is currently in standby mode.
  final bool isStandby;

  const SystemToggleButton({super.key, required this.isStandby});

  @override
  State<SystemToggleButton> createState() => _SystemToggleButtonState();
}

class _SystemToggleButtonState extends State<SystemToggleButton> {
  final ApiClient _client = ApiClient();
  bool _loading = false;

  Future<void> _handleTap() async {
    if (widget.isStandby) {
      await _turnOn();
    } else {
      await _turnOff();
    }
  }

  Future<void> _turnOff() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.power_settings_new, color: Colors.red.shade400, size: 24),
            const SizedBox(width: 10),
            const Text('Turn Off System'),
          ],
        ),
        content: const Text(
          'This will stop all controls (compressor, vacuum, humidifier) '
          'and pause sensor data logging.\n\n'
          'Are you sure you want to put the system in standby?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Turn Off'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    // Persist standby state immediately — before API call completes
    await SensorPollingService.instance.setStandby(true);
    await _doRequest('/system-off', 'System entering standby — all controls OFF');
  }

  Future<void> _turnOn() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.play_circle_outline, color: Colors.green.shade400, size: 24),
            const SizedBox(width: 10),
            const Text('Turn On System'),
          ],
        ),
        content: const Text(
          'This will trigger a produce scan to re-initialize the system '
          'and resume environmental controls.\n\n'
          'Are you sure you want to start the system?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade400),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Turn On'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    // Clear standby state immediately — before API call completes
    await SensorPollingService.instance.setStandby(false);
    await _doRequest('/trigger-produce-scan', 'System starting — produce scan triggered');
  }

  Future<void> _doRequest(String endpoint, String successMsg) async {
    setState(() => _loading = true);
    try {
      await _client.post(endpoint, {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: widget.isStandby
                ? Colors.green.shade700   // turning ON
                : Colors.orange.shade700, // turning OFF
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
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isOn      = widget.isStandby; // standby = system is OFF, button says "Turn On"
    final color     = isOn ? Colors.green.shade400 : Colors.red.shade400;
    final icon      = isOn ? Icons.play_circle_outline : Icons.power_settings_new;
    final label     = isOn ? 'TURN ON SYSTEM' : 'TURN OFF SYSTEM';
    final bgAlpha   = isDark ? 0.08 : 0.04;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color.withValues(alpha: 0.5), width: 1.5),
            foregroundColor: color,
            backgroundColor: color.withValues(alpha: bgAlpha),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _loading ? null : _handleTap,
          icon: _loading
              ? SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              : Icon(icon, color: color),
          label: Text(
            _loading ? 'SENDING...' : label,
            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'package:my_new_app/src/core/api_client.dart';

/// SystemOffButton — puts the ESP32 into standby mode.
///
/// Works in BOTH offline and online mode via the same single call:
///   - Offline: Pi's /system-off → publishes MQTT immediately → ESP32 standby
///   - Online:  Cloud's /system-off → enqueues SYSTEM_OFF command →
///              Pi sync engine picks it up on next poll → publishes MQTT → ESP32 standby
class SystemOffButton extends StatefulWidget {
  const SystemOffButton({super.key});

  @override
  State<SystemOffButton> createState() => _SystemOffButtonState();
}

class _SystemOffButtonState extends State<SystemOffButton> {
  final ApiClient _client = ApiClient();
  bool _loading = false;

  Future<void> _turnOffSystem() async {
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

    setState(() => _loading = true);
    try {
      await _client.post('/system-off', {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('System standby command sent'),
            backgroundColor: Colors.orange.shade700,
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
    final dangerColor = Colors.red.shade400;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: dangerColor.withValues(alpha: 0.5), width: 1.5),
            foregroundColor: dangerColor,
            backgroundColor: dangerColor.withValues(alpha: isDark ? 0.08 : 0.04),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _loading ? null : _turnOffSystem,
          icon: _loading
              ? SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: dangerColor),
                )
              : Icon(Icons.power_settings_new, color: dangerColor),
          label: Text(
            _loading ? 'SENDING...' : 'TURN OFF SYSTEM',
            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
        ),
      ),
    );
  }
}

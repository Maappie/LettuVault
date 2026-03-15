import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Simple HTTP polling adapter that fetches JSON from a configured URL and
/// forwards values to the provided `onData` callback.
///
/// Expected JSON payload example:
/// { "temp": 23.4, "hum": 56.2, "pres": 1012.3 }
///
/// NOTE: for Android emulator use `http://10.0.2.2:5000/sensor` to reach a
/// local dev server running on the host machine.
class SensorNetworkAdapter {
  final String url;
  final int intervalSeconds;
  final void Function(double? temp, double? hum, double? pres) onData;

  Timer? _timer;
  bool _running = false;

  SensorNetworkAdapter({
    required this.url,
    this.intervalSeconds = 5,
    required this.onData,
  });

  bool get isRunning => _running;

  void start() {
    _running = true;
    _fetchOnce();
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: intervalSeconds), (_) => _fetchOnce());
  }

  void stop() {
    _timer?.cancel();
    _running = false;
  }

  Future<void> _fetchOnce() async {
    try {
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
      if (resp.statusCode != 200) return;
      final Map<String, dynamic> j = json.decode(resp.body) as Map<String, dynamic>;
      final double? t = j['temp'] != null ? (j['temp'] as num).toDouble() : null;
      final double? h = j['hum'] != null ? (j['hum'] as num).toDouble() : null;
      final double? p = j['pres'] != null ? (j['pres'] as num).toDouble() : null;
      onData(t, h, p);
    } catch (_) {
      // Swallow network/timeouts — adapter keeps trying on next tick
    }
  }
}

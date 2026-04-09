import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:workmanager/workmanager.dart';

import '../core/constants.dart';

// ─── Notification channels ───────────────────────────────────────────────────
const String _kBgChannelId      = 'lettuvault_bg';
const String _kBgChannelName    = 'LettuVault Background';
const String _kOrangeChannelId   = 'lettuvault_orange_alerts';
const String _kOrangeChannelName = 'LettuVault Warnings';
const String _kRedChannelId      = 'lettuvault_red_alerts';
const String _kRedChannelName    = 'LettuVault Critical Alerts';
const int    _kBgNotifId        = 888;

const int _kTempAlertId = 901;
const int _kHumAlertId  = 902;
const int _kPresAlertId = 903;

// ─── WorkManager task names ───────────────────────────────────────────────────
// The periodic task is the reliable watchdog: fires every 15 min even when
// HiOS/Hiber has killed the foreground service completely.
const String _kWmTaskName = 'lettuvault_zone_watch';
const String _kWmTaskTag  = 'zoneWatch';

// ─── Zone enum ───────────────────────────────────────────────────────────────
enum _Zone { green, orange, red }

// ─── SharedPreferences keys ───────────────────────────────────────────────────
const String _kPrefZonePrefix      = 'bg_zone_';
const String _kPrefLastNotifPrefix = 'bg_last_notif_';
const String _kPrefActiveIdPrefix  = 'bg_active_id_';

// Re-fire if sensor stays in non-green for this long without change.
const Duration _kReminderInterval = Duration(minutes: 2);

// Consecutive green readings needed before we cancel an alert.
const int _kGreenClearThreshold = 3;

// Per-tick in-memory green counter (resets on service restart — intentional).
final Map<String, int> _greenReadingCount = {};

// System-config cache (used only by the long-running foreground service).
// WorkManager runs in a fresh isolate each time so it always fetches fresh.
Map<String, double>? _cachedConfig;
DateTime _configLastFetched = DateTime.fromMillisecondsSinceEpoch(0);

// ─── Zone persistence helpers ─────────────────────────────────────────────────

String _zoneToString(_Zone z) => z.name;

_Zone _zoneFromString(String? s) {
  switch (s) {
    case 'orange': return _Zone.orange;
    case 'red':    return _Zone.red;
    default:       return _Zone.green;
  }
}

_Zone _loadZoneSync(SharedPreferences prefs, String key) =>
    _zoneFromString(prefs.getString('$_kPrefZonePrefix$key'));

Future<void> _saveZone(SharedPreferences prefs, String key, _Zone zone) =>
    prefs.setString('$_kPrefZonePrefix$key', _zoneToString(zone));

DateTime? _loadLastNotifTime(SharedPreferences prefs, String key) {
  final ms = prefs.getInt('$_kPrefLastNotifPrefix$key');
  return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
}

Future<void> _saveLastNotifTime(SharedPreferences prefs, String key, DateTime dt) =>
    prefs.setInt('$_kPrefLastNotifPrefix$key', dt.millisecondsSinceEpoch);

int? _loadActiveNotifId(SharedPreferences prefs, String key) =>
    prefs.getInt('$_kPrefActiveIdPrefix$key');

Future<void> _saveActiveNotifId(SharedPreferences prefs, String key, int? id) =>
    id == null ? prefs.remove('$_kPrefActiveIdPrefix$key')
               : prefs.setInt('$_kPrefActiveIdPrefix$key', id);

String _zoneEmoji(_Zone z) {
  switch (z) {
    case _Zone.green:  return '✅';
    case _Zone.orange: return '⚠️';
    case _Zone.red:    return '🔴';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WorkManager callback dispatcher — MUST be a top-level function.
// Runs in its own Dart isolate every 15 minutes, independent of the
// foreground service. This is the reliable watchdog that fires even when
// HiOS has completely killed the foreground service and all Flutter processes.
// ═══════════════════════════════════════════════════════════════════════════════

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('[WM] ====== WorkManager task fired: $task ======');
    try {
      // Plugins need bindings initialised in a WorkManager isolate.
      WidgetsFlutterBinding.ensureInitialized();

      final notifs = FlutterLocalNotificationsPlugin();
      await notifs.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );

      // Ensure alert channels exist in this fresh isolate.
      final android = notifs.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _kOrangeChannelId, _kOrangeChannelName, importance: Importance.high,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        _kRedChannelId, _kRedChannelName, importance: Importance.max,
      ));

      // Run the shared poll-and-notify logic (no service context in WM).
      await _pollAndNotify(notifs, service: null);
      debugPrint('[WM] Task complete.');
    } catch (e, st) {
      debugPrint('[WM] ERROR: $e\n$st');
    }
    return Future.value(true);
  });
}

// ─── Public init function ─────────────────────────────────────────────────────

/// Initialise WorkManager + the foreground background service.
/// Safe to call multiple times.
Future<void> initBackgroundService() async {
  // ── Notification channel creation ────────────────────────────────────────
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _kBgChannelId, _kBgChannelName,
      description: 'Keeps LettuVault sensor polling alive in the background',
      importance: Importance.low,
    ));
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _kOrangeChannelId, _kOrangeChannelName,
      description: 'Alerts when a sensor enters the orange zone',
      importance: Importance.high,
    ));
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      _kRedChannelId, _kRedChannelName,
      description: 'Critical alerts when a sensor enters the red zone',
      importance: Importance.max,
    ));
  } catch (e) {
    debugPrint('[BG] Notification channel setup failed: $e');
  }

  // ── WorkManager registration ──────────────────────────────────────────────
  // This is the RELIABLE WATCHDOG. Even if HiOS kills the foreground service,
  // WorkManager will wake the device and run _pollAndNotify every ~15 minutes.
  // Android enforces a 15-minute minimum period — this is OS-level, not our limit.
  try {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    await Workmanager().registerPeriodicTask(
      _kWmTaskName,
      _kWmTaskTag,
      frequency: const Duration(minutes: 15),
      // keep = don't replace the task if it's already scheduled
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 5),
    );
    debugPrint('[BG] WorkManager watchdog registered (15-min period)');
  } catch (e) {
    debugPrint('[BG] WorkManager registration failed (non-fatal): $e');
  }

  // ── flutter_background_service (foreground, real-time 5-second polling) ──
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onBgStart,
      isForegroundMode: true,
      autoStart: true,
      foregroundServiceNotificationId: _kBgNotifId,
      initialNotificationTitle: 'LettuVault',
      initialNotificationContent: 'Monitoring environment…',
      notificationChannelId: _kBgChannelId,
      foregroundServiceTypes: const [AndroidForegroundType.dataSync],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onBgStart,
    ),
  );

  final isRunning = await service.isRunning();
  if (!isRunning) await service.startService();
}

// ─── Foreground service entry point ──────────────────────────────────────────

@pragma('vm:entry-point')
void onBgStart(ServiceInstance service) async {
  debugPrint('[BG] ======== Foreground service isolate started ========');

  final FlutterLocalNotificationsPlugin notifs = FlutterLocalNotificationsPlugin();
  await notifs.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  debugPrint('[BG] Notification plugin initialized');

  if (service is AndroidServiceInstance) {
    service.on('stopService').listen((_) => service.stopSelf());
  }

  Future<void> tick() async {
    // Re-acquire CPU wakelock continuously to fight TECNO Hiber.
    try { await WakelockPlus.enable(); } catch (_) {}
    await _pollAndNotify(notifs, service: service);
  }

  // First tick immediately, then every N seconds.
  tick();
  Timer.periodic(Duration(seconds: kDashboardPollIntervalSeconds), (_) => tick());
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared poll-and-notify logic
// Called by BOTH the foreground service timer AND the WorkManager task.
// [service] is null when called from WorkManager.
// ═══════════════════════════════════════════════════════════════════════════════

Future<void> _pollAndNotify(
  FlutterLocalNotificationsPlugin notifs, {
  required ServiceInstance? service,
}) async {
  final String tag = service != null ? '[BG]' : '[WM]';

  // Load persisted zone state — must happen before any early return so every
  // code path uses the same SharedPreferences snapshot for this tick.
  final SharedPreferences prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('$tag SharedPreferences unavailable: $e');
    return;
  }

  try {
    // ── 1. Fetch the latest sensor reading ──────────────────────────────────
    final readingResp = await http.get(
      Uri.parse('$kBaseUrl$kApiPrefix/internal-environment?limit=1&order=desc'),
      headers: {'X-API-KEY': kApiKey},
    ).timeout(const Duration(seconds: 10));

    debugPrint('$tag Sensor API → ${readingResp.statusCode}');
    if (readingResp.statusCode != 200) return;

    final data  = json.decode(readingResp.body);
    final List items = data is List ? data : (data['items'] ?? []);
    if (items.isEmpty) return;

    final item = items.first;
    final double temp = (item['temperature'] ?? 0).toDouble();
    final double hum  = (item['humidity']    ?? 0).toDouble();
    final double pres = (item['pressure']    ?? 0).toDouble();

    // Push reading to the UI isolate (no-op when called from WorkManager).
    service?.invoke('sensorReading', {
      'temperature': temp,
      'humidity':    hum,
      'pressure':    pres,
    });

    // ── 2. Refresh system-config cache (60-s TTL for foreground service) ────
    final now = DateTime.now();
    // WorkManager always fetches fresh config (fresh isolate = null _cachedConfig).
    if (_cachedConfig == null ||
        now.difference(_configLastFetched).inSeconds >= 60) {
      try {
        final cfgResp = await http.get(
          Uri.parse('$kBaseUrl$kApiPrefix/system_config'),
          headers: {'X-API-KEY': kApiKey},
        ).timeout(const Duration(seconds: 10));

        if (cfgResp.statusCode == 200) {
          final decoded = json.decode(cfgResp.body);
          final List cfgItems = decoded is List ? decoded : [];
          if (cfgItems.isNotEmpty) {
            final cfg = cfgItems.first;
            _cachedConfig = {
              'temp': (cfg['temperature'] ?? cfg['set_temperature'] ?? 25.0).toDouble(),
              'hum':  (cfg['humidity']    ?? cfg['set_humidity']    ?? 60.0).toDouble(),
              'pres': (cfg['pressure']    ?? cfg['set_pressure']    ?? 1013.0).toDouble(),
            };
            _configLastFetched = now;
          } else {
            _cachedConfig = {'temp': 25.0, 'hum': 60.0, 'pres': 1013.0};
            _configLastFetched = now;
          }
        }
      } catch (e) {
        debugPrint('$tag Config fetch error: $e');
      }
    }
    if (_cachedConfig == null) {
      debugPrint('$tag No config yet — skipping zone check');
      return;
    }
    debugPrint('$tag Config → T=${_cachedConfig!["temp"]} H=${_cachedConfig!["hum"]} P=${_cachedConfig!["pres"]}');

    // ── 3. Read threshold settings ──────────────────────────────────────────
    final useDefault = prefs.getBool('useDefaultThresholds') ?? true;
    final tTarget = _cachedConfig!['temp']!;
    final hTarget = _cachedConfig!['hum']!;
    final pTarget = _cachedConfig!['pres']!;

    final tempLow  = prefs.getDouble('tempThresholdLow')      ?? (tTarget - kTempMaxDeviation);
    final tempHigh = prefs.getDouble('tempThresholdHigh')     ?? (tTarget + kTempMaxDeviation);
    final humLow   = prefs.getDouble('humidityThresholdLow')  ?? (hTarget - kHumMaxDeviation);
    final humHigh  = prefs.getDouble('humidityThresholdHigh') ?? (hTarget + kHumMaxDeviation);
    final presLow  = prefs.getDouble('pressureThresholdLow')  ?? (pTarget - kPresMaxDeviation);
    final presHigh = prefs.getDouble('pressureThresholdHigh') ?? (pTarget + kPresMaxDeviation);

    // ── 4. Compute zones ────────────────────────────────────────────────────
    final tempZone = _computeZone(
      value: temp, target: tTarget,
      tolerance: kTempTolerance, maxDev: kTempMaxDeviation,
      customLow: tempLow, customHigh: tempHigh, useDefault: useDefault,
    );
    final humZone = _computeZone(
      value: hum, target: hTarget,
      tolerance: kHumTolerance, maxDev: kHumMaxDeviation,
      customLow: humLow, customHigh: humHigh, useDefault: useDefault,
    );
    final presZone = _computeZone(
      value: pres, target: pTarget,
      tolerance: kPresTolerance, maxDev: kPresMaxDeviation,
      customLow: presLow, customHigh: presHigh, useDefault: useDefault,
    );

    debugPrint('$tag Zones → T:$tempZone  H:$humZone  P:$presZone');

    // ── 5. Update persistent foreground notification (foreground service only) ─
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'LettuVault — Live Monitoring',
        content: '🌡 ${temp.toStringAsFixed(1)}°C ${_zoneEmoji(tempZone)}  '
                 '💧 ${hum.toStringAsFixed(0)}% ${_zoneEmoji(humZone)}  '
                 '🔵 ${pres.toStringAsFixed(0)} hPa ${_zoneEmoji(presZone)}',
      );
    }

    // ── 6. Load persisted previous zones ────────────────────────────────────
    final prevTemp = _loadZoneSync(prefs, 'temp');
    final prevHum  = _loadZoneSync(prefs, 'hum');
    final prevPres = _loadZoneSync(prefs, 'pres');
    debugPrint('$tag Persisted prev → T:$prevTemp  H:$prevHum  P:$prevPres');

    // ── 7. Fire notifications on zone change / reminder ──────────────────────
    await _checkAndNotify(prefs, notifs, 'Temperature', '${temp.toStringAsFixed(1)}°C',   _kTempAlertId, tempZone, prevTemp, 'temp', tag);
    await _checkAndNotify(prefs, notifs, 'Humidity',    '${hum.toStringAsFixed(0)}%',     _kHumAlertId,  humZone,  prevHum,  'hum',  tag);
    await _checkAndNotify(prefs, notifs, 'Pressure',    '${pres.toStringAsFixed(0)} hPa', _kPresAlertId, presZone, prevPres, 'pres', tag);

  } catch (e, st) {
    debugPrint('$tag ERROR: $e\n$st');
  }
}

// ─── Zone computation ─────────────────────────────────────────────────────────

_Zone _computeZone({
  required double value,
  required double target,
  required double tolerance,
  required double maxDev,
  required double customLow,
  required double customHigh,
  required bool   useDefault,
}) {
  if (useDefault) {
    final diff = (value - target).abs();
    if (diff <= tolerance) return _Zone.green;
    if (diff <= maxDev)    return _Zone.orange;
    return _Zone.red;
  } else {
    if (value < customLow || value > customHigh) return _Zone.red;
    if ((value - target).abs() <= tolerance)     return _Zone.green;
    return _Zone.orange;
  }
}

// ─── Notification logic ───────────────────────────────────────────────────────

Future<void> _checkAndNotify(
  SharedPreferences               prefs,
  FlutterLocalNotificationsPlugin notifs,
  String sensorName,
  String readingStr,
  int    baseNotifId,
  _Zone  zone,
  _Zone  prev,
  String key,
  String tag,
) async {
  final lastTime    = _loadLastNotifTime(prefs, key);
  final zoneChanged = zone != prev;
  final reminderDue = !zoneChanged &&
      zone != _Zone.green &&
      (lastTime == null || DateTime.now().difference(lastTime) >= _kReminderInterval);

  if (!zoneChanged && !reminderDue) {
    debugPrint('$tag $sensorName: zone unchanged ($zone), skipping');
    return;
  }

  if (zoneChanged) {
    debugPrint('$tag $sensorName: zone CHANGED $prev → $zone');
  } else {
    debugPrint('$tag $sensorName: persistent $zone — reminder');
  }

  // ── Green: debounce before cancelling the alarm ───────────────────────────
  if (zone == _Zone.green) {
    if (prev != _Zone.green) {
      final count = (_greenReadingCount[key] ?? 0) + 1;
      _greenReadingCount[key] = count;
      debugPrint('$tag $sensorName: green reading #$count/$_kGreenClearThreshold');
      if (count < _kGreenClearThreshold) return; // not stable yet
    }
    _greenReadingCount[key] = 0;
    if (prev != _Zone.green) {
      final activeId = _loadActiveNotifId(prefs, key) ?? baseNotifId;
      notifs.cancel(id: activeId);
      await _saveActiveNotifId(prefs, key, null);
      await _saveLastNotifTime(prefs, key, DateTime.fromMillisecondsSinceEpoch(0));
      await _saveZone(prefs, key, _Zone.green);
      debugPrint('$tag $sensorName: stable green — cancelled notif $activeId');
    }
    return;
  }

  _greenReadingCount[key] = 0;

  final bool isRed = zone == _Zone.red;

  // Zone change → fresh notification ID (Android treats it as brand-new: banner + vibration).
  // Reminder → reuse existing ID (silently updates the text).
  final int fireId;
  if (zoneChanged) {
    final oldId = _loadActiveNotifId(prefs, key);
    if (oldId != null) notifs.cancel(id: oldId);
    fireId = baseNotifId * 1000 + (DateTime.now().millisecondsSinceEpoch ~/ 1000) % 1000;
    await _saveActiveNotifId(prefs, key, fireId);
  } else {
    fireId = _loadActiveNotifId(prefs, key) ?? baseNotifId;
  }

  notifs.show(
    id:    fireId,
    title: isRed
        ? 'LettuVault Alert 🔴 — Red Zone'
        : 'LettuVault Warning 🟠 — Orange Zone',
    body: isRed
        ? '$sensorName ($readingStr) has entered the Red Zone. Please check the LettuVault immediately!'
        : '$sensorName ($readingStr) is in the Orange Zone. LettuVault is outside the safe range.',
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        isRed ? _kRedChannelId : _kOrangeChannelId,
        isRed ? _kRedChannelName : _kOrangeChannelName,
        importance:      isRed ? Importance.max  : Importance.high,
        priority:        isRed ? Priority.max    : Priority.high,
        icon:            '@mipmap/ic_launcher',
        ongoing:         isRed,
        autoCancel:      !isRed,
        playSound:       true,
        enableVibration: true,
      ),
    ),
  );

  await _saveZone(prefs, key, zone);
  await _saveLastNotifTime(prefs, key, DateTime.now());
  debugPrint('$tag $sensorName: notif $fireId fired — zone=$zone saved to disk');
}

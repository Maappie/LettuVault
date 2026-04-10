import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_iot/wifi_iot.dart';

import 'src/models/sensor_reading.dart';
import 'src/screens/home_screen.dart';
import 'src/screens/detail_screen.dart';
import 'src/screens/log_status_screen.dart';
import 'src/screens/splash_screen.dart';
import 'src/screens/setup_offline_screen.dart';
import 'src/widgets/helpers.dart';
import 'src/repositories/environment_repository.dart';
import 'src/repositories/config_repository.dart';
import 'src/core/constants.dart';
import 'src/core/app_mode.dart';
import 'src/core/secure_storage.dart';
import 'src/services/background_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:auto_start_flutter/auto_start_flutter.dart';

final FlutterLocalNotificationsPlugin localNotif =
    FlutterLocalNotificationsPlugin();

// Global theme notifier so screens can toggle theme at runtime
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Seed default API keys into secure storage on first run
  await SecureStorage.seedDefaultsIfNeeded();
  // Best-effort background service init
  try {
    await initBackgroundService();
  } catch (e) {
    debugPrint('[BG] Background service init failed (non-fatal): $e');
  }
  runApp(
    ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) => MaterialApp(
        title: 'LettuVault',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
          primaryColor: Colors.blue.shade700,
          scaffoldBackgroundColor: const Color(0xFFF6F8FA),
          cardColor: Colors.white,
          fontFamily: 'Google',
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
          primaryColor: const Color(0xFF1E1E1E),
          scaffoldBackgroundColor: const Color(0xFF121212),
          cardColor: const Color(0xFF1E1E1E),
          fontFamily: 'Google',
          useMaterial3: true,
        ),
        themeMode: mode,
        home: MainNavigationContainer(key: MainNavigationContainer.navKey),
      ),
    ),
  );
}

// --- MASTER CONTROLLER ---
class MainNavigationContainer extends StatefulWidget {
  const MainNavigationContainer({super.key});

  // Global key to access the state and inject real sensor data from elsewhere
  static final GlobalKey<_MainNavigationContainerState> navKey = GlobalKey<_MainNavigationContainerState>();

  @override
  State<MainNavigationContainer> createState() =>
      _MainNavigationContainerState();
}

class _MainNavigationContainerState extends State<MainNavigationContainer> {
  int _selectedIndex = 0;
  // Zone tracking: 0=green 1=orange 2=red — only notify on transitions
  final Map<String, int> _lastZone = {'temp': 0, 'hum': 0, 'pres': 0};
  bool _alertsEnabled = true;

  // UI theme state
  bool _isDarkMode = false;
  // Show startup splash until async initialization completes
  bool _isLoading = true;
  // First-time offline setup
  bool _showOfflineSetup = false;
  // Mode-switching state
  bool _isSwitchingMode = false;
  String? _modeError;

  double tempThresholdLow = 18.0; 
  double tempThresholdHigh = 28.0; 
  double humidityThresholdLow = 40.0;
  double humidityThresholdHigh = 80.0;
  double pressureThresholdLow = 950.0;
  double pressureThresholdHigh = 1050.0;

  // Longer history buffers (short-term / 30 samples)
  List<SensorReading> tempHistory = [];
  List<SensorReading> humidityHistory = [];
  List<SensorReading> pressureHistory = [];

  // NOTE: use the _Low/_High threshold pairs above for alerts and UI sliders
  bool _useDefaultThresholds = true;

  // Staging variables — used as temp state while editing custom alert thresholds.
  // Only applied to the real threshold variables when the user taps "Save".
  double _draftTempLow = 18.0;
  double _draftTempHigh = 28.0;
  double _draftHumLow = 40.0;
  double _draftHumHigh = 80.0;
  double _draftPresLow = 950.0;
  double _draftPresHigh = 1050.0;
  String? _thresholdError;

  // --- System Config (UI-only target setpoints chosen by the user) ---
  String _selectedPreset = 'Custom';
  double _sysConfigTemp = 25.0;
  double _sysConfigHum = 60.0;
  double _sysConfigPres = 1013.0;
  bool _showSysConfig = false; // collapsed by default

  // --- Real API polling ---
  final EnvironmentRepository _envRepo = EnvironmentRepository();
  final ConfigRepository _configRepo = ConfigRepository();
  Timer? _apiPollTimer;
  bool _apiPollingEnabled = false;
  String? _apiError;  // null = no error, otherwise the error message

  List<SensorReading> tempBuffer = [];
  List<SensorReading> humidityBuffer = [];
  List<SensorReading> pressureBuffer = [];

  double currentTemp = 25.0, currentHum = 60.0, currentPres = 1013.0;
  double avgT = 25.0, avgH = 60.0, avgP = 1013.0;
  
  // Target Setpoints (from system_config)
  double targetTemp = 25.0, targetHum = 60.0, targetPres = 1013.0;
  
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _performStartup();
  }

  // Perform async startup steps while showing a splash/loading screen
  Future<void> _performStartup() async {
    setState(() => _isLoading = true);

    // await critical async initialization before showing main UI
    try {
      await _initializeNotifications();
    } catch (_) {}
    await _loadSavedThresholds();
    await _loadSavedTheme();

    // Start real API polling (runs alongside the background service)
    _startApiPolling();

    // Subscribe to readings pushed by the background isolate (best-effort)
    try {
      FlutterBackgroundService().on('sensorReading').listen((data) {
        if (data == null || !mounted) return;
        injectSensorReadings(
          temp: (data['temperature'] as num?)?.toDouble(),
          hum:  (data['humidity']   as num?)?.toDouble(),
          pres: (data['pressure']   as num?)?.toDouble(),
        );
      });
    } catch (e) {
      debugPrint('[BG] Could not subscribe to background readings: $e');
    }

    // Check if offline setup has ever been completed — show it if not
    final setupDone = await SecureStorage.isOfflineSetupDone();
    if (!setupDone && mounted) {
      setState(() { _isLoading = false; _showOfflineSetup = true; });
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    // Automatically detect and pop up the "Auto Start" settings screen on
    // Chinese ROMs (like TECNO's HiOS, Xiaomi MIUI, etc.) if it is available.
    try {
      final available = await isAutoStartAvailable;
      if (available == true) {
        final prefs = await SharedPreferences.getInstance();
        final bool autoStartPrompted = prefs.getBool('autoStartPrompted') ?? false;
        
        // Temporarily ignore the saved flag so the user can see the new instructions,
        // unless they literally just did it. For production this would stay true.
        // I will set it to false so it pops up for the user now.
        if (!autoStartPrompted || prefs.getBool('v2Prompt') != true) {
          if (!mounted) return;
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Keep Alerts Running'),
              content: const Text(
                'To ensure you receive critical alerts when LettuVault is closed:\n\n'
                '1. We will open your "App Launch" settings.\n'
                '2. Find LettuVault in the list and turn it ON (Allowed).\n'
                '3. Do NOT tap the "Intelligent Optimization" button at the bottom.\n\n'
                'Then press your phone\'s Back button to return here.',
                style: TextStyle(height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Skip'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await getAutoStartPermission();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
          await prefs.setBool('autoStartPrompted', true);
          await prefs.setBool('v2Prompt', true);
        }
      }
    } catch (e) {
      debugPrint('[AutoStart] error: $e');
    }
  }

  // --- Persistence for thresholds using shared_preferences
  Future<void> _loadSavedThresholds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _useDefaultThresholds = prefs.getBool('useDefaultThresholds') ?? true;
        tempThresholdLow = prefs.getDouble('tempThresholdLow') ?? tempThresholdLow;
        tempThresholdHigh = prefs.getDouble('tempThresholdHigh') ?? tempThresholdHigh;
        humidityThresholdLow = prefs.getDouble('humidityThresholdLow') ?? humidityThresholdLow;
        humidityThresholdHigh = prefs.getDouble('humidityThresholdHigh') ?? humidityThresholdHigh;
        pressureThresholdLow = prefs.getDouble('pressureThresholdLow') ?? pressureThresholdLow;
        pressureThresholdHigh = prefs.getDouble('pressureThresholdHigh') ?? pressureThresholdHigh;
      });
    } catch (e) {
      debugPrint('Prefs load error: $e');
    }
  }

  // Persist and restore the user's theme choice
  Future<void> _loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool('isDarkMode') ?? false;
      themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
      setState(() => _isDarkMode = isDark);
    } catch (e) {
      debugPrint('Theme load error: $e');
    }
  }

  Future<void> _saveThemePreference(bool isDark) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', isDark);
    } catch (e) {
      debugPrint('Theme save error: $e');
    }
  }

  Future<void> _saveThreshold(String key, double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(key, value);
    } catch (e) {
      debugPrint('Prefs save error: $e');
    }
  }

  Future<void> _saveBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('Prefs save error: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _apiPollTimer?.cancel();
    super.dispose();
  }

  // --- Real API Polling ---
  void _startApiPolling() {
    _apiPollTimer?.cancel();
    _apiPollingEnabled = true;
    // Initial fetch immediately
    _fetchLatestFromApi();
    // Then poll on interval
    _apiPollTimer = Timer.periodic(
      Duration(seconds: kDashboardPollIntervalSeconds),
      (_) => _fetchLatestFromApi(),
    );
  }


  Future<void> _fetchLatestFromApi() async {
    if (!_apiPollingEnabled) return;
    try {
      final reading = await _envRepo.getLatest();
      final config = await _configRepo.getLatest();
      
      if (config != null) {
        setState(() {
          targetTemp = config.temperature ?? targetTemp;
          targetHum = config.humidity ?? targetHum;
          targetPres = config.pressure ?? targetPres;
          
          if (_useDefaultThresholds) {
            // Dynamically center the critical safety boundaries around our true target
            tempThresholdLow = targetTemp - kTempMaxDeviation;
            tempThresholdHigh = targetTemp + kTempMaxDeviation;
            
            humidityThresholdLow = targetHum - kHumMaxDeviation;
            humidityThresholdHigh = targetHum + kHumMaxDeviation;
            
            pressureThresholdLow = targetPres - kPresMaxDeviation;
            pressureThresholdHigh = targetPres + kPresMaxDeviation;
          }
        });
      }

      if (reading == null) {
        setState(() => _apiError = null); // no data yet, not an error
        return;
      }
      
      // Inject the real values into the existing system
      injectSensorReadings(
        temp: reading.temperature,
        hum: reading.humidity,
        pres: reading.pressure,
      );

      // ── Zone notifications ────────────────────────────────────────────────
      // This runs in the main isolate (always alive when app is backgrounded).
      // Uses the same target / threshold state already loaded for the gauges.
      if (_alertsEnabled) {
        _checkAndNotifyZone(
          key: 'temp', sensorName: 'Temperature',
          readingStr: '${reading.temperature?.toStringAsFixed(1)}°C',
          notifId: 901,
          value: reading.temperature ?? 0,
          target: targetTemp,
          tolerance: kTempTolerance, maxDev: kTempMaxDeviation,
          customLow: tempThresholdLow, customHigh: tempThresholdHigh,
        );
        _checkAndNotifyZone(
          key: 'hum', sensorName: 'Humidity',
          readingStr: '${reading.humidity?.toStringAsFixed(0)}%',
          notifId: 902,
          value: reading.humidity ?? 0,
          target: targetHum,
          tolerance: kHumTolerance, maxDev: kHumMaxDeviation,
          customLow: humidityThresholdLow, customHigh: humidityThresholdHigh,
        );
        _checkAndNotifyZone(
          key: 'pres', sensorName: 'Pressure',
          readingStr: '${reading.pressure?.toStringAsFixed(0)} hPa',
          notifId: 903,
          value: reading.pressure ?? 0,
          target: targetPres,
          tolerance: kPresTolerance, maxDev: kPresMaxDeviation,
          customLow: pressureThresholdLow, customHigh: pressureThresholdHigh,
        );
      }

      if (mounted) setState(() => _apiError = null);
    } catch (e) {
      debugPrint('API poll error: $e');
      if (mounted) setState(() => _apiError = e.toString());
    }
  }

  /// Computes the zone (0=green,1=orange,2=red) for [value] and fires a
  /// notification only when the zone transitions. Cancels the notification
  /// when returning to green.
  void _checkAndNotifyZone({
    required String key,
    required String sensorName,
    required String readingStr,
    required int    notifId,
    required double value,
    required double target,
    required double tolerance,
    required double maxDev,
    required double customLow,
    required double customHigh,
  }) {
    // Compute zone using same logic as the gauge
    int zone;
    if (_useDefaultThresholds) {
      final diff = (value - target).abs();
      if (diff <= tolerance)   zone = 0; // green
      else if (diff <= maxDev) zone = 1; // orange
      else                     zone = 2; // red
    } else {
      if (value < customLow || value > customHigh) {
        zone = 2; // red — outside hard bounds
      } else if ((value - target).abs() <= tolerance) {
        zone = 0; // green
      } else {
        zone = 1; // orange
      }
    }

    final prev = _lastZone[key] ?? 0;
    if (zone == prev) return; // no change — don't spam
    _lastZone[key] = zone;

    if (zone == 0) {
      // Returned to green — cancel the alert silently
      localNotif.cancel(id: notifId);
      return;
    }

    final bool isRed = zone == 2;
    localNotif.show(
      id:    notifId,
      title: isRed
          ? 'LettuVault Alert 🔴 — Red Zone'
          : 'LettuVault Warning 🟠 — Orange Zone',
      body: isRed
          ? '$sensorName ($readingStr) has entered the Red Zone. Please check the LettuVault immediately!'
          : '$sensorName ($readingStr) is in the Orange Zone. LettuVault is outside the safe range.',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          isRed ? 'lettuvault_red_alerts' : 'lettuvault_orange_alerts',
          isRed ? 'LettuVault Critical Alerts' : 'LettuVault Warnings',
          importance: isRed ? Importance.max  : Importance.high,
          priority:   isRed ? Priority.max    : Priority.high,
          ongoing:        isRed,
          autoCancel:     !isRed,
          playSound:      true,
          enableVibration: true,
        ),
      ),
    );
  }

  Future<void> _initializeNotifications() async {
    // Android initialization
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS (Darwin) initialization
    // Request alert/badge/sound permission on iOS during initialization
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );

    await localNotif.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: null,
    );

    // Explicitly request Android 13+ POST_NOTIFICATIONS runtime permission.
    // If we don't ask, notifications will be silently blocked by the OS.
    final androidImplementation = localNotif.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();

    // Ask the user to disable battery optimizations for LettuVault so the OS doesn't
    // brutally kill the background service when the app is swiped away.
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    debugPrint('Notifications initialized (permissions requested)');
  }

  Future<Directory?> _getStorageDirectory() async {
    try {
      if (Platform.isAndroid) return await getExternalStorageDirectory();
      return await getApplicationDocumentsDirectory();
    } catch (e) {
      debugPrint('Storage unavailable: $e');
      return null;
    }
  }

  Future<void> _logToCSV(String sensor, double value) async {
    try {
      final directory = await _getStorageDirectory();
      if (directory == null) return;
      final file = File('${directory.path}/sensor_log.csv');
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      await file.writeAsString(
        '$timestamp, $sensor, ${value.toStringAsFixed(2)}\n',
        mode: FileMode.append,
      );
    } catch (e) {
      debugPrint("CSV Error: $e");
    }
  }

  void _updateHistory(List<SensorReading> hist, double val, {int maxLen = 30}) {
    hist.add(SensorReading(val, DateTime.now()));
    if (hist.length > maxLen) hist.removeAt(0);
  }

  double _updateBuffer(List<SensorReading> buffer, double val) {
    buffer.add(SensorReading(val, DateTime.now()));
    if (buffer.length > 5) buffer.removeAt(0);
    return buffer.isEmpty
        ? 0
        : buffer.map((e) => e.value).reduce((a, b) => a + b) / buffer.length;
  }

  // Public API for real sensor integrations: inject one or more sensor values.
  // Example: MainNavigationContainer.navKey.currentState?.injectSensorReadings(temp: 23.5);
  void injectSensorReadings({double? temp, double? hum, double? pres}) {
    setState(() {
      if (temp != null) {
        currentTemp = temp;
        avgT = _updateBuffer(tempBuffer, currentTemp);
        _updateHistory(tempHistory, currentTemp);
        _logToCSV("Temperature", currentTemp);
      }
      if (hum != null) {
        currentHum = hum;
        avgH = _updateBuffer(humidityBuffer, currentHum);
        _updateHistory(humidityHistory, currentHum);
        _logToCSV("Humidity", currentHum);
      }
      if (pres != null) {
        currentPres = pres;
        avgP = _updateBuffer(pressureBuffer, currentPres);
        _updateHistory(pressureHistory, currentPres);
        _logToCSV("Pressure", currentPres);
      }
    });
  }

  double _calcDangerLevel(double current, double target, double tol, double maxDev) {
    double diff = (current - target).abs();
    if (diff <= tol) return 0.0;
    if (diff >= maxDev) return 1.0;
    return (diff - tol) / (maxDev - tol);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(
        t: currentTemp,
        h: currentHum,
        p: currentPres,
        targetT: targetTemp,
        targetH: targetHum,
        targetP: targetPres,
        // Delta vs Target
        trendT: currentTemp - targetTemp,
        trendH: currentHum - targetHum,
        trendP: currentPres - targetPres,
        // Dynamic danger colors — use custom midpoint+halfrange when not default
        tempDanger: _useDefaultThresholds
            ? _calcDangerLevel(currentTemp, targetTemp, kTempTolerance, kTempMaxDeviation)
            : _calcDangerLevel(currentTemp, (tempThresholdLow + tempThresholdHigh) / 2,
                (tempThresholdHigh - tempThresholdLow) / 2,
                ((tempThresholdHigh - tempThresholdLow) / 2) + ((tempThresholdHigh - tempThresholdLow) / 2 * 0.2).clamp(1.0, 20.0)),
        humDanger: _useDefaultThresholds
            ? _calcDangerLevel(currentHum, targetHum, kHumTolerance, kHumMaxDeviation)
            : _calcDangerLevel(currentHum, (humidityThresholdLow + humidityThresholdHigh) / 2,
                (humidityThresholdHigh - humidityThresholdLow) / 2,
                ((humidityThresholdHigh - humidityThresholdLow) / 2) + ((humidityThresholdHigh - humidityThresholdLow) / 2 * 0.2).clamp(1.0, 20.0)),
        presDanger: _useDefaultThresholds
            ? _calcDangerLevel(currentPres, targetPres, kPresTolerance, kPresMaxDeviation)
            : _calcDangerLevel(currentPres, (pressureThresholdLow + pressureThresholdHigh) / 2,
                (pressureThresholdHigh - pressureThresholdLow) / 2,
                ((pressureThresholdHigh - pressureThresholdLow) / 2) + ((pressureThresholdHigh - pressureThresholdLow) / 2 * 0.2).clamp(1.0, 20.0)),
        // API status
        apiError: _apiError,
        apiPolling: _apiPollingEnabled,
      ),
      DetailScreen(
        title: "Temperature",
        val: currentTemp,
        avg: avgT,
        buffer: tempBuffer,
        historyBuffer: tempHistory,
        unit: "°C",
        color: Colors.redAccent,
        lowerThreshold: tempThresholdLow,
        upperThreshold: tempThresholdHigh,
        target: targetTemp,
        useDefaultThresholds: _useDefaultThresholds,
      ),
      DetailScreen(
        title: "Humidity",
        val: currentHum,
        avg: avgH,
        buffer: humidityBuffer,
        historyBuffer: humidityHistory,
        unit: "%",
        color: Colors.blueAccent,
        lowerThreshold: humidityThresholdLow,
        upperThreshold: humidityThresholdHigh,
        isLowCrit: true,
        target: targetHum,
        useDefaultThresholds: _useDefaultThresholds,
      ),
      DetailScreen(
        title: "Pressure",
        val: currentPres,
        avg: avgP,
        buffer: pressureBuffer,
        historyBuffer: pressureHistory,
        unit: "hPa",
        color: Colors.amber,
        lowerThreshold: pressureThresholdLow,
        upperThreshold: pressureThresholdHigh,
        target: targetPres,
        useDefaultThresholds: _useDefaultThresholds,
      ),
      const LogStatusScreen(),
    ];

    // Show first-time offline setup screen
    if (_showOfflineSetup) {
      return SetupOfflineScreen(onDone: () {
        setState(() => _showOfflineSetup = false);
        _startApiPolling();
        _performPostSetupTasks();
      });
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          drawer: _buildAppDrawer(context),
          body: screens[_selectedIndex],
          bottomNavigationBar: BottomNavigationBar(
            backgroundColor: Theme.of(context).cardColor,
            currentIndex: _selectedIndex,
            onTap: (i) => setState(() => _selectedIndex = i),
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Colors.grey.shade600,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
              BottomNavigationBarItem(icon: Icon(Icons.thermostat), label: "Temp"),
              BottomNavigationBarItem(icon: Icon(Icons.water_drop), label: "Humid"),
              BottomNavigationBarItem(icon: Icon(Icons.compress), label: "Pres"),
            ],
          ),
        ),

        // Splash shown during startup
        if (_isLoading)
          const Positioned.fill(child: SplashScreen()),

        // Full-screen loading while switching modes
        if (_isSwitchingMode)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.75),
              child: const Center(child: SplashScreen()),
            ),
          ),
      ],
    );
  }

  // ── Mode Switching Logic ─────────────────────────────────────────────────

  Future<void> _switchToOfflineMode() async {
    setState(() { _isSwitchingMode = true; _modeError = null; });
    try {
      final ssid = await SecureStorage.getPiSsid();
      final pass = await SecureStorage.getPiPassword();

      if (ssid == null || pass == null) {
        // No credentials saved — open setup screen
        setState(() { _isSwitchingMode = false; _showOfflineSetup = true; });
        return;
      }

      final connected = await WiFiForIoTPlugin.connect(
        ssid,
        password: pass,
        security: NetworkSecurity.WPA,
        joinOnce: false,
        withInternet: false,
      );

      if (!mounted) return;
      if (connected == true) {
        appModeNotifier.value = AppMode.offline;
        _startApiPolling();
        setState(() { _isSwitchingMode = false; _modeError = null; });
      } else {
        setState(() {
          _isSwitchingMode = false;
          _modeError = 'Could not connect to LettuVault AP. Make sure the Pi is powered on and nearby.';
        });
        _showModeErrorSnackbar();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSwitchingMode = false;
        _modeError = 'Connection error: ${e.toString()}';
      });
      _showModeErrorSnackbar();
    }
  }

  void _switchToOnlineMode() {
    appModeNotifier.value = AppMode.online;
    _startApiPolling();
    setState(() { _modeError = null; });
  }

  void _showModeErrorSnackbar() {
    if (!mounted || _modeError == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_modeError!),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _performPostSetupTasks() async {
    try {
      final available = await isAutoStartAvailable;
      if (available == true) {
        final prefs = await SharedPreferences.getInstance();
        final bool prompted = prefs.getBool('autoStartPrompted') ?? false;
        if (!prompted || prefs.getBool('v2Prompt') != true) {
          if (!mounted) return;
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Keep Alerts Running'),
              content: const Text(
                'To ensure you receive critical alerts when LettuVault is closed:\n\n'
                '1. We will open your "App Launch" settings.\n'
                '2. Find LettuVault in the list and turn it ON.\n'
                '3. Press Back to return here.',
                style: TextStyle(height: 1.5),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Skip')),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await getAutoStartPermission();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
          await prefs.setBool('autoStartPrompted', true);
          await prefs.setBool('v2Prompt', true);
        }
      }
    } catch (e) {
      debugPrint('[AutoStart] error: $e');
    }
  }

 Widget _buildAppDrawer(BuildContext context) {
  final isOffline = appModeNotifier.value == AppMode.offline;
  return Drawer(
    backgroundColor: Theme.of(context).colorScheme.surface,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header stays fixed at the top
        Padding(
          padding: const EdgeInsets.only(top: 60, left: 20, bottom: 20),
          child: Row(
            children: [
              Icon(Icons.settings, color: Theme.of(context).colorScheme.primary, size: 30),
              const SizedBox(width: 15),
              Text(
                "Settings",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        Divider(color: Theme.of(context).dividerColor),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Connection Mode Toggle ─────────────────────────
                        buildSectionHeader("Connection Mode"),
                        ValueListenableBuilder<AppMode>(
                          valueListenable: appModeNotifier,
                          builder: (context, mode, _) {
                            final isOffline = mode == AppMode.offline;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isOffline
                                    ? Colors.orange.withValues(alpha: 0.08)
                                    : Colors.blue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isOffline
                                      ? Colors.orange.withValues(alpha: 0.3)
                                      : Colors.blue.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isOffline ? Icons.wifi : Icons.cloud,
                                    color: isOffline ? Colors.orange : Colors.blue,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isOffline ? 'Offline Mode' : 'Online Mode',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.onSurface,
                                          ),
                                        ),
                                        Text(
                                          isOffline
                                              ? 'Connected to LettuVault AP'
                                              : 'Using cloud server',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: isOffline,
                                    activeColor: Colors.orange,
                                    inactiveTrackColor: Colors.blue.shade200,
                                    onChanged: (_) {
                                      Navigator.of(context).pop();
                                      if (isOffline) {
                                        _switchToOnlineMode();
                                      } else {
                                        _switchToOfflineMode();
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        Divider(color: Theme.of(context).dividerColor),
                        _buildAlertSwitch(),
                        _buildThemeSwitch(),
                        _buildClearLogsTile(context),
                        buildSectionHeader("System Config"),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: OutlinedButton.icon(
                              icon: Icon(_showSysConfig ? Icons.expand_less : Icons.settings,
                                  size: 18, color: Theme.of(context).colorScheme.primary),
                              label: Text(_showSysConfig ? 'Hide Settings' : 'Change Setting',
                                  style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => setState(() => _showSysConfig = !_showSysConfig),
                            ),
                          ),
                        ),
                        if (_showSysConfig) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Wrap(spacing: 8, runSpacing: 4, children: [
                              _buildPresetChip('Lettuce', Icons.eco, Colors.green),
                              _buildPresetChip('Strawberry', Icons.spa, Colors.red),
                              _buildPresetChip('Custom', Icons.tune, Colors.blueAccent),
                            ]),
                          ),
                          _buildSysConfigSlider("Target Temp", _sysConfigTemp, 0, 60, Colors.redAccent,
                              (v) => setState(() { _sysConfigTemp = v; _selectedPreset = 'Custom'; })),
                          _buildSysConfigSlider("Target Humid", _sysConfigHum, 50, 100, Colors.blueAccent,
                              (v) => setState(() { _sysConfigHum = v; _selectedPreset = 'Custom'; })),
                          _buildSysConfigSlider("Target Pres", _sysConfigPres, 800, 1100, Colors.amber,
                              (v) => setState(() { _sysConfigPres = v; _selectedPreset = 'Custom'; })),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                            child: Text('\u26a0 System Config is UI-only. Backend changes not applied yet.',
                              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
                          ),
                        ],


                        Divider(color: Theme.of(context).dividerColor),

                        // ─── ALERT THRESHOLDS ────────────────────────────────
                        // These bounds control when the mobile app sends you
                        // a notification. They are independent of System Config.
                        buildSectionHeader("Alert Thresholds"),
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
                          child: Text(
                            'Set the reading bounds that trigger a push notification. '
                            'Independent of System Config.',
                            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.auto_awesome, color: Colors.blueAccent),
                          title: Text("Auto-derive from Target", style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                          subtitle: Text(
                            "Alert when reading exceeds target ± max deviation",
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12),
                          ),
                          trailing: Switch(
                            value: _useDefaultThresholds,
                            onChanged: (v) {
                              setState(() {
                                _useDefaultThresholds = v;
                                if (!v) {
                                  _draftTempLow = tempThresholdLow;
                                  _draftTempHigh = tempThresholdHigh;
                                  _draftHumLow = humidityThresholdLow;
                                  _draftHumHigh = humidityThresholdHigh;
                                  _draftPresLow = pressureThresholdLow;
                                  _draftPresHigh = pressureThresholdHigh;
                                  _thresholdError = null;
                                }
                              });
                              _saveBool('useDefaultThresholds', v);
                              _fetchLatestFromApi();
                            },
                            activeColor: Colors.blueAccent,
                          ),
                        ),

                        if (!_useDefaultThresholds) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                            child: Text(
                              'Adjust then tap Save. Target must be inside your Low–High range.',
                              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                            ),
                          ),
                          _buildThresholdSlider("Temp Low", _draftTempLow, -40, 60, Colors.redAccent,
                              (v) => setState(() { _draftTempLow = v; _thresholdError = null; })),
                          _buildThresholdSlider("Temp High", _draftTempHigh, -40, 60, Colors.redAccent,
                              (v) => setState(() { _draftTempHigh = v; _thresholdError = null; })),
                          _buildThresholdSlider("Humid Low", _draftHumLow, 0, 100, Colors.blueAccent,
                              (v) => setState(() { _draftHumLow = v; _thresholdError = null; })),
                          _buildThresholdSlider("Humid High", _draftHumHigh, 0, 100, Colors.blueAccent,
                              (v) => setState(() { _draftHumHigh = v; _thresholdError = null; })),
                          _buildThresholdSlider("Pres Low", _draftPresLow, 750, 1100, Colors.amber,
                              (v) => setState(() { _draftPresLow = v; _thresholdError = null; })),
                          _buildThresholdSlider("Pres High", _draftPresHigh, 750, 1100, Colors.amber,
                              (v) => setState(() { _draftPresHigh = v; _thresholdError = null; })),

                          if (_thresholdError != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                                ),
                                child: Text(_thresholdError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                              ),
                            ),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.save_rounded, size: 18),
                                label: const Text('Save Custom Thresholds'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: _saveCustomThresholds,
                              ),
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 20),
                      ],


            ),
          ),
        ),

        // 3. About Button pinned to bottom
        Divider(color: Theme.of(context).dividerColor, height: 1),
        _buildAboutButton(context),
      ],
    ),
  );
}

  Widget _buildAlertSwitch() {
    return ListTile(
      leading: const Icon(Icons.notifications_active, color: Colors.grey),
      title: Text(
        "Critical Alerts", 
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      trailing: Tooltip(
        message: "Toggle critical threshold notifications",
        child: Switch(
          value: _alertsEnabled,
          onChanged: (val) => setState(() => _alertsEnabled = val),
          activeThumbColor: Colors.blueAccent.withValues(alpha: 0.5),
          // activeColor: Colors.blueAccent.withValues(alpha: 0.5), // Softens the track color
          inactiveThumbColor: Colors.grey,
          inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  Widget _buildThemeSwitch() {
    return ListTile(
      leading: Icon(Icons.brightness_6, color: Theme.of(context).colorScheme.primary),
      title: Text('Dark Mode', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
      trailing: Switch(
        value: _isDarkMode,
        onChanged: (v) {
          setState(() {
            _isDarkMode = v;
            themeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
            _saveThemePreference(v);
          });
        },
        activeColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildClearLogsTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.delete_sweep, color: Colors.redAccent),
      title: Text(
        "Clear Sensor Logs",
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      onTap: () async {
        try {
          final directory = await _getStorageDirectory();
          if (directory == null) throw Exception('Storage unavailable');
          final file = File('${directory.path}/sensor_log.csv');
          if (await file.exists()) await file.delete();
          if (!mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Logs cleared successfully")),
          );
        } catch (e) {
          debugPrint("Delete Error: $e");
        }
      },
    );
  }


  Widget _buildThresholdSlider(
    String label,
    double val,
    double min,
    double max,
    Color color,
    ValueChanged<double> onCh,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ${val.toStringAsFixed(0)}",
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12),
          ),
          Slider(
            value: val,
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            activeColor: color,
            onChanged: onCh,
          ),
        ],
      ),
    );
  }

  // --- Validates drafts and commits them to the live alert threshold variables ---
  void _saveCustomThresholds() {
    // 1. Low must be strictly less than High
    if (_draftTempLow >= _draftTempHigh) {
      setState(() => _thresholdError = 'Temp Low (${_draftTempLow.toStringAsFixed(0)}) must be less than Temp High (${_draftTempHigh.toStringAsFixed(0)}).');
      return;
    }
    if (_draftHumLow >= _draftHumHigh) {
      setState(() => _thresholdError = 'Humid Low (${_draftHumLow.toStringAsFixed(0)}) must be less than Humid High (${_draftHumHigh.toStringAsFixed(0)}).');
      return;
    }
    if (_draftPresLow >= _draftPresHigh) {
      setState(() => _thresholdError = 'Pres Low (${_draftPresLow.toStringAsFixed(0)}) must be less than Pres High (${_draftPresHigh.toStringAsFixed(0)}).');
      return;
    }
    // 2. The current target (setpoint) must sit inside the custom range so the
    //    green zone (target ± tolerance) makes sense within the orange zone.
    if (targetTemp <= _draftTempLow || targetTemp >= _draftTempHigh) {
      setState(() => _thresholdError =
          'Target temp (${targetTemp.toStringAsFixed(1)}°C) must be inside your range '
          '[${_draftTempLow.toStringAsFixed(0)} – ${_draftTempHigh.toStringAsFixed(0)}].');
      return;
    }
    if (targetHum <= _draftHumLow || targetHum >= _draftHumHigh) {
      setState(() => _thresholdError =
          'Target humidity (${targetHum.toStringAsFixed(1)}%) must be inside your range '
          '[${_draftHumLow.toStringAsFixed(0)} – ${_draftHumHigh.toStringAsFixed(0)}].');
      return;
    }
    if (targetPres <= _draftPresLow || targetPres >= _draftPresHigh) {
      setState(() => _thresholdError =
          'Target pressure (${targetPres.toStringAsFixed(1)} hPa) must be inside your range '
          '[${_draftPresLow.toStringAsFixed(0)} – ${_draftPresHigh.toStringAsFixed(0)}].');
      return;
    }

    // All valid — commit and persist
    setState(() {
      tempThresholdLow = _draftTempLow;
      tempThresholdHigh = _draftTempHigh;
      humidityThresholdLow = _draftHumLow;
      humidityThresholdHigh = _draftHumHigh;
      pressureThresholdLow = _draftPresLow;
      pressureThresholdHigh = _draftPresHigh;
      _thresholdError = null;
    });
    _saveThreshold('tempThresholdLow', tempThresholdLow);
    _saveThreshold('tempThresholdHigh', tempThresholdHigh);
    _saveThreshold('humidityThresholdLow', humidityThresholdLow);
    _saveThreshold('humidityThresholdHigh', humidityThresholdHigh);
    _saveThreshold('pressureThresholdLow', pressureThresholdLow);
    _saveThreshold('pressureThresholdHigh', pressureThresholdHigh);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Custom alert thresholds saved!'),
        backgroundColor: Colors.blueAccent,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // --- Preset chip builder ---
  Widget _buildPresetChip(String label, IconData icon, Color color) {
    final bool selected = _selectedPreset == label;
    return FilterChip(
      avatar: Icon(icon, size: 16, color: selected ? Colors.white : color),
      label: Text(label, style: TextStyle(color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface, fontSize: 12)),
      selected: selected,
      selectedColor: color,
      backgroundColor: Theme.of(context).cardColor,
      checkmarkColor: Colors.white,
      side: BorderSide(color: selected ? color : Theme.of(context).dividerColor),
      onSelected: (_) {
        setState(() {
          _selectedPreset = label;
          if (label == 'Lettuce') {
            _sysConfigTemp = 15.0;
            _sysConfigHum = 95.0;
            _sysConfigPres = 900.0;
          } else if (label == 'Strawberry') {
            _sysConfigTemp = 20.0;
            _sysConfigHum = 90.0;
            _sysConfigPres = 1010.0;
          }
          // 'Custom' just keeps current slider values
        });
      },
    );
  }

  // --- System Config slider (distinct style from alert slider) ---
  Widget _buildSysConfigSlider(String label, double val, double min, double max, Color color, ValueChanged<double> onCh) {
    String unit = label.contains('Temp') ? '°C' : label.contains('Humid') ? '%' : ' hPa';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12)),
              Text('${val.toStringAsFixed(0)}$unit', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 3),
            child: Slider(
              value: val,
              min: min,
              max: max,
              divisions: (max - min).toInt(),
              activeColor: color,
              onChanged: onCh,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutButton(BuildContext context) {
    return Tooltip(
      message: "View app information and team credits",
      // Adding waitDuration makes it feel more responsive on desktop/web
      // while long-press works natively for mobile.
      child: GestureDetector(
        onTap: () => showAppAboutDialog(context),
        child: const Padding(
          padding: EdgeInsets.all(20.0),
          child: Row(
            children: [
              Text(
                "LettuVault v1.1.5",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              Spacer(),
              Icon(Icons.info_outline, color: Colors.blueAccent, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
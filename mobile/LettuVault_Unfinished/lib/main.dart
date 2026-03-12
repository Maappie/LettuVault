import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/models/sensor_reading.dart';
import 'src/screens/home_screen.dart';
import 'src/screens/detail_screen.dart';
import 'src/screens/log_status_screen.dart';
import 'src/widgets/helpers.dart';
import 'src/integration/sensor_network_adapter.dart';

final FlutterLocalNotificationsPlugin localNotif =
    FlutterLocalNotificationsPlugin();

// Global theme notifier so screens can toggle theme at runtime
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() {
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
        // Use a GlobalKey so external code (sensor integration) can inject readings
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
  bool _tempAlertSent = false;
  bool _humidityAlertSent = false;
  bool _pressureAlertSent = false;
  bool _alertsEnabled = true;

  // UI theme state
  bool _isDarkMode = false;
  // Show startup loading screen until async initialization completes
  bool _isLoading = true;

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

  // Current computed Vapor Pressure Deficit
  double currentVPD = 0.0;

  // NOTE: use the _Low/_High threshold pairs above for alerts and UI sliders
  double updateInterval = 5.0;
  double simulationAmplitude = 2.1;

  // When true the timer will modify sensor values with simulated noise.
  // Set to false to feed real sensor data via `injectSensorReadings(...)`.
  bool _simulateSensors = true; 

  // Network adapter (optional) — polls an external API and injects readings
  SensorNetworkAdapter? _networkAdapter;
  bool _adapterRunning = false;
  String _adapterUrl = 'http://10.0.2.2:5000/sensor';

  List<SensorReading> tempBuffer = [];
  List<SensorReading> humidityBuffer = [];
  List<SensorReading> pressureBuffer = [];

  double currentTemp = 25.0, currentHum = 60.0, currentPres = 1013.0;
  double avgT = 25.0, avgH = 60.0, avgP = 1013.0;
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

    // start the periodic timer after initial state is restored
    _startTimer();

    // keep the splash visible for a short, pleasant duration
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  // --- Persistence for thresholds using shared_preferences
  Future<void> _loadSavedThresholds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
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

  @override
  void dispose() {
    _networkAdapter?.stop();
    _timer?.cancel();
    super.dispose();
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

    // Android 13+ POST_NOTIFICATIONS is declared in the manifest; if your
    // device still blocks notifications you will need to grant the runtime
    // permission from system settings or add a runtime-permission flow
    // (e.g. using permission_handler) — keeping this simple for now.
    debugPrint('Notifications initialized (check device permissions if blocked)');
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: (updateInterval * 1000).toInt()),
      (t) => _processSensorData(),
    );
  }

  Future<Directory?> _getStorageDirectory() async {
    try {
      if (Platform.isAndroid) return await getExternalStorageDirectory();
      // For iOS and desktop fall back to application documents directory
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
      String timestamp =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      await file.writeAsString(
        '$timestamp, $sensor, ${value.toStringAsFixed(2)}\n',
        mode: FileMode.append,
      );
    } catch (e) {
      debugPrint("CSV Error: $e");
    }
  }

  void _processSensorData() {
    // If simulation is disabled the timer does nothing; external code should
    // call `injectSensorReadings` to feed real sensor values.
    if (!_simulateSensors) return;

    setState(() {
      currentTemp += (Random().nextDouble() - 0.5) * simulationAmplitude;
      currentHum += (Random().nextDouble() - 0.5) * simulationAmplitude;
      currentPres += (Random().nextDouble() - 0.5) * simulationAmplitude;

      // update live buffers (last 5)
      avgT = _updateBuffer(tempBuffer, currentTemp);
      avgH = _updateBuffer(humidityBuffer, currentHum);
      avgP = _updateBuffer(pressureBuffer, currentPres);

      // update history buffers (last 30)
      _updateHistory(tempHistory, currentTemp);
      _updateHistory(humidityHistory, currentHum);
      _updateHistory(pressureHistory, currentPres);

      // compute current VPD
      currentVPD = _computeVPD(currentTemp, currentHum);

      _logToCSV("Temperature", currentTemp);
      _logToCSV("Humidity", currentHum);
      _logToCSV("Pressure", currentPres);

      if (_alertsEnabled) {
        _checkAlerts();
      }
    });
  }

  void _updateHistory(List<SensorReading> hist, double val, {int maxLen = 30}) {
    hist.add(SensorReading(val, DateTime.now()));
    if (hist.length > maxLen) hist.removeAt(0);
  }

  double _computeVPD(double tempC, double rhPercent) {
    // es(T) = 0.61078 * exp((17.27 * T) / (T + 237.3))
    final es = 0.61078 * exp((17.27 * tempC) / (tempC + 237.3));
    final vpd = es * (1 - (rhPercent / 100.0));
    return double.parse(vpd.toStringAsFixed(3));
  }

  void _checkAlerts() {
    // Temperature Alert (high/low)
    if ((currentTemp > tempThresholdHigh || currentTemp < tempThresholdLow) && !_tempAlertSent) {
      String direction = currentTemp > tempThresholdHigh ? "High" : "Low";
      _showThresholdAlert("$direction Temperature: ${currentTemp.toStringAsFixed(1)}°C");
      _tempAlertSent = true;
    } else if (currentTemp <= tempThresholdHigh - 1.0 && currentTemp >= tempThresholdLow + 1.0) {
      _tempAlertSent = false;
    }

    // Humidity Alert (low/high)
    if ((currentHum > humidityThresholdHigh || currentHum < humidityThresholdLow) && !_humidityAlertSent) {
      String direction = currentHum > humidityThresholdHigh ? "High" : "Low";
      _showThresholdAlert("$direction Humidity: ${currentHum.toStringAsFixed(1)}%");
      _humidityAlertSent = true;
    } else if (currentHum <= humidityThresholdHigh - 1.0 && currentHum >= humidityThresholdLow + 1.0) {
      _humidityAlertSent = false;
    }

    // Pressure Alert (high/low)
    if ((currentPres > pressureThresholdHigh || currentPres < pressureThresholdLow) && !_pressureAlertSent) {
      String direction = currentPres > pressureThresholdHigh ? "High" : "Low";
      _showThresholdAlert("$direction Pressure: ${currentPres.toStringAsFixed(1)} hPa");
      _pressureAlertSent = true;
    } else if (currentPres <= pressureThresholdHigh - 1.0 && currentPres >= pressureThresholdLow + 1.0) {
      _pressureAlertSent = false;
    }
  }

  Future<void> _showThresholdAlert(String body) async {
    const androidDetails = AndroidNotificationDetails(
      'critical_alerts',
      'Sensor Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );
    await localNotif.show(
      id: Random().nextInt(1000),
      title: 'LettuVault Warning',
      body: body,
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
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

      // recompute derived metric
      currentVPD = _computeVPD(currentTemp, currentHum);

      if (_alertsEnabled) _checkAlerts();
    });
  }

  void setSimulationEnabled(bool enabled) => setState(() => _simulateSensors = enabled);

  void _startNetworkAdapter() {
    // create adapter (uses current updateInterval as default polling interval)
    _networkAdapter?.stop();
    _networkAdapter = SensorNetworkAdapter(
      url: _adapterUrl,
      intervalSeconds: updateInterval.toInt().clamp(1, 60),
      onData: (t, h, p) {
        MainNavigationContainer.navKey.currentState?.injectSensorReadings(
          temp: t,
          hum: h,
          pres: p,
        );
      },
    );
    _networkAdapter!.start();
    setState(() {
      _adapterRunning = true;
      // disable simulation when external adapter is running
      _simulateSensors = false;
    });
  }

  void _stopNetworkAdapter() {
    _networkAdapter?.stop();
    setState(() => _adapterRunning = false);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(
        t: currentTemp,
        h: currentHum,
        p: currentPres,
        at: avgT,
        ah: avgH,
        ap: avgP,
        vpd: currentVPD,
        // Trends (difference vs oldest sample in buffer)
        trendT: tempBuffer.isNotEmpty ? (currentTemp - tempBuffer.first.value) : 0.0,
        trendH: humidityBuffer.isNotEmpty ? (currentHum - humidityBuffer.first.value) : 0.0,
        trendP: pressureBuffer.isNotEmpty ? (currentPres - pressureBuffer.first.value) : 0.0,
        // pass critical flags so Home can color cards
        isTempCritical: (currentTemp > tempThresholdHigh || currentTemp < tempThresholdLow),
        isHumCritical: (currentHum > humidityThresholdHigh || currentHum < humidityThresholdLow),
        isPresCritical: (currentPres > pressureThresholdHigh || currentPres < pressureThresholdLow),
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
      ),
      const LogStatusScreen(),
    ];

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

        if (_isLoading)
          Positioned.fill(
            child: buildLoadingScreen(context),
          ),
      ],
    );
  }

 Widget _buildAppDrawer(BuildContext context) {
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
                        _buildAlertSwitch(),
                        _buildThemeSwitch(),
                        _buildClearLogsTile(context),
                        buildSectionHeader("Simulation Control"),
                _buildTimerSlider(),
                _buildAmplitudeSlider(),

                // Simulation toggle (expose the existing flag in the UI)
                ListTile(
                  leading: const Icon(Icons.play_arrow, color: Colors.greenAccent),
                  title: Text("Enable Simulation", style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  trailing: Switch(
                    value: _simulateSensors,
                    onChanged: (v) => setSimulationEnabled(v),
                    activeColor: Colors.greenAccent,
                  ),
                ),

                // External network adapter control
                ListTile(
                  leading: const Icon(Icons.cloud, color: Colors.blueAccent),
                  title: Text("Network Adapter", style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  subtitle: Text(
                    _adapterRunning ? 'Running ($_adapterUrl)' : 'Stopped — default: http://10.0.2.2:5000/sensor',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 12),
                  ),
                  trailing: Switch(
                    value: _adapterRunning,
                    onChanged: (v) {
                      if (v) {
                        _startNetworkAdapter();
                      } else {
                        _stopNetworkAdapter();
                      }
                    },
                    activeColor: Colors.blueAccent,
                  ),
                ),

                Divider(color: Theme.of(context).dividerColor),
                buildSectionHeader("Alert Thresholds"),

                // Temperature
                _buildThresholdSlider("Temp (Low)", tempThresholdLow, -40, 40, Colors.red,
                    (v) {
                      setState(() => tempThresholdLow = v);
                      _saveThreshold('tempThresholdLow', v);
                    }),
                _buildThresholdSlider("Temp (High)", tempThresholdHigh, -20, 60, Colors.red,
                    (v) {
                      setState(() => tempThresholdHigh = v);
                      _saveThreshold('tempThresholdHigh', v);
                    }),

                // Humidity
                _buildThresholdSlider("Humid (Low)", humidityThresholdLow, 0, 100, Colors.blue,
                    (v) {
                      setState(() => humidityThresholdLow = v);
                      _saveThreshold('humidityThresholdLow', v);
                    }),
                _buildThresholdSlider("Humid (High)", humidityThresholdHigh, 0, 100, Colors.blue,
                    (v) {
                      setState(() => humidityThresholdHigh = v);
                      _saveThreshold('humidityThresholdHigh', v);
                    }),

                // Pressure
                _buildThresholdSlider("Pres (Low)", pressureThresholdLow, 750, 1100, Colors.amber,
                    (v) {
                      setState(() => pressureThresholdLow = v);
                      _saveThreshold('pressureThresholdLow', v);
                    }),
                _buildThresholdSlider("Pres (High)", pressureThresholdHigh, 900, 1400, Colors.amber,
                    (v) {
                      setState(() => pressureThresholdHigh = v);
                      _saveThreshold('pressureThresholdHigh', v);
                    }),
                
                const SizedBox(height: 20), // Padding at the bottom of scroll
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

  Widget _buildTimerSlider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Update every: ${updateInterval.toStringAsFixed(1)}s",
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12),
          ),
          Slider(
            value: updateInterval,
            min: 0.5,
            max: 10.0,
            divisions: 19,
            activeColor: Colors.greenAccent,
            onChanged: (val) => setState(() => updateInterval = val),
            onChangeEnd: (val) => _startTimer(),
          ),
        ],
      ),
    );
  }

  Widget _buildAmplitudeSlider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Amplitude: ${simulationAmplitude.toStringAsFixed(2)}",
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12),
          ),
          Slider(
            value: simulationAmplitude,
            min: 0.0,
            max: 10.0,
            divisions: 50,
            activeColor: Colors.orangeAccent,
            onChanged: (val) => setState(() => simulationAmplitude = val),
          ),
        ],
      ),
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
import 'dart:async';

import 'package:auto_start_flutter/auto_start_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_new_app/src/core/app_mode.dart';
import 'package:my_new_app/src/core/constants.dart';
import 'package:my_new_app/src/core/secure_storage.dart';
import 'package:my_new_app/features/splash/screens/splash_screen.dart';
import 'package:my_new_app/features/setup/screens/setup_offline_screen.dart';
import 'package:my_new_app/features/logs/screens/log_status_screen.dart';
import 'package:my_new_app/features/onboarding/screens/onboarding_flow_screen.dart';

import 'package:my_new_app/features/dashboard/screens/dashboard_screen.dart';
import 'package:my_new_app/features/settings/screens/settings_drawer.dart';
import 'package:my_new_app/features/settings/controllers/settings_controller.dart';
import 'package:my_new_app/services/connectivity_service.dart';
import 'package:my_new_app/services/notification_service.dart';
import 'package:my_new_app/services/sensor_polling_service.dart';

import 'package:my_new_app/features/detail/screens/sensor_detail_screen.dart';

/// MainNavigator — root navigation widget.
///
/// Owns:
///  - The bottom navigation bar + screen list
///  - Startup loading / offline setup overlays
///  - Mode-switching loading overlay
///  - Background service subscription
///
/// All business logic is delegated to the service singletons:
///   [SensorPollingService], [ConnectivityService],
///   [NotificationService], [SettingsController]
class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  static final GlobalKey<MainNavigatorState> navKey =
      GlobalKey<MainNavigatorState>();

  @override
  State<MainNavigator> createState() => MainNavigatorState();
}

class MainNavigatorState extends State<MainNavigator> {
  int _selectedIndex = 0;
  bool _isLoading    = true;
  bool _showOnboarding   = false;
  bool _showOfflineSetup = false;
  bool _isSwitchingMode  = false;
  bool _cancelConnection = false;

  final _polling = SensorPollingService.instance;
  final _settings = SettingsController.instance;

  @override
  void initState() {
    super.initState();
    _performStartup();
  }

  @override
  void dispose() {
    _polling.stop();
    super.dispose();
  }

  // ── Startup ────────────────────────────────────────────────────────────

  Future<void> _performStartup() async {
    setState(() => _isLoading = true);

    try {
      await NotificationService.instance.initialize();
    } catch (_) {}

    await _settings.loadSavedThresholds();
    await _settings.loadTheme();
    await SecureStorage.seedDefaultsIfNeeded();

    await _polling.start();

    // Subscribe to background isolate readings (offline mode)
    try {
      FlutterBackgroundService().on('sensorReading').listen((data) {
        if (data == null || !mounted) return;
        if (appModeNotifier.value == AppMode.online) return;
        _polling.inject(
          temp: (data['temperature'] as num?)?.toDouble(),
          hum:  (data['humidity']   as num?)?.toDouble(),
          pres: (data['pressure']   as num?)?.toDouble(),
        );
      });
    } catch (e) {
      debugPrint('[BG] Subscribe error: $e');
    }

    // Check onboarding completion — first-run wizard replaces old setup check
    final onboardingDone = await SecureStorage.isOnboardingDone();
    if (!onboardingDone && mounted) {
      setState(() { _isLoading = false; _showOnboarding = true; });
      return;
    }

    // Restore persisted mode
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('app_mode') == 'offline') {
      appModeNotifier.value = AppMode.offline;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    _promptAutoStart();
  }

  // ── Mode switching ─────────────────────────────────────────────────────

  Future<void> _handleModeSwitch() async {
    final current = appModeNotifier.value;
    if (current == AppMode.offline) {
      ConnectivityService.instance.switchToOnline();
      await _polling.start();
    } else {
      await _switchOffline();
    }
  }

  Future<void> _switchOffline() async {
    setState(() { _isSwitchingMode = true; _cancelConnection = false; });
    final error = await ConnectivityService.instance.switchToOffline(
      isCancelled: () => _cancelConnection,
    );
    if (!mounted) return;
    if (error == 'no_credentials') {
      setState(() { _isSwitchingMode = false; _showOfflineSetup = true; });
    } else if (error != null) {
      setState(() => _isSwitchingMode = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ));
    } else if (!_cancelConnection) {
      await _polling.start();
      setState(() => _isSwitchingMode = false);
    } else {
      setState(() => _isSwitchingMode = false);
    }
  }

  // ── AutoStart prompt (Chinese ROMs) ───────────────────────────────────

  Future<void> _promptAutoStart() async {
    try {
      final available = await isAutoStartAvailable;
      if (available != true) return;
      final prefs = await SharedPreferences.getInstance();
      final prompted = prefs.getBool('autoStartPrompted') ?? false;
      if (prompted && prefs.getBool('v2Prompt') == true) return;
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
              onPressed: () => Navigator.pop(context),
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
    } catch (e) {
      debugPrint('[AutoStart] error: $e');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // First-time onboarding overlay
    if (_showOnboarding) {
      return OnboardingFlowScreen(onComplete: () async {
        setState(() => _showOnboarding = false);
        await _polling.start();
        _promptAutoStart();
      });
    }

    // Re-configure offline credentials (from Settings drawer)
    if (_showOfflineSetup) {
      return SetupOfflineScreen(onDone: () async {
        setState(() => _showOfflineSetup = false);
        await _polling.start();
        _promptAutoStart();
      });
    }

    return ListenableBuilder(
      listenable: _polling,
      builder: (context, _) {
        final s = _polling.state;
        final screens = _buildScreens(s);

        return Stack(
          fit: StackFit.expand,
          children: [
            Scaffold(
              drawer: SettingsDrawer(
                onSwitchMode: _handleModeSwitch,
                onShowOfflineSetup: () => setState(() => _showOfflineSetup = true),
              ),
              body: screens[_selectedIndex],
              bottomNavigationBar: _BottomNav(
                selectedIndex: _selectedIndex,
                onTap: (i) => setState(() => _selectedIndex = i),
              ),
            ),
            if (_isLoading) const Positioned.fill(child: SplashScreen()),
            if (_isSwitchingMode)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.85),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SplashScreen(),
                      const SizedBox(height: 24),
                      TextButton.icon(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        label: const Text('Cancel Connection',
                            style: TextStyle(color: Colors.white70, fontSize: 16)),
                        onPressed: () => setState(() {
                          _cancelConnection = true;
                          _isSwitchingMode = false;
                        }),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _buildScreens(SensorState s) {
    double calcDanger(double current, double target, double tol, double maxDev) {
      final diff = (current - target).abs();
      if (diff <= tol) return 0.0;
      if (diff >= maxDev) return 1.0;
      return (diff - tol) / (maxDev - tol);
    }

    return [
      DashboardScreen(
        t: s.temp, h: s.hum, p: s.pres,
        targetT: s.targetTemp, targetH: s.targetHum, targetP: s.targetPres,
        trendT: s.temp - s.targetTemp,
        trendH: s.hum  - s.targetHum,
        trendP: s.pres - s.targetPres,
        tempDanger: calcDanger(s.temp, s.targetTemp, kTempTolerance, kTempMaxDeviation),
        humDanger:  calcDanger(s.hum,  s.targetHum,  kHumTolerance,  kHumMaxDeviation),
        presDanger: calcDanger(s.pres, s.targetPres, kPresTolerance, kPresMaxDeviation),
        apiError:      s.apiError,
        apiPolling:    true,
        systemStandby: s.systemStandby,
      ),
      SensorDetailScreen(
        key: const ValueKey('temp_screen'),
        title: 'Temperature', val: s.temp, avg: s.avgT,
        buffer: s.tempBuffer, historyBuffer: s.tempHistory,
        unit: '°C', color: Colors.redAccent,
        lowerThreshold: s.tempThresholdLow, upperThreshold: s.tempThresholdHigh,
        target: s.targetTemp,
        useDefaultThresholds: _settings.useDefaultThresholds,
      ),
      SensorDetailScreen(
        key: const ValueKey('humid_screen'),
        title: 'Humidity', val: s.hum, avg: s.avgH,
        buffer: s.humBuffer, historyBuffer: s.humHistory,
        unit: '%', color: Colors.blueAccent, isLowCrit: true,
        lowerThreshold: s.humThresholdLow, upperThreshold: s.humThresholdHigh,
        target: s.targetHum,
        useDefaultThresholds: _settings.useDefaultThresholds,
      ),
      SensorDetailScreen(
        key: const ValueKey('pres_screen'),
        title: 'Pressure', val: s.pres, avg: s.avgP,
        buffer: s.presBuffer, historyBuffer: s.presHistory,
        unit: 'hPa', color: Colors.amber,
        lowerThreshold: s.presThresholdLow, upperThreshold: s.presThresholdHigh,
        target: s.targetPres,
        useDefaultThresholds: _settings.useDefaultThresholds,
      ),
      const LogStatusScreen(),
    ];
  }
}

// ── Bottom navigation bar ─────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mode indicator strip
        ValueListenableBuilder<AppMode>(
          valueListenable: appModeNotifier,
          builder: (context, mode, _) {
            final isOffline = mode == AppMode.offline;
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: isOffline
                  ? Colors.orange.withValues(alpha: 0.12)
                  : Colors.blue.withValues(alpha: 0.08),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isOffline ? Icons.wifi : Icons.cloud,
                    size: 12,
                    color: isOffline ? Colors.orange : Colors.blue,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isOffline ? 'Local' : 'Remote',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isOffline ? Colors.orange : Colors.blue,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        BottomNavigationBar(
          backgroundColor: Theme.of(context).cardColor,
          currentIndex: selectedIndex,
          onTap: onTap,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey.shade600,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home),       label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.thermostat), label: 'Temp'),
            BottomNavigationBarItem(icon: Icon(Icons.water_drop), label: 'Humid'),
            BottomNavigationBarItem(icon: Icon(Icons.compress),   label: 'Pres'),
          ],
        ),
      ],
    );
  }
}

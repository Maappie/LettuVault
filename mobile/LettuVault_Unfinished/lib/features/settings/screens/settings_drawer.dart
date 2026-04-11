import 'dart:io';

import 'package:flutter/material.dart';

import 'package:my_new_app/features/settings/controllers/settings_controller.dart';
import 'package:my_new_app/features/settings/widgets/connection_mode_tile.dart';
import 'package:my_new_app/features/settings/widgets/threshold_sliders.dart';
import 'package:my_new_app/features/settings/widgets/sys_config_panel.dart';
import 'package:my_new_app/services/csv_logger_service.dart';
import 'package:my_new_app/shared/widgets/metric_card.dart';
import 'package:my_new_app/shared/widgets/about_dialog.dart';

/// SettingsDrawer — the app-wide settings panel.
///
/// Accepts callbacks for actions that require navigator-level access
/// (showing the offline setup screen, switching mode).
class SettingsDrawer extends StatelessWidget {
  final VoidCallback onSwitchMode;
  final VoidCallback onShowOfflineSetup;

  const SettingsDrawer({
    super.key,
    required this.onSwitchMode,
    required this.onShowOfflineSetup,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = SettingsController.instance;
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 60, left: 20, bottom: 20),
            child: Row(
              children: [
                Icon(Icons.settings,
                    color: Theme.of(context).colorScheme.primary, size: 30),
                const SizedBox(width: 15),
                Text(
                  'Settings',
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

          // ── Scrollable body ───────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: ctrl,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Connection mode
                    SectionHeader('Connection Mode'),
                    ConnectionModeTile(onToggle: () {
                      Navigator.of(context).pop();
                      onSwitchMode();
                    }),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                      leading: Icon(Icons.router,
                          color: Theme.of(context).colorScheme.primary, size: 22),
                      title: const Text('Offline Mode Setting',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Update Raspberry Pi Wi-Fi credentials',
                          style: TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () {
                        Navigator.of(context).pop();
                        onShowOfflineSetup();
                      },
                    ),

                    Divider(color: Theme.of(context).dividerColor),

                    // Toggles
                    _AlertSwitch(ctrl: ctrl),
                    _ThemeSwitch(ctrl: ctrl),
                    _ClearLogsTile(),

                    // System Config
                    SectionHeader('System Config'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: OutlinedButton.icon(
                          icon: Icon(
                            ctrl.showSysConfig ? Icons.expand_less : Icons.settings,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          label: Text(
                            ctrl.showSysConfig ? 'Hide Settings' : 'Change Setting',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.primary),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.5),
                            ),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: ctrl.toggleSysConfig,
                        ),
                      ),
                    ),
                    if (ctrl.showSysConfig) const SysConfigPanel(),

                    Divider(color: Theme.of(context).dividerColor),

                    // Alert Thresholds
                    SectionHeader('Alert Thresholds'),
                    Padding(
                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
                      child: Text(
                        'Set the reading bounds that trigger a push notification. '
                        'Independent of System Config.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.auto_awesome, color: Colors.blueAccent),
                      title: Text('Auto-derive from Target',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface)),
                      subtitle: Text(
                        'Alert when reading exceeds target ± max deviation',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                      trailing: Switch(
                        value: ctrl.useDefaultThresholds,
                        activeColor: Colors.blueAccent,
                        onChanged: (v) => ctrl.setUseDefaultThresholds(v),
                      ),
                    ),
                    if (!ctrl.useDefaultThresholds)
                      ThresholdSliders(
                        onSaved: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Custom alert thresholds saved!'),
                            backgroundColor: Colors.blueAccent,
                            duration: Duration(seconds: 2),
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

          // ── Footer ────────────────────────────────────────────────────────
          Divider(color: Theme.of(context).dividerColor, height: 1),
          _AboutButton(),
        ],
      ),
    );
  }
}

// ── Internal tile widgets ─────────────────────────────────────────────────────

class _AlertSwitch extends StatelessWidget {
  final SettingsController ctrl;
  const _AlertSwitch({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.notifications_active, color: Colors.grey),
      title: Text('Critical Alerts',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
      trailing: Tooltip(
        message: 'Toggle critical threshold notifications',
        child: Switch(
          value: ctrl.alertsEnabled,
          onChanged: ctrl.setAlertsEnabled,
          activeThumbColor: Colors.blueAccent.withValues(alpha: 0.5),
          inactiveThumbColor: Colors.grey,
          inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

class _ThemeSwitch extends StatelessWidget {
  final SettingsController ctrl;
  const _ThemeSwitch({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.brightness_6,
          color: Theme.of(context).colorScheme.primary),
      title: Text('Dark Mode',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
      trailing: Switch(
        value: ctrl.isDarkMode,
        onChanged: ctrl.setDarkMode,
        activeColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _ClearLogsTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.delete_sweep, color: Colors.redAccent),
      title: Text('Clear Sensor Logs',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
      onTap: () async {
        try {
          await CsvLoggerService.instance.clearLogs();
          if (!context.mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logs cleared successfully')),
          );
        } catch (e) {
          debugPrint('Delete Error: $e');
        }
      },
    );
  }
}

class _AboutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'View app information and team credits',
      child: GestureDetector(
        onTap: () => showAppAboutDialog(context),
        child: const Padding(
          padding: EdgeInsets.all(20.0),
          child: Row(
            children: [
              Text('LettuVault v1.1.5',
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
              Spacer(),
              Icon(Icons.info_outline, color: Colors.blueAccent, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

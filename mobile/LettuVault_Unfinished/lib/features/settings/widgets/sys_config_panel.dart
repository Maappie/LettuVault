import 'package:flutter/material.dart';

import 'package:my_new_app/features/settings/controllers/settings_controller.dart';

/// SysConfigPanel — system config preset chips + target sliders.
///
/// Reads from and writes to [SettingsController.instance].
class SysConfigPanel extends StatelessWidget {
  const SysConfigPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = SettingsController.instance;
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _PresetChip('Lettuce',    Icons.eco,  Colors.green),
                  _PresetChip('Strawberry', Icons.spa,  Colors.red),
                  _PresetChip('Custom',     Icons.tune, Colors.blueAccent),
                ],
              ),
            ),
            _ConfigSlider('Target Temp',  ctrl.sysConfigTemp,  0,   60,   Colors.redAccent,  ctrl.setSysConfigTemp),
            _ConfigSlider('Target Humid', ctrl.sysConfigHum,   50,  100,  Colors.blueAccent, ctrl.setSysConfigHum),
            _ConfigSlider('Target Pres',  ctrl.sysConfigPres,  800, 1100, Colors.amber,      ctrl.setSysConfigPres),
            if (ctrl.sysConfigError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  ctrl.sysConfigError!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: FilledButton.icon(
                onPressed: ctrl.isSavingSysConfig ? null : () async {
                  final focus = FocusScope.of(context);
                  focus.unfocus();
                  final success = await ctrl.saveSysConfig();
                  if (success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('System config synced to hardware!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: ctrl.isSavingSysConfig 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload),
                label: Text(ctrl.isSavingSysConfig ? 'Saving...' : 'Apply Details'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _PresetChip(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    final ctrl = SettingsController.instance;
    final selected = ctrl.selectedPreset == label;
    return FilterChip(
      avatar: Icon(icon, size: 16, color: selected ? Colors.white : color),
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
          fontSize: 12,
        ),
      ),
      selected: selected,
      selectedColor: color,
      backgroundColor: Theme.of(context).cardColor,
      checkmarkColor: Colors.white,
      side: BorderSide(color: selected ? color : Theme.of(context).dividerColor),
      onSelected: (_) => ctrl.applyPreset(label),
    );
  }
}

class _ConfigSlider extends StatelessWidget {
  final String label;
  final double value, min, max;
  final Color color;
  final ValueChanged<double> onChanged;

  const _ConfigSlider(this.label, this.value, this.min, this.max, this.color, this.onChanged);

  String get _unit =>
      label.contains('Temp')  ? '°C'  :
      label.contains('Humid') ? '%'   : ' hPa';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface, fontSize: 12)),
              Text('${value.toStringAsFixed(0)}$_unit',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 3),
            child: Slider(
              value: value, min: min, max: max,
              divisions: (max - min).toInt(),
              activeColor: color,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

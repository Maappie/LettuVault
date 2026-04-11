import 'package:flutter/material.dart';

import 'package:my_new_app/features/settings/controllers/settings_controller.dart';

/// ThresholdSliders — custom alert threshold sliders with draft editing and validation.
///
/// Reads from and writes to [SettingsController.instance].
/// Only shown when [SettingsController.useDefaultThresholds] is false.
class ThresholdSliders extends StatelessWidget {
  final VoidCallback onSaved;

  const ThresholdSliders({super.key, required this.onSaved});

  @override
  Widget build(BuildContext context) {
    final ctrl = SettingsController.instance;
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Text(
                'Adjust then tap Save. Target must be inside your Low–High range.',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
            _Slider('Temp Low',  ctrl.draftTempLow,  -40, 60,  Colors.redAccent,
                (v) => ctrl.updateDraft(tempLow: v)),
            _Slider('Temp High', ctrl.draftTempHigh, -40, 60,  Colors.redAccent,
                (v) => ctrl.updateDraft(tempHigh: v)),
            _Slider('Humid Low', ctrl.draftHumLow,   0,  100, Colors.blueAccent,
                (v) => ctrl.updateDraft(humLow: v)),
            _Slider('Humid High',ctrl.draftHumHigh,  0,  100, Colors.blueAccent,
                (v) => ctrl.updateDraft(humHigh: v)),
            _Slider('Pres Low',  ctrl.draftPresLow,  750, 1100, Colors.amber,
                (v) => ctrl.updateDraft(presLow: v)),
            _Slider('Pres High', ctrl.draftPresHigh, 750, 1100, Colors.amber,
                (v) => ctrl.updateDraft(presHigh: v)),

            if (ctrl.thresholdError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    ctrl.thresholdError!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
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
                  onPressed: () async {
                    final ok = await ctrl.saveCustomThresholds();
                    if (ok) onSaved();
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Slider extends StatelessWidget {
  final String label;
  final double value, min, max;
  final Color color;
  final ValueChanged<double> onChanged;

  const _Slider(this.label, this.value, this.min, this.max, this.color, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ${value.toStringAsFixed(0)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface, fontSize: 12,
            ),
          ),
          Slider(
            value: value, min: min, max: max,
            divisions: (max - min).toInt(),
            activeColor: color,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

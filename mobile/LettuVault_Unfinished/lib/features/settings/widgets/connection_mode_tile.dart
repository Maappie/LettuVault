import 'package:flutter/material.dart';

import 'package:my_new_app/src/core/app_mode.dart';

/// ConnectionModeTile — shows the Online/Offline mode badge and toggle switch.
///
/// [onToggle] is called when the switch is flipped; the caller is responsible
/// for the actual connectivity switching logic.
class ConnectionModeTile extends StatelessWidget {
  final VoidCallback onToggle;

  const ConnectionModeTile({super.key, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppMode>(
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
                      isOffline ? 'Connected to LettuVault AP' : 'Using cloud server',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isOffline,
                activeThumbColor: Colors.orange,
                inactiveTrackColor: Colors.blue.shade200,
                onChanged: (_) => onToggle(),
              ),
            ],
          ),
        );
      },
    );
  }
}

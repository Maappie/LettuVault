import 'package:flutter/material.dart';

/// ApiStatusBanner — shows backend connection state at the top of the dashboard.
///
/// Displays a red error banner (tappable for full error detail) when [apiError]
/// is non-null, or a green "live" banner when [isPolling] is true and no error.
class ApiStatusBanner extends StatelessWidget {
  final String? apiError;
  final bool isPolling;

  const ApiStatusBanner({
    super.key,
    required this.apiError,
    required this.isPolling,
  });

  @override
  Widget build(BuildContext context) {
    if (apiError != null) return _ErrorBanner(apiError: apiError!, context: context);
    if (isPolling) return _LiveBanner();
    return const SizedBox.shrink();
  }
}

class _ErrorBanner extends StatelessWidget {
  final String apiError;
  final BuildContext context;
  const _ErrorBanner({required this.apiError, required this.context});

  @override
  Widget build(BuildContext outerCtx) {
    return GestureDetector(
      onTap: () => showDialog(
        context: outerCtx,
        builder: (dialogCtx) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.error_outline, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Connection Error', style: TextStyle(fontSize: 16)),
          ]),
          content: SingleChildScrollView(
            child: SelectableText(
              apiError,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.cloud_off, color: Colors.redAccent, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Backend unreachable — tap for details',
                  style: TextStyle(
                    color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.redAccent, size: 16),
            ]),
            const SizedBox(height: 4),
            Text(
              apiError.length > 120 ? '${apiError.substring(0, 120)}…' : apiError,
              style: TextStyle(
                color: Colors.redAccent.withValues(alpha: 0.8),
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.cloud_done, color: Colors.green, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Live — connected to backend',
            style: TextStyle(color: Colors.green.withValues(alpha: 0.9), fontSize: 12),
          ),
        ),
      ]),
    );
  }
}

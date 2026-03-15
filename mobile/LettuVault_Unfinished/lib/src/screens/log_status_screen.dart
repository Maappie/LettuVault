import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class LogStatusScreen extends StatelessWidget {
  const LogStatusScreen({super.key});

  Future<void> _shareLogs(BuildContext context) async {
    try {
      Directory? dir;
      try {
        dir = await getExternalStorageDirectory();
      } catch (_) {
        dir = await getApplicationDocumentsDirectory();
      }
      if (dir == null) throw Exception('Storage unavailable');
      final file = File('${dir.path}/sensor_log.csv');
      if (!await file.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No log file to share')));
        return;
      }
      await Share.shareXFiles([XFile(file.path)], text: 'LettuVault sensor logs');
    } catch (e) {
      debugPrint('Share error: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to share logs')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storage, size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 20),
            const Text(
              "CSV Logging Active",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              "Data is saved to 'sensor_log.csv' in the public documents folder.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _shareLogs(context),
              icon: const Icon(Icons.share),
              label: const Text('Share Logs'),
            ),
          ],
        ),
      ),
    );
  }
}

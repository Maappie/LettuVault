import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// CsvLoggerService — handles all CSV read/write/delete operations.
class CsvLoggerService {
  CsvLoggerService._();
  static final CsvLoggerService instance = CsvLoggerService._();

  // ── Storage directory resolution ─────────────────────────────────────────

  Future<Directory?> getStorageDirectory() async {
    try {
      if (Platform.isAndroid) return await getExternalStorageDirectory();
      return await getApplicationDocumentsDirectory();
    } catch (e) {
      debugPrint('[CSV] Storage unavailable: $e');
      return null;
    }
  }

  // ── Write ────────────────────────────────────────────────────────────────

  Future<void> log(String sensor, double value) async {
    try {
      final dir = await getStorageDirectory();
      if (dir == null) return;
      final file = File('${dir.path}/sensor_log.csv');
      final timestamp =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      await file.writeAsString(
        '$timestamp, $sensor, ${value.toStringAsFixed(2)}\n',
        mode: FileMode.append,
      );
    } catch (e) {
      debugPrint('[CSV] Write error: $e');
    }
  }

  // ── Delete ───────────────────────────────────────────────────────────────

  Future<void> clearLogs() async {
    final dir = await getStorageDirectory();
    if (dir == null) throw Exception('Storage unavailable');
    final file = File('${dir.path}/sensor_log.csv');
    if (await file.exists()) await file.delete();
  }
}

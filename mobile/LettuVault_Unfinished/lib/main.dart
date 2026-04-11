import 'package:flutter/material.dart';

import 'package:my_new_app/app/app.dart';
import 'package:my_new_app/src/core/secure_storage.dart';
import 'package:my_new_app/src/services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Seed default API keys into secure storage on first run
  await SecureStorage.seedDefaultsIfNeeded();

  // Best-effort background service initialization
  try {
    await initBackgroundService();
  } catch (e) {
    debugPrint('[BG] Background service init failed (non-fatal): $e');
  }

  runApp(const LettuVaultApp());
}
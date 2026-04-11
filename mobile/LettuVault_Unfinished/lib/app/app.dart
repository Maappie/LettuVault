import 'package:flutter/material.dart';
import 'package:my_new_app/app/app_notifiers.dart';
import 'package:my_new_app/app/theme.dart';
import 'package:my_new_app/navigation/main_navigator.dart';

/// LettuVaultApp — Root widget.
///
/// Wraps MaterialApp in a ValueListenableBuilder so the entire app
/// rebuilds with the correct theme whenever the user toggles dark mode.
class LettuVaultApp extends StatelessWidget {
  const LettuVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) => MaterialApp(
        title: 'LettuVault',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        home: MainNavigator(key: MainNavigator.navKey),
      ),
    );
  }
}

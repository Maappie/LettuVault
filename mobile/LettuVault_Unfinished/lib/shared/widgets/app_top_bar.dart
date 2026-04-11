import 'package:flutter/material.dart';

/// AppTopBar — standard top bar used by all screens.
///
/// Shows a hamburger-menu icon (opens the Drawer), a centered title,
/// and a balancing spacer on the right.
class AppTopBar extends StatelessWidget {
  final String title;
  const AppTopBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 50, left: 10, right: 20, bottom: 20),
      color: Colors.transparent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              Icons.menu_rounded,
              color: Theme.of(context).colorScheme.onSurface,
              size: 28,
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          // Spacer to keep title centered (mirrors IconButton width)
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

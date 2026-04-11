import 'package:flutter/material.dart';

/// AboutDialog — shows app info and team credits.
void showAppAboutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('About LettuVault'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'LettuVault v1.1.5',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'A real-time sensor monitoring app for greenhouse and agricultural environments.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text('Features:', style: TextStyle(fontWeight: FontWeight.bold)),
            const Padding(
              padding: EdgeInsets.only(left: 8.0, top: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• Real-time Sensor Monitoring'),
                  Text('• Customizable Alert Thresholds'),
                  Text('• Live Timeline Charts'),
                  Text('• CSV Data Logging'),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(),
            ),
            const Text('The Team:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            _teamMember('Banate, Jeraldine', 'AI Training'),
            _teamMember('Cariazo, Vaan Meyvn', 'UI/UX'),
            _teamMember('Malidas, Hasnayrah', 'UI/UX'),
            _teamMember('Mapa, Renz Daneco', 'Backend Logic'),
            _teamMember('Mortera, Rhiza Rhean', 'AI Training'),
            const SizedBox(height: 16),
            const Text(
              'Made for precision agriculture.',
              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Widget _teamMember(String name, String role) {
  return Padding(
    padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
    child: Text('$name — $role', style: const TextStyle(fontSize: 13)),
  );
}

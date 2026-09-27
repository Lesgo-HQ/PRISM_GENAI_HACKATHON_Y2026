import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            title: const Text('Accessibility Service'),
            subtitle: Text(
              controller.isAccessibilityEnabled ? 'Enabled' : 'Disabled',
            ),
            trailing: Switch(
              value: controller.isAccessibilityEnabled,
              onChanged: (val) {
                controller.openAccessibilitySettings();
              },
            ),
          ),
          const Divider(height: 32),
          const ListTile(
            title: Text('Target Applications'),
            subtitle: Text(
              'SAAR requires target apps to be installed. Target applications are identified natively during execution.',
            ),
          ),
          const Divider(height: 32),
          const ListTile(
            title: Text('About SAAR'),
            subtitle: Text(
              'Smart Automated Action Replay (SAAR) is an on-device workflow automation tool driven by voice. It records and replays user interactions natively without any cloud dependencies.',
            ),
          ),
          ListTile(
            title: const Text('Saved Flows'),
            subtitle: Text('${controller.flows.length} flows in library'),
            leading: const Icon(Icons.library_books),
          ),
          const Divider(height: 32),
          const ListTile(
            title: Text('Model Information'),
            subtitle: Text('LocalIntentModel - Keyword-based NLU'),
            leading: Icon(Icons.model_training),
          ),
          const Divider(height: 32),
          const Center(
            child: Text(
              'SAAR Version 1.0.0 (Hackathon Edition)\nRunning Local NLU Pipeline',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

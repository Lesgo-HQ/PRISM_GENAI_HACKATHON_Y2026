import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_controller.dart';
import 'teach_screen.dart';
import 'replay_screen.dart';
import 'settings_screen.dart';
import 'flow_library_screen.dart';
import 'report_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>().state;

    Widget body;
    switch (state) {
      case AppState.teaching:
      case AppState.synthesizing:
        body = const TeachScreen();
        break;
      case AppState.executing:
      case AppState.waitingForClarification:
        body = const ReplayScreen();
        break;
      default:
        body = const _HomeView();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: body,
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SAAR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportScreen()),
            ),
            tooltip: 'Reports',
          ),
          IconButton(
            icon: const Icon(Icons.library_books),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FlowLibraryScreen()),
            ),
            tooltip: 'Flow Library',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          if (!controller.isAccessibilityEnabled)
            Material(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: Icon(
                  Icons.warning,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                title: Text(
                  'Accessibility service disabled',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                trailing: TextButton(
                  onPressed: controller.openAccessibilitySettings,
                  child: const Text('ENABLE'),
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Card(
                      margin: const EdgeInsets.all(32),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              controller.state == AppState.error
                                  ? Icons.error_outline
                                  : Icons.info_outline,
                              color: controller.state == AppState.error
                                  ? Colors.red
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 16),
                            Flexible(
                              child: Text(
                                controller.statusMessage,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTapDown: (_) => controller.startListening(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: controller.state == AppState.listening
                            ? 120
                            : 100,
                        height: controller.state == AppState.listening
                            ? 120
                            : 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: controller.state == AppState.listening
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
                          boxShadow: controller.state == AppState.listening
                              ? [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.5),
                                    blurRadius: 20,
                                    spreadRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          Icons.mic,
                          size: 48,
                          color: controller.state == AppState.listening
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Tap to talk'),
                  ],
                ),
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Learned Flows',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FlowLibraryScreen(),
                    ),
                  ),
                  child: const Text('View All'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: controller.flows.take(5).length,
              itemBuilder: (context, index) {
                final flow = controller.flows[index];
                return ListTile(
                  title: Text(flow.triggerIntent),
                  subtitle: Text(
                    '${flow.appPackage} • ${flow.steps.length} steps',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // View flow details logic (could push to flow library detail view)
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

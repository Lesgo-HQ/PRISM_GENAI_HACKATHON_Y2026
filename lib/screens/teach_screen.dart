import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_controller.dart';

class TeachScreen extends StatelessWidget {
  const TeachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final isSynthesizing = controller.state == AppState.synthesizing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teach Mode'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (!isSynthesizing) {
              controller.stopTeaching();
            }
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSynthesizing)
                const CircularProgressIndicator()
              else ...[
                const Icon(
                  Icons.fiber_manual_record,
                  color: Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 24),
              Text(
                controller.statusMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 32),
              if (controller.lastSynthesizedFlow != null &&
                  controller.state == AppState.idle)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Synthesized Flow',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Intent: ${controller.lastSynthesizedFlow!.triggerIntent}',
                        ),
                        Text(
                          'Steps: ${controller.lastSynthesizedFlow!.steps.length}',
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: isSynthesizing
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                controller.stopTeaching();
              },
              backgroundColor: Colors.red,
              icon: const Icon(Icons.stop),
              label: const Text('Stop & Save'),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

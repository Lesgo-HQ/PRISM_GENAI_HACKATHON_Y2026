import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_controller.dart';

class ReplayScreen extends StatefulWidget {
  const ReplayScreen({super.key});

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen> {
  final _clarificationController = TextEditingController();

  @override
  void dispose() {
    _clarificationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final isClarifying = controller.state == AppState.waitingForClarification;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Executing Command'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Spacer(),
            if (controller.replayState != null) ...[
              Text(
                'Step ${controller.replayState!.currentStep} of ${controller.replayState!.totalSteps}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: controller.replayState!.totalSteps > 0
                    ? controller.replayState!.currentStep /
                          controller.replayState!.totalSteps
                    : null,
              ),
              const SizedBox(height: 32),
            ],

            Text(
              controller.statusMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),

            if (isClarifying) ...[
              const SizedBox(height: 32),
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        controller.clarificationQuestion ??
                            'Clarification needed',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _clarificationController,
                        decoration: const InputDecoration(
                          hintText: 'Type your answer...',
                          filled: true,
                        ),
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            controller.provideClarification(value);
                            _clarificationController.clear();
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          if (_clarificationController.text.isNotEmpty) {
                            controller.provideClarification(
                              _clarificationController.text,
                            );
                            _clarificationController.clear();
                          }
                        },
                        child: const Text('Submit'),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  controller.stopExecution();
                },
                icon: const Icon(Icons.stop, size: 32),
                label: const Text(
                  'STOP',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

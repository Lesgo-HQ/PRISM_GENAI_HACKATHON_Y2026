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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'TEACH MODE',
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: Theme.of(context).primaryColor),
          onPressed: () {
            if (!isSynthesizing) {
              controller.stopTeaching();
            }
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSynthesizing) ...[
                CircularProgressIndicator(color: Theme.of(context).primaryColor),
                const SizedBox(height: 24),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
                        blurRadius: 40,
                        spreadRadius: 10,
                      )
                    ],
                  ),
                  child: Icon(
                    Icons.fiber_manual_record_rounded,
                    color: Theme.of(context).colorScheme.error,
                    size: 80,
                  ),
                ),
                const SizedBox(height: 40),
              ],
              Text(
                controller.statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              if (!isSynthesizing)
                Text(
                  'Navigate to the app and perform the task now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70,
                  ),
                ),
              const Spacer(),
              if (!isSynthesizing)
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      controller.stopTeaching();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 10,
                      shadowColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
                    ),
                    icon: const Icon(Icons.stop_rounded, size: 28),
                    label: const Text(
                      'STOP & SAVE',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_controller.dart';
import '../theme.dart';

class ReplayScreen extends StatefulWidget {
  const ReplayScreen({super.key});

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen> with SingleTickerProviderStateMixin {
  final _clarificationController = TextEditingController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _clarificationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _submitClarification(AppController controller, String value) {
    if (value.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    controller.provideClarification(value.trim());
    _clarificationController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final isClarifying = controller.state == AppState.waitingForClarification;
    final replayState = controller.replayState;
    final currentStep = replayState?.currentStep ?? 0;
    final totalSteps = replayState?.totalSteps ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          isClarifying ? 'NEEDS INPUT' : 'EXECUTING TASK',
          style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w800, letterSpacing: 1.2),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          if (totalSteps > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: currentStep / totalSteps,
                        minHeight: 8,
                        backgroundColor: AppTheme.surface,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '$currentStep / $totalSteps',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
          
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surface),
            ),
            child: Row(
              children: [
                FadeTransition(
                  opacity: _pulseAnimation,
                  child: const Icon(Icons.settings_suggest_rounded, color: AppTheme.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    controller.statusMessage,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: totalSteps,
              itemBuilder: (context, index) {
                final isCompleted = index < (currentStep - 1);
                final isCurrent = index == (currentStep - 1);
                
                Color iconColor = AppTheme.textSecondary;
                IconData iconData = Icons.radio_button_unchecked_rounded;
                
                if (isCompleted) {
                  iconColor = AppTheme.success;
                  iconData = Icons.check_circle_rounded;
                } else if (isCurrent) {
                  iconColor = AppTheme.primary;
                  iconData = Icons.play_circle_fill_rounded;
                }
                
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isCurrent ? AppTheme.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent ? AppTheme.primary.withValues(alpha: 0.3) : Colors.transparent,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(iconData, color: iconColor),
                    title: Text(
                      'Step ${index + 1}',
                      style: TextStyle(
                        color: isCurrent ? AppTheme.textPrimary : AppTheme.textSecondary,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: isCurrent ? const Text('Running...', style: TextStyle(color: AppTheme.primary)) : null,
                  ),
                );
              },
            ),
          ),
          
          if (isClarifying)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, -5))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.help_outline_rounded, color: AppTheme.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          controller.clarificationQuestion ?? 'Clarification needed',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (controller.isTeachConfirmation)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => controller.provideClarification('No'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textPrimary,
                              side: const BorderSide(color: AppTheme.surface),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('NO'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => controller.provideClarification('Yes'),
                            child: const Text('YES'),
                          ),
                        ),
                      ],
                    )
                  else
                    TextField(
                      controller: _clarificationController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Type your answer...',
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.send_rounded, color: AppTheme.primary),
                          onPressed: () => _submitClarification(controller, _clarificationController.text),
                        ),
                      ),
                      onSubmitted: (val) => _submitClarification(controller, val),
                    ),
                ],
              ),
            ),
            
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: controller.stopExecution,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error.withValues(alpha: 0.1),
                  foregroundColor: AppTheme.error,
                  elevation: 0,
                ),
                icon: const Icon(Icons.stop_rounded),
                label: const Text('STOP EXECUTION', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

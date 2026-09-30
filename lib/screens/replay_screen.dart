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

  void _submitClarification(AppController controller, String value) {
    if (value.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    controller.provideClarification(value.trim());
    _clarificationController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<AppController>();
    final isClarifying = controller.state == AppState.waitingForClarification;
    final replayState = controller.replayState;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // The clarification field opens the keyboard; the body scrolls instead of
      // being squeezed, so the content never overflows.
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          isClarifying ? 'NEEDS INPUT' : 'EXECUTING',
          style: TextStyle(
            color: theme.primaryColor,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 24.0,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      if (replayState != null) ...[
                        _ProgressCard(
                          currentStep: replayState.currentStep,
                          totalSteps: replayState.totalSteps,
                        ),
                        const SizedBox(height: 32),
                      ],
                      Text(
                        controller.statusMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color:
                              theme.textTheme.bodyLarge?.color ?? Colors.white,
                        ),
                      ),
                      if (isClarifying) ...[
                        const SizedBox(height: 32),
                        _ClarificationCard(
                          question: controller.clarificationQuestion ??
                              'Clarification needed',
                          isConfirmation: controller.isTeachConfirmation,
                          textController: _clarificationController,
                          onSubmit: (value) =>
                              _submitClarification(controller, value),
                          onYes: () => controller.provideClarification('Yes'),
                          onNo: () => controller.provideClarification('No'),
                        ),
                      ],
                      const SizedBox(height: 40),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed: controller.stopExecution,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.cardTheme.color,
                            foregroundColor: theme.colorScheme.error,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.cancel_rounded, size: 26),
                          label: const Text(
                            'CANCEL EXECUTION',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _ProgressCard({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Step $currentStep of $totalSteps',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color ?? Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 12,
              backgroundColor: theme.scaffoldBackgroundColor,
              color: theme.primaryColor,
              value: totalSteps > 0 ? currentStep / totalSteps : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClarificationCard extends StatelessWidget {
  final String question;
  final bool isConfirmation;
  final TextEditingController textController;
  final ValueChanged<String> onSubmit;
  final VoidCallback onYes;
  final VoidCallback onNo;

  const _ClarificationCard({
    required this.question,
    required this.isConfirmation,
    required this.textController,
    required this.onSubmit,
    required this.onYes,
    required this.onNo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            question,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 20),
          if (isConfirmation)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onNo,
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          theme.textTheme.bodyMedium?.color ?? Colors.white70,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('NO'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onYes,
                    child: const Text('YES'),
                  ),
                ),
              ],
            )
          else
            TextField(
              controller: textController,
              textInputAction: TextInputAction.send,
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color ?? Colors.white,
              ),
              decoration: InputDecoration(
                hintText: 'Type your answer...',
                hintStyle: TextStyle(
                  color: theme.textTheme.bodyMedium?.color ?? Colors.white54,
                ),
                filled: true,
                fillColor: theme.scaffoldBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: Icon(Icons.send_rounded, color: theme.primaryColor),
                  onPressed: () => onSubmit(textController.text),
                ),
              ),
              onSubmitted: onSubmit,
            ),
        ],
      ),
    );
  }
}

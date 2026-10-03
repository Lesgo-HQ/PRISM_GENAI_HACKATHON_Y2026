import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_controller.dart';

class FlowLibraryScreen extends StatelessWidget {
  const FlowLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Flow Library',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ),
      body: controller.flows.isEmpty
          ? Center(
              child: Text(
                'No flows saved yet.',
                style: TextStyle(
                  color:
                      Theme.of(context).textTheme.bodyMedium?.color ??
                      Colors.white70,
                ),
              ),
            )
          : ListView.builder(
              itemCount: controller.flows.length,
              itemBuilder: (context, index) {
                final flow = controller.flows[index];
                return Dismissible(
                  key: Key(flow.flowId),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20.0),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text("Confirm"),
                          content: const Text(
                            "Are you sure you wish to delete this flow?",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text("CANCEL"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text("DELETE"),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  onDismissed: (direction) {
                    controller.deleteFlow(flow.flowId);
                  },
                  child: ExpansionTile(
                    title: Text(
                      flow.triggerIntent,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:
                            Theme.of(context).textTheme.bodyLarge?.color ??
                            Colors.white,
                      ),
                    ),
                    subtitle: Text(
                      '${flow.appPackage} • ${flow.steps.length} steps • ${flow.slots.length} slots',
                      style: TextStyle(color: Theme.of(context).primaryColor),
                    ),
                    children: [
                      ...flow.steps.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final step = entry.value;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).primaryColor
                                .withValues(alpha: 0.2),
                            child: Text(
                              '${idx + 1}',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                          title: Text(
                            step.action,
                            style: TextStyle(
                              color:
                                  Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.color ??
                                  Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            'Target: ${step.targetRole} '
                            '${step.targetNodeText ?? step.targetNodeContentDescription ?? ''}\n'
                            'Value: ${step.valueSlot ?? step.valueLiteral ?? step.targetNodeText ?? 'N/A'}',
                            style: TextStyle(
                              color:
                                  Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color ??
                                  Colors.white70,
                            ),
                          ),
                          isThreeLine: true,
                        );
                      }),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 16.0,
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error
                                .withValues(alpha: 0.1),
                            foregroundColor: Theme.of(context)
                                .colorScheme
                                .error,
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text("Delete Workflow"),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text("Confirm"),
                                  content: const Text(
                                    "Are you sure you wish to delete this flow?",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text("CANCEL"),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text("DELETE"),
                                    ),
                                  ],
                                );
                              },
                            );
                            if (confirm == true) {
                              controller.deleteFlow(flow.flowId);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_controller.dart';

class FlowLibraryScreen extends StatelessWidget {
  const FlowLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Flow Library')),
      body: controller.flows.isEmpty
          ? const Center(child: Text('No flows saved yet.'))
          : ListView.builder(
              itemCount: controller.flows.length,
              itemBuilder: (context, index) {
                final flow = controller.flows[index];
                return Dismissible(
                  key: Key(flow.flowId),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
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
                    title: Text(flow.triggerIntent),
                    subtitle: Text(
                      '${flow.appPackage} • ${flow.steps.length} steps • ${flow.slots.length} slots',
                    ),
                    children: flow.steps.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final step = entry.value;
                      return ListTile(
                        leading: CircleAvatar(child: Text('${idx + 1}')),
                        title: Text(step.action),
                        subtitle: Text(
                          'Target: ${step.targetRole}\nValue: ${step.valueSlot ?? step.valueLiteral ?? 'N/A'}',
                        ),
                        isThreeLine: true,
                      );
                    }).toList(),
                  ),
                );
              },
            ),
    );
  }
}

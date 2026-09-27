import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_controller.dart';
import '../models/execution_report.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final reports = controller.executionReports;

    return Scaffold(
      appBar: AppBar(title: const Text('Execution Reports')),
      body: reports.isEmpty
          ? const Center(child: Text('No execution reports yet.'))
          : ListView.builder(
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[reports.length - 1 - index];
                return _ReportCard(report: report);
              },
            ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ExecutionReport report;

  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (report.status) {
      case ReportStatus.completed:
        statusColor = Colors.green;
        break;
      case ReportStatus.halted:
        statusColor = Colors.red;
        break;
      case ReportStatus.cancelled:
        statusColor = Colors.orange;
        break;
    }

    final duration = report.endTime != null
        ? report.endTime!.difference(report.startTime).inSeconds
        : 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ExpansionTile(
        leading: Icon(Icons.analytics, color: statusColor),
        title: Text(report.flowName),
        subtitle: Text(
          'Run: ${report.runId.substring(0, 8)} • ${report.status.name.toUpperCase()}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (report.reason != null) ...[
                  Text(
                    'Reason: ${report.reason}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  'Steps Completed: ${report.stepsCompleted} / ${report.totalSteps}',
                ),
                Text('Recoveries Attempted: ${report.recoveriesAttempted}'),
                Text(
                  'Clarifications Requested: ${report.clarificationsRequested}',
                ),
                Text('Duration: $duration seconds'),
                const SizedBox(height: 8),
                Text('Start: ${report.startTime.toLocal()}'),
                if (report.endTime != null)
                  Text('End: ${report.endTime!.toLocal()}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

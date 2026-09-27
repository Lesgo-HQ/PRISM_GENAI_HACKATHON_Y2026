import 'dart:convert';

import '../models/execution_report.dart';
import 'flow_store.dart';

class ExecutionReporter {
  final FlowStore _store;
  final List<ExecutionReport> _reports = [];

  ExecutionReporter(this._store);

  List<ExecutionReport> get reports => List.unmodifiable(_reports);

  ExecutionReport create({
    required String runId,
    required String flowId,
    required String flowName,
    required int totalSteps,
  }) {
    final report = ExecutionReport(
      runId: runId,
      flowId: flowId,
      flowName: flowName,
      status: ReportStatus.completed,
      stepsCompleted: 0,
      totalSteps: totalSteps,
      startTime: DateTime.now(),
    );
    return report;
  }

  Future<void> save(ExecutionReport report) async {
    _reports.add(report);
    await _store.logSession(
      flowId: report.flowId,
      sessionType: 'replay',
      status: report.status.name,
      details: jsonEncode(report.toJson()),
    );
  }

  Future<void> loadFromStore() async {
    final logs = await _store.getSessionLogs();
    _reports.clear();
    for (final log in logs) {
      if (log['session_type'] == 'replay' && log['details'] != null) {
        try {
          final data = jsonDecode(log['details'] as String);
          _reports.add(ExecutionReport.fromJson(data));
        } catch (_) {}
      }
    }
  }

  Map<String, dynamic> get statistics {
    if (_reports.isEmpty) return {};
    final completed = _reports.where((r) => r.status == ReportStatus.completed).length;
    final halted = _reports.where((r) => r.status == ReportStatus.halted).length;
    final cancelled = _reports.where((r) => r.status == ReportStatus.cancelled).length;
    final avgSteps = _reports.map((r) => r.stepsCompleted).reduce((a, b) => a + b) / _reports.length;
    return {
      'total': _reports.length,
      'completed': completed,
      'halted': halted,
      'cancelled': cancelled,
      'successRate': completed / _reports.length,
      'avgStepsCompleted': avgSteps,
    };
  }
}

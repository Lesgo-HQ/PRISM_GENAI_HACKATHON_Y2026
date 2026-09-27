enum ReportStatus { completed, halted, cancelled }

class ExecutionReport {
  final String runId;
  final String flowId;
  final String flowName;
  final ReportStatus status;
  final int stepsCompleted;
  final int totalSteps;
  final int recoveriesAttempted;
  final int clarificationsRequested;
  final String? reason;
  final DateTime startTime;
  final DateTime? endTime;

  ExecutionReport({
    required this.runId,
    required this.flowId,
    required this.flowName,
    required this.status,
    required this.stepsCompleted,
    required this.totalSteps,
    this.recoveriesAttempted = 0,
    this.clarificationsRequested = 0,
    this.reason,
    required this.startTime,
    this.endTime,
  });

  String get summary {
    final buf = StringBuffer();
    buf.writeln('RUN #${runId.substring(0, 4).toUpperCase()}');
    buf.writeln('Status: ${status.name.toUpperCase()}');
    buf.writeln('Flow: $flowName');
    buf.writeln('Step: $stepsCompleted / $totalSteps');
    buf.writeln('Recoveries: $recoveriesAttempted');
    buf.writeln('Clarifications: $clarificationsRequested');
    if (reason != null) buf.writeln('Reason: $reason');
    if (endTime != null) {
      buf.writeln('Duration: ${endTime!.difference(startTime).inSeconds}s');
    }
    return buf.toString();
  }

  Map<String, dynamic> toJson() => {
    'runId': runId,
    'flowId': flowId,
    'flowName': flowName,
    'status': status.name,
    'stepsCompleted': stepsCompleted,
    'totalSteps': totalSteps,
    'recoveriesAttempted': recoveriesAttempted,
    'clarificationsRequested': clarificationsRequested,
    'reason': reason,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
  };

  factory ExecutionReport.fromJson(Map<String, dynamic> j) => ExecutionReport(
    runId: j['runId'] as String,
    flowId: j['flowId'] as String,
    flowName: j['flowName'] as String,
    status: ReportStatus.values.firstWhere((e) => e.name == j['status']),
    stepsCompleted: j['stepsCompleted'] as int,
    totalSteps: j['totalSteps'] as int,
    recoveriesAttempted: j['recoveriesAttempted'] as int? ?? 0,
    clarificationsRequested: j['clarificationsRequested'] as int? ?? 0,
    reason: j['reason'] as String?,
    startTime: DateTime.parse(j['startTime'] as String),
    endTime: j['endTime'] != null
        ? DateTime.parse(j['endTime'] as String)
        : null,
  );
}

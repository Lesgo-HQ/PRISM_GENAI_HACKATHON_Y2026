import 'flow.dart';
import 'screen_snapshot.dart';

enum ReplayStatus {
  idle,
  executing,
  recovering,
  waitingForUser,
  haltedSensitive,
  cancelled,
  failed,
  completed,
}

class ReplaySession {
  final String runId;
  final Flow flow;
  final Map<String, dynamic> slots;
  int currentStep;
  ReplayStatus status;
  bool actionPending = false;
  bool manualStep = false;
  int stepRecoveryAttempts = 0;
  int recoveryAttempts;
  int clarificationCount;
  ScreenSnapshot? lastScreen;
  String? pauseReason;
  DateTime? startedAt;
  DateTime? endedAt;

  ReplaySession({
    required this.runId,
    required this.flow,
    required this.slots,
    this.currentStep = 0,
    this.status = ReplayStatus.idle,
    this.recoveryAttempts = 0,
    this.clarificationCount = 0,
    this.lastScreen,
  });

  Map<String, dynamic> toJson() => {
    'runId': runId,
    'flow': flow.toJson(),
    'slots': slots,
    'currentStep': currentStep,
    'actionPending': actionPending,
    'manualStep': manualStep,
    'status': status.name,
    'recoveryAttempts': recoveryAttempts,
    'clarificationCount': clarificationCount,
    'startedAt': startedAt?.toIso8601String(),
  };

  factory ReplaySession.fromJson(Map<String, dynamic> json) {
    final flow = Flow.fromJson(Map<String, dynamic>.from(json['flow'] as Map));
    final step = json['currentStep'] as int;
    if (step < 0 || step > flow.steps.length) {
      throw const FormatException('Invalid checkpoint');
    }
    return ReplaySession(
        runId: json['runId'] as String,
        flow: flow,
        slots: Map<String, dynamic>.from(json['slots'] as Map),
        currentStep: step,
        status: ReplayStatus.waitingForUser,
        recoveryAttempts: (json['recoveryAttempts'] as int?) ?? 0,
        clarificationCount: (json['clarificationCount'] as int?) ?? 0,
      )
      ..manualStep = json['manualStep'] == true
      ..actionPending = json['actionPending'] == true
      ..startedAt = DateTime.tryParse(json['startedAt'] as String? ?? '');
  }

  void start() {
    status = ReplayStatus.executing;
    startedAt = DateTime.now();
  }

  void pause([String? reason]) {
    status = ReplayStatus.waitingForUser;
    pauseReason = reason;
  }

  void resume([String? userResponse]) {
    status = ReplayStatus.executing;
    pauseReason = null;
  }

  void stop() {
    status = ReplayStatus.cancelled;
    endedAt = DateTime.now();
  }

  void haltForSafety() {
    status = ReplayStatus.haltedSensitive;
    endedAt = DateTime.now();
  }

  void fail() {
    status = ReplayStatus.failed;
    endedAt = DateTime.now();
  }

  void complete() {
    status = ReplayStatus.completed;
    endedAt = DateTime.now();
  }
}

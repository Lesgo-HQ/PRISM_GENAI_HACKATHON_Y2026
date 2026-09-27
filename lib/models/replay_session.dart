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

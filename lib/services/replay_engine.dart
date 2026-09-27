import 'dart:async';

import 'package:uuid/uuid.dart';

import '../models/flow.dart';
import '../models/replay_session.dart';
import '../models/role_ontology.dart';
import '../models/screen_snapshot.dart';
import '../models/ui_node.dart';
import 'accessibility_bridge.dart';
import 'clarification_service.dart';
import 'credential_guard.dart';
import 'node_ranker.dart';
import 'recovery_engine.dart';

class ReplayState {
  final ReplayStatus status;
  final int currentStep;
  final int totalSteps;
  final String? message;
  final String? clarificationQuestion;

  ReplayState({
    required this.status,
    required this.currentStep,
    required this.totalSteps,
    this.message,
    this.clarificationQuestion,
  });
}

enum _StepResult { completed, waiting, halted }

class ReplayEngine {
  final AccessibilityBridge _bridge;
  final ClarificationService _clarification;
  final RecoveryEngine _recovery;
  final NodeRanker _ranker = NodeRanker();
  final StreamController<ReplayState> _states = StreamController.broadcast();
  final Duration _stepDelay;

  ReplaySession? _session;
  Completer<void>? _resumeSignal;
  bool _stopRequested = false;

  Stream<ReplayState> get stateStream => _states.stream;
  ReplaySession? get session => _session;

  ReplayEngine(this._bridge, this._clarification, {Duration stepDelay = const Duration(milliseconds: 800)})
      : _recovery = RecoveryEngine(_bridge),
        _stepDelay = stepDelay;

  Future<ReplayState> execute(Flow flow, Map<String, dynamic> slots) async {
    if (_session != null && _isActive(_session!.status)) {
      throw StateError('A replay session is already active.');
    }
    final session = ReplaySession(runId: const Uuid().v4(), flow: flow, slots: Map.unmodifiable(slots))..start();
    _session = session;
    _stopRequested = false;

    while (session.currentStep < flow.steps.length) {
      if (_stopRequested) return _finish(session, ReplayStatus.cancelled, 'Stopped by user');
      final result = await _executeCurrentStep(session);
      if (result == _StepResult.completed) {
        session.currentStep++;
        session.recoveryAttempts = 0;
        continue;
      }
      if (result == _StepResult.halted) {
        return _finish(session, ReplayStatus.haltedSensitive, 'SAAR stopped for safety.');
      }

      session.pause('needs_clarification');
      session.clarificationCount++;
      final step = flow.steps[session.currentStep];
      _emit(session, message: 'Stuck at step ${session.currentStep + 1}.', question: _clarification.buildReplayClarification(
        '${step.action} on ${step.targetRole}',
        _describeScreen(await _bridge.getLastTree()),
      ));
      _resumeSignal = Completer<void>();
      await _resumeSignal!.future;
      _resumeSignal = null;
      if (_stopRequested) return _finish(session, ReplayStatus.cancelled, 'Stopped by user');
      session.resume(); // Remains at same step
    }
    return _finish(session, ReplayStatus.completed, 'Flow completed successfully');
  }

  Future<_StepResult> _executeCurrentStep(ReplaySession session) async {
    final step = session.flow.steps[session.currentStep];
    if (step.action == 'stop_before') return _StepResult.waiting;

    _emit(session, message: 'Executing: ${step.action} on ${step.targetRole}');
    for (var attempt = 0; attempt < 5; attempt++) {
      if (_stopRequested) return _StepResult.waiting;
      final tree = await _bridge.getLastTree();
      if (CredentialGuard.isSensitiveScreen(tree)) return _StepResult.halted;
      try {
        if (await _bridge.isSensitiveScreen()) return _StepResult.halted;
      } catch (_) {
        return _StepResult.halted;
      }
      if (tree == null) {
        await Future<void>.delayed(_stepDelay);
        continue;
      }
      final roles = _rolesForTree(tree);
      if (!step.validatePrecondition(roles)) {
        session.status = ReplayStatus.recovering;
        session.recoveryAttempts++;
        await _recovery.recover(tree);
        await Future<void>.delayed(_stepDelay);
        continue;
      }
      final match = _ranker.best(tree.flatten(), step.targetRole, step.action);
      if (match != null && match.isAmbiguous) {
        return _StepResult.waiting;
      }
      final target = match?.node;
      if (target != null && await _performAction(step, target, session.slots)) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        final afterTree = await _bridge.getLastTree();
        if (CredentialGuard.isSensitiveScreen(afterTree)) return _StepResult.halted;
        if (afterTree != null) {
          final afterRoles = _rolesForTree(afterTree);
          if (!step.validatePostcondition(afterRoles)) {
            session.status = ReplayStatus.recovering;
            session.recoveryAttempts++;
            await _recovery.recover(afterTree);
            await Future<void>.delayed(_stepDelay);
            continue;
          }
        }
        session.lastScreen = afterTree != null ? ScreenSnapshot.fromTree(afterTree, rolesForNode: (n) => [RoleOntology.inferRole(n)].whereType<String>()) : null;
        return _StepResult.completed;
      }
      session.status = ReplayStatus.recovering;
      session.recoveryAttempts++;
      await _recovery.recover(tree);
      await Future<void>.delayed(_stepDelay);
    }
    return _StepResult.waiting;
  }

  Set<String> _rolesForTree(UiNode tree) {
    final s = <String>{};
    for (final n in tree.flatten()) {
      final r = RoleOntology.inferRole(n);
      if (r != null) s.add(r);
    }
    return s;
  }

  Future<bool> _performAction(FlowStep step, UiNode target, Map<String, dynamic> slots) async {
    final bounds = target.bounds;
    final x = ((bounds['left'] ?? 0) + (bounds['right'] ?? 0)) / 2;
    final y = ((bounds['top'] ?? 0) + (bounds['bottom'] ?? 0)) / 2;
    switch (step.action) {
      case 'tap':
      case 'select':
        return _bridge.tap(x, y);
      case 'type':
      case 'set_quantity':
        final value = step.valueSlot != null && slots.containsKey(step.valueSlot)
            ? slots[step.valueSlot].toString()
            : step.valueLiteral ?? '';
        if (value.isEmpty || !await _bridge.tap(x, y)) return false;
        return _bridge.typeIntoFocused(value);
      case 'swipe':
        return _bridge.swipe(x, y + 300, x, y - 300, durationMs: 300);
      default:
        return false;
    }
  }

  void resume() {
    if (_session?.status == ReplayStatus.waitingForUser && _resumeSignal != null) {
      _resumeSignal!.complete();
    }
  }

  void stop() {
    _stopRequested = true;
    if (_resumeSignal != null && !_resumeSignal!.isCompleted) _resumeSignal!.complete();
  }

  ReplayState _finish(ReplaySession session, ReplayStatus status, String message) {
    session.status = status;
    return _emit(session, message: message);
  }

  ReplayState _emit(ReplaySession session, {String? message, String? question}) {
    final state = ReplayState(
      status: session.status,
      currentStep: session.status == ReplayStatus.completed ? session.currentStep : session.currentStep + 1,
      totalSteps: session.flow.steps.length,
      message: message,
      clarificationQuestion: question,
    );
    _states.add(state);
    return state;
  }

  bool _isActive(ReplayStatus status) =>
      status == ReplayStatus.executing || status == ReplayStatus.recovering || status == ReplayStatus.waitingForUser;

  String _describeScreen(UiNode? tree) {
    if (tree == null) return 'unknown screen';
    final labels = tree.flatten().where((node) => node.isClickable && (node.text?.isNotEmpty ?? false)).take(5).map((node) => node.text);
    return labels.isEmpty ? 'a screen with no identifiable elements' : 'a screen showing: ${labels.join(', ')}';
  }

  void dispose() {
    stop();
    _states.close();
  }
}

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

/// One owner executes actions. Every dispatched action is checkpointed before
/// crossing the native boundary; an uncertain outcome requires human review.
class ReplayEngine {
  final AccessibilityBridge _bridge;
  final ClarificationService _clarification;
  final RecoveryEngine _recovery;
  final NodeRanker _ranker = NodeRanker();
  final StreamController<ReplayState> _states = StreamController.broadcast();
  final Duration stepDelay;
  final Future<void> Function(ReplaySession)? saveCheckpoint;
  ReplaySession? _session;
  Completer<void>? _resumeSignal;
  bool _stopRequested = false;
  bool _pauseRequested = false;
  bool _running = false;
  bool _disposed = false;
  Stream<ReplayState> get stateStream => _states.stream;
  ReplaySession? get session => _session;
  bool get isActive => _running;

  ReplayEngine(
    this._bridge,
    this._clarification, {
    this.stepDelay = const Duration(milliseconds: 800),
    this.saveCheckpoint,
  }) : _recovery = RecoveryEngine(_bridge);

  Future<void> _save(ReplaySession s) async => saveCheckpoint?.call(s);

  Future<ReplayState> execute(
    Flow flow,
    Map<String, dynamic> slots, {
    ReplaySession? checkpoint,
  }) async {
    if (_running) throw StateError('A replay session is already active.');
    _running = true;
    final s =
        checkpoint ??
        (ReplaySession(
          runId: const Uuid().v4(),
          flow: flow,
          slots: Map.of(slots),
        )..start());
    _session = s;
    _recovery.setExpectedPackage(flow.appPackage);
    _stopRequested = false;
    _pauseRequested = false;
    try {
      await _save(s);
      if (!await _openTargetApp(flow.appPackage)) {
        await _wait(s, 'Open the learned app, then say continue.');
      }
      while (s.currentStep < flow.steps.length && !_stopRequested) {
        if (_pauseRequested) {
          await _wait(
            s,
            'Task paused. Tell me what to change, or say continue.',
          );
          continue;
        }
        final step = flow.steps[s.currentStep];
        final tree = await _bridge.getLastTree();
        if (_stopRequested || _pauseRequested) continue;
        if (tree == null || !await _safe(tree)) {
          await _wait(
            s,
            'Complete any sign-in or verification yourself. '
            'I have kept your progress. Say continue when the screen is ready.',
          );
          continue;
        }
        if (flow.appPackage.isNotEmpty && !_belongs(tree, flow.appPackage)) {
          await _wait(s, 'Return to the learned app before continuing.');
          continue;
        }
        if (s.actionPending) {
          if (_verified(step, tree, s)) {
            await _advance(s);
          } else {
            await _wait(
              s,
              'The previous action was sent, but its result is uncertain. '
              'Check the app. Say "step completed" only if it succeeded, or cancel. '
              'I will not repeat it automatically.',
            );
          }
          continue;
        }
        if (step.action == 'stop_before' || s.manualStep) {
          s.manualStep = true;
          await _wait(
            s,
            'This step needs you. Complete it in the app, then say '
            '"step completed". I will keep the remaining steps.',
          );
          continue;
        }
        s.status = ReplayStatus.executing;
        _emit(s, 'Working on step ${s.currentStep + 1}: ${step.action}');
        final roles = _roles(tree);
        final match = _ranker.best(
          tree.flatten(),
          step.targetRole,
          step.action,
          targetNodeText: _boundText(step.targetNodeText, s),
          targetNodeContentDescription: _boundText(
            step.targetNodeContentDescription,
            s,
          ),
          targetNodeResourceId: step.targetNodeResourceId,
        );
        if (!step.validatePrecondition(roles) ||
            match == null ||
            match.isAmbiguous) {
          // Never explore when multiple targets are equally plausible.
          if (match?.isAmbiguous != true && s.stepRecoveryAttempts < 2) {
            s.status = ReplayStatus.recovering;
            s.recoveryAttempts++;
            s.stepRecoveryAttempts++;
            if (_stopRequested || _pauseRequested) continue;
            await _recovery.recover(tree, isCancelled: () => _stopRequested || _pauseRequested);
            await Future<void>.delayed(stepDelay);
            continue;
          }
          await _wait(
            s,
            _clarification.buildReplayClarification(
              '${step.action} on ${step.targetRole}',
              'the current app screen',
            ),
          );
          continue;
        }
        if (_stopRequested || _pauseRequested) continue;
        final targetLabel =
            '${match.node.text ?? ''} ${match.node.contentDescription ?? ''}';
        if (RegExp(
          r'\b(pay|place order|confirm purchase|delete|send money|transfer|subscribe)\b',
          caseSensitive: false,
        ).hasMatch(targetLabel)) {
          s.manualStep = true;
          continue;
        }
        // Recheck after asynchronous observation; native code checks again.
        if (!await _safe(await _bridge.getLastTree())) continue;
        if (_stopRequested || _pauseRequested) continue;
        s.lastScreen = _snapshot(tree);
        s.actionPending = true;
        await _save(s);
        if (_stopRequested || _pauseRequested) {
          s.actionPending = false;
          await _save(s);
          continue;
        }
        final dispatched = await _performAction(step, match.node, s.slots);
        if (!dispatched) {
          // A failed bridge call may still have changed focus or dispatched a
          // gesture. Preserve the intent record rather than guessing/retrying.
          await _wait(
            s,
            'The device did not confirm the action. Check the app '
            'and say "step completed" if it succeeded, or cancel.',
          );
          continue;
        }
        for (var attempt = 0; attempt < 4 && !_stopRequested; attempt++) {
          await Future<void>.delayed(stepDelay);
          final after = await _bridge.getLastTree();
          if (after != null && _verified(step, after, s)) {
            await _advance(s);
            break;
          }
        }
      }
      return await _finish(
        s,
        _stopRequested ? ReplayStatus.cancelled : ReplayStatus.completed,
        _stopRequested ? 'Task cancelled.' : 'All workflow steps verified.',
      );
    } catch (_) {
      s.status = ReplayStatus.failed;
      s.pauseReason =
          'Execution interrupted. Review the saved checkpoint before resuming.';
      await _save(s);
      rethrow;
    } finally {
      _running = false;
    }
  }

  String? _boundText(String? text, ReplaySession s) {
    if (text == null) return null;
    var result = text;
    for (final slot in s.flow.slots) {
      final original = slot.defaultValue?.toString();
      final replacement = s.slots[slot.name]?.toString();
      if (original != null && original.isNotEmpty && replacement != null) {
        result = result.replaceAll(
          RegExp(RegExp.escape(original), caseSensitive: false),
          replacement,
        );
      }
    }
    return result;
  }

  bool _verified(FlowStep step, UiNode after, ReplaySession s) {
    if (CredentialGuard.isSensitiveScreen(after)) return false;
    if (s.flow.appPackage.isNotEmpty && !_belongs(after, s.flow.appPackage)) {
      return false;
    }
    if (step.postcondition?.requiredRoles.isNotEmpty == true) {
      return step.validatePostcondition(_roles(after));
    }
    if (step.action == 'type' || step.action == 'set_quantity') {
      final value = _value(step, s.slots);
      return value.isNotEmpty &&
          after.flatten().any((n) => n.isEditable && n.text == value);
    }
    return s.lastScreen != null &&
        _snapshot(after).stateHash != s.lastScreen!.stateHash;
  }

  Future<void> _advance(ReplaySession s) async {
    s.currentStep++;
    s.actionPending = false;
    s.manualStep = false;
    s.stepRecoveryAttempts = 0;
    await _save(s);
  }

  Future<bool> _safe(UiNode? tree) async {
    if (CredentialGuard.isSensitiveScreen(tree)) return false;
    try {
      return !await _bridge.isSensitiveScreen();
    } catch (_) {
      return false;
    }
  }

  Future<void> _wait(ReplaySession s, String question) async {
    if (_stopRequested) return;
    s.pause(question);
    s.clarificationCount++;
    _resumeSignal = Completer<void>();
    await _save(s);
    _emit(s, question, question: question);
    if (!_stopRequested) await _resumeSignal!.future;
    _resumeSignal = null;
    if (!_stopRequested) {
      s.resume();
      await _save(s);
      if (s.currentStep < s.flow.steps.length) await _openTargetApp(s.flow.appPackage);
    }
  }

  void pause() {
    if (_running) _pauseRequested = true;
  }

  void resume({
    Map<String, dynamic> slots = const {},
    bool stepCompleted = false,
  }) {
    final s = _session;
    if (s == null || _resumeSignal == null) return;
    if (stepCompleted) {
      final step = s.flow.steps[s.currentStep];
      if (s.actionPending || s.manualStep || step.action == 'stop_before') {
        s.currentStep++;
        s.actionPending = false;
        s.manualStep = false;
        s.stepRecoveryAttempts = 0;
      }
    }
    s.slots.addAll(slots);
    _pauseRequested = false;
    if (!_resumeSignal!.isCompleted) _resumeSignal!.complete();
  }

  void stop() {
    _stopRequested = true;
    if (_resumeSignal != null && !_resumeSignal!.isCompleted) {
      _resumeSignal!.complete();
    }
  }

  Future<bool> _openTargetApp(String package) async {
    if (_stopRequested) return false;
    if (package.isEmpty || _belongs(await _bridge.getLastTree(), package)) {
      return true;
    }
    if (!await _bridge.openApp(package)) return false;
    for (var i = 0; i < 12 && !_stopRequested; i++) {
      await Future<void>.delayed(stepDelay);
      if (_belongs(await _bridge.getLastTree(), package)) return true;
    }
    return false;
  }

  bool _belongs(UiNode? tree, String package) =>
      tree != null && tree.flatten().any((n) => n.packageName == package);
  Set<String> _roles(UiNode tree) =>
      tree.flatten().map(RoleOntology.inferRole).whereType<String>().toSet();
  ScreenSnapshot _snapshot(UiNode tree) => ScreenSnapshot.fromTree(
    tree,
    rolesForNode: (n) => [RoleOntology.inferRole(n)].whereType<String>(),
  );
  String _value(FlowStep step, Map<String, dynamic> slots) =>
      (step.valueSlot != null
          ? slots[step.valueSlot]?.toString()
          : step.valueLiteral) ??
      '';

  Future<bool> _performAction(
    FlowStep step,
    UiNode target,
    Map<String, dynamic> slots,
  ) async {
    final b = target.bounds;
    final x = ((b['left'] ?? 0) + (b['right'] ?? 0)) / 2;
    final y = ((b['top'] ?? 0) + (b['bottom'] ?? 0)) / 2;
    switch (step.action) {
      case 'tap':
      case 'select':
        return _bridge.tap(x, y);
      case 'type':
      case 'set_quantity':
        final value = _value(step, slots);
        if (value.isEmpty ||
            value == '<REDACTED>' ||
            !await _bridge.tap(x, y)) {
          return false;
        }
        if (_stopRequested ||
            _pauseRequested ||
            !await _safe(await _bridge.getLastTree())) {
          return false;
        }
        return _bridge.typeIntoFocused(value);
      case 'swipe':
      case 'scroll':
        final dx = (step.scrollDeltaX ?? 0) == 0
            ? 0
            : (step.scrollDeltaX! > 0 ? -150 : 150);
        final dy = (step.scrollDeltaY ?? 0) < 0 ? 150 : -150;
        return _bridge.swipe(x - dx, y - dy, x, y, durationMs: 300);
      default:
        return false;
    }
  }

  Future<ReplayState> _finish(
    ReplaySession s,
    ReplayStatus status,
    String message,
  ) async {
    s.status = status;
    s.endedAt = DateTime.now();
    await _save(s);
    return _emit(s, message);
  }

  ReplayState _emit(ReplaySession s, String message, {String? question}) {
    final state = ReplayState(
      status: s.status,
      currentStep: s.currentStep < s.flow.steps.length
          ? s.currentStep + 1
          : s.currentStep,
      totalSteps: s.flow.steps.length,
      message: message,
      clarificationQuestion: question,
    );
    if (!_disposed) _states.add(state);
    return state;
  }

  void dispose() {
    stop();
    _disposed = true;
    _states.close();
  }
}

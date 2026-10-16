import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models/flow.dart';
import 'models/action_trace_event.dart';
import 'models/chat_message.dart';
import 'models/replay_session.dart';
import 'services/accessibility_bridge.dart';
import 'services/conversation_service.dart';
import 'services/slot_extractor.dart';
import 'services/asr_service.dart';
import 'services/flow_store.dart';
import 'services/flow_matcher.dart';
import 'services/replay_engine.dart';
import 'services/flow_synthesizer.dart';
import 'services/clarification_service.dart';
import 'services/intent_model.dart';
import 'models/execution_report.dart';
import 'services/execution_reporter.dart';

enum AppState {
  idle,
  listening,
  teaching,
  synthesizing,
  matching,
  executing,
  waitingForClarification,
  error,
}

enum ClarificationContext {
  unknownIntent,
  flowNeedsClarification,
  flowLowConfidence,
  replayStuck,
}

class AppController extends ChangeNotifier {
  AppController({
    AccessibilityBridge? bridge,
    AsrService? asr,
    FlowStore? store,
    ConversationService? conversation,
    LocalIntentModel? intentModel,
  }) : _bridge = bridge ?? AccessibilityBridge(),
       _asr = asr ?? AsrService(),
       _store = store ?? FlowStore(),
       _conversation = conversation ?? ConversationService(),
       _localModel = intentModel ?? LocalIntentModel();
  final ConversationService _conversation;
  bool _processing = false;
  String? _pendingInterruption;
  bool _disposed = false;
  int _turn = 0;
  ReplaySession? _recovered;
  bool get hasActiveTask => _initialized && _replay.isActive;
  void _say(String text) {
    if (_disposed) return;
    _statusMessage = text;
    unawaited(_bridge.speak(text));
    addMessage(
      ChatMessage(
        text: text,
        type: ChatMessageType.agentResult,
        timestamp: DateTime.now(),
      ),
    );
  }

  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  void addMessage(ChatMessage msg) {
    _messages.add(msg);
    notifyListeners();
  }

  final AccessibilityBridge _bridge;
  final AsrService _asr;
  final FlowStore _store;
  late final FlowMatcher _matcher;
  late final ReplayEngine _replay;
  late final FlowSynthesizer _synthesizer;
  late final ClarificationService _clarification;
  final LocalIntentModel _localModel;
  late final ExecutionReporter _reporter;

  AppState _state = AppState.idle;
  AppState get state => _state;

  List<ExecutionReport> get executionReports =>
      _initialized ? _reporter.reports : [];
  Map<String, dynamic> get reportStatistics =>
      _initialized ? _reporter.statistics : {};

  String _statusMessage = 'Ready';
  String get statusMessage => _statusMessage;

  List<Flow> _flows = [];
  List<Flow> get flows => _flows;

  // Teach mode state
  List<ActionTraceEvent> _actionTrace = [];
  StreamSubscription<List<ActionTraceEvent>>? _teachSubscription;
  String? _teachUtterance;
  Flow? _lastSynthesizedFlow;
  Flow? get lastSynthesizedFlow => _lastSynthesizedFlow;

  // Replay state
  ReplayState? _replayState;
  ReplayState? get replayState => _replayState;
  StreamSubscription? _replaySubscription;

  // Clarification
  String? _clarificationQuestion;
  String? get clarificationQuestion => _clarificationQuestion;
  ClarificationContext? _clarificationContext;
  bool get isTeachConfirmation =>
      _clarificationContext == ClarificationContext.unknownIntent;
  String? _pendingUtterance;
  Flow? _pendingFlow;
  List<Flow> _pendingCandidates = [];
  Map<String, dynamic>? _pendingSlots;

  bool _isAccessibilityEnabled = false;
  bool get isAccessibilityEnabled => _isAccessibilityEnabled;

  bool _initialized = false;

  Future<void> initialize() async {
    try {
      _clarification = ClarificationService();
      await _localModel.initialize();
      _reporter = ExecutionReporter(_store);
      await _reporter.loadFromStore();
      _matcher = FlowMatcher(_store, localModel: _localModel);
      _replay = ReplayEngine(
        _bridge,
        _clarification,
        saveCheckpoint: _store.saveCheckpoint,
      );
      _synthesizer = FlowSynthesizer();
      _initialized = true;
      try {
        await _asr.initialize();
      } catch (_) {}
      try {
        await _store.loadEmbeddingsIntoMemory();
        _flows = await _store.getAllFlows();
      } catch (_) {}
      await checkAccessibility();
      await _checkRecoverTeaching();
      _recovered = await _store.loadCheckpoint();
      if (_recovered != null) {
        _say(
          'I saved your unfinished task: ${_recovered!.flow.triggerIntent}. Say resume task to review and continue, or cancel to discard it.',
        );
      } else {
        _say(
          _flows.isEmpty
              ? 'Hi, I’m SAAR. Teach me a task with “teach me to …”, or configure a local model in Settings to chat naturally.'
              : 'Welcome back. I remember ${_flows.length} learned skills, including ${_flows.last.triggerIntent}. What would you like to do?',
        );
      }
    } catch (e) {
      debugPrint('AppController init error: $e');
      _state = AppState.error;
      _say('Could not initialize local storage. Please restart SAAR.');
    }
    notifyListeners();
  }

  Future<void> _checkRecoverTeaching() async {
    try {
      final isRecording = await _bridge.isRecording();
      if (isRecording) {
        _state = AppState.teaching;
        _teachUtterance = await _loadPendingTeach() ?? 'Recovered Task';
        _statusMessage = 'Recording recovered...';
        _actionTrace = [];
      }
    } catch (_) {}
  }

  Future<void> _savePendingTeach(String utterance) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/pending_teach.txt');
      await file.writeAsString(utterance);
    } catch (_) {}
  }

  Future<String?> _loadPendingTeach() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/pending_teach.txt');
      if (await file.exists()) {
        final text = await file.readAsString();
        await file.delete();
        return text;
      }
    } catch (_) {}
    return null;
  }

  Future<void> checkAccessibility() async {
    try {
      _isAccessibilityEnabled = await _bridge.isServiceEnabled();
    } catch (_) {
      _isAccessibilityEnabled = false;
    }
    notifyListeners();
  }

  Future<void> openAccessibilitySettings() async {
    await _bridge.openAccessibilitySettings();
  }

  /// Start listening for voice input (push-to-talk)
  Future<void> startListening() async {
    if (_state == AppState.listening) return;
    await _bridge.stopSpeaking();

    final previousState = _state;
    if (hasActiveTask) _replay.pause();
    if (!hasActiveTask) _state = AppState.listening;
    _statusMessage = 'Listening...';
    notifyListeners();

    String? transcript;
    try {
      transcript = await _asr.listenOnce();
    } catch (e) {
      debugPrint('ASR failure: $e');
    }

    if (transcript == null || transcript.isEmpty) {
      _state = previousState;
      _statusMessage = _asr.lastError ?? 'No speech detected. Try again.';
      notifyListeners();
      return;
    }

    if (!hasActiveTask) _state = previousState;
    await submitTypedCommand(transcript);
  }

  /// Run a typed command, used as the fallback when voice is unavailable.
  Future<void> submitTypedCommand(String utterance) async {
    await _bridge.stopSpeaking();
    final text = utterance.trim();
    if (text.isEmpty) return;
    addMessage(
      ChatMessage(
        text: text,
        type: ChatMessageType.user,
        timestamp: DateTime.now(),
      ),
    );
    final lower = text.toLowerCase().replaceAll(RegExp(r'[.!?]+$'), '');
    if (['stop', 'cancel', 'stop task', 'cancel task'].contains(lower)) {
      _turn++;
      stopExecution();
      _recovered = null;
      if (_initialized) await _store.clearCheckpoint();
      _say('Task cancelled.');
      return;
    }
    if (!_initialized) {
      _say('SAAR is still starting. Please try again in a moment.');
      return;
    }
    if (['pause', 'wait', 'hold on'].contains(lower) && hasActiveTask) {
      _replay.pause();
      _say('Pausing at the next action boundary. Your progress is kept.');
      return;
    }
    if (_clarificationContext != null) {
      await provideClarification(text);
      return;
    }
    if (_recovered != null &&
        ['resume', 'resume task', 'continue'].contains(lower)) {
      final checkpoint = _recovered!;
      _recovered = null;
      await _executeFlow(
        checkpoint.flow,
        checkpoint.slots,
        checkpoint: checkpoint,
      );
      return;
    }
    if (hasActiveTask) {
      _replay.pause();
      _pendingInterruption = text;
      _say('I’m pausing your task to apply your change.');
      return;
    }
    if (_processing ||
        _state == AppState.synthesizing ||
        _state == AppState.teaching) {
      _say('Finish the current request or teaching session first.');
      return;
    }
    _processing = true;
    final turn = ++_turn;
    try {
      if (lower.startsWith('teach')) {
        await _processUtterance(text);
        return;
      }
      if ([
        'hi',
        'hello',
        'hey',
        'what can you do',
        'what have i taught you',
      ].contains(lower)) {
        _say(
          _flows.isEmpty
              ? 'Hi! I can learn a task by watching you, then reuse it with new inputs. Say “teach me to search for a product” to begin.'
              : 'I remember: ${_flows.map((f) => f.triggerIntent).join('; ')}. Which task would you like?',
        );
        return;
      }
      _statusMessage = 'Thinking…';
      notifyListeners();
      final decision = await _conversation.respond(
        text,
        _messages.take(_messages.length - 1).toList(),
        _flows,
      );
      if (turn != _turn || _disposed) return;
      if (decision == null) {
        final parsed = await _localModel.parse(text);
        if (parsed.isUnknown) {
          _say(
            'Natural conversation needs a local model connection in Settings. You can still teach a task or use an exact learned command.',
          );
        } else {
          await _startCommand(text, parsed.slots);
        }
      } else if (decision.kind == 'run' && decision.confidence >= 0.8) {
        final flow = _flows.singleWhere((f) => f.flowId == decision.flowId);
        _pendingFlow = flow;
        _pendingSlots = {
          for (final slot in flow.slots) slot.name: decision.slots[slot.name],
        };
        final missing = _pendingSlots!.entries
            .where((e) => e.value == null)
            .map((e) => e.key)
            .toList();
        _clarificationContext = missing.isEmpty
            ? ClarificationContext.flowLowConfidence
            : ClarificationContext.flowNeedsClarification;
        _clarificationQuestion = missing.isEmpty
            ? 'Run “${flow.triggerIntent}” with ${decision.slots}? Say yes to start.'
            : 'What ${missing.first} should I use?';
        _state = AppState.waitingForClarification;
        _say(_clarificationQuestion!);
      } else {
        _say(decision.reply);
      }
    } catch (e) {
      if (turn == _turn) {
        _say(
          'I could not get a reliable model response. Check the model connection in Settings. No new task was started.',
        );
      }
      debugPrint('Conversation error: $e');
    } finally {
      _processing = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _processUtterance(String utterance) async {
    _statusMessage = 'Understanding: "$utterance"';
    notifyListeners();
    final lower = utterance.toLowerCase();
    if (lower.startsWith('teach') || lower.contains('teach me')) {
      String intent = utterance;
      if (lower.startsWith('teach me how to ')) {
        intent = utterance.substring(16);
      } else if (lower.startsWith('teach me to ')) {
        intent = utterance.substring(12);
      } else if (lower.startsWith('teach me ')) {
        intent = utterance.substring(9);
      } else if (lower.startsWith('teach ')) {
        intent = utterance.substring(6);
      } else {
        // Fallback for "teach me" anywhere else
        intent = utterance
            .replaceAll(
              RegExp(
                r'(teach me how to|teach me to|teach me|teach)\s*',
                caseSensitive: false,
              ),
              '',
            )
            .trim();
      }
      if (intent.isEmpty) intent = utterance;
      await _startTeaching(intent, intent);
      return;
    }
    try {
      await _startCommand(utterance, {});
    } catch (e, stack) {
      debugPrint('CRITICAL ERROR in processUtterance: $e\n$stack');
      _state = AppState.idle;
      _statusMessage = 'I didn\'t understand that. Try saying "teach me to..." or "order..."';
      notifyListeners();
    }
  }

  Future<void> _startTeaching(String utterance, String taskDescription) async {
    await checkAccessibility();
    if (!_isAccessibilityEnabled) {
      _state = AppState.error;
      _statusMessage =
          'Enable the SAAR accessibility service before teaching a flow.';
      notifyListeners();
      return;
    }

    _state = AppState.teaching;
    _teachUtterance = utterance;
    _statusMessage = 'Recording your actions... Perform the task now.';
    _actionTrace = [];
    await _savePendingTeach(utterance);
    notifyListeners();

    // Start teach session via bridge
    _teachSubscription?.cancel();
    final stream = await _bridge.startTeachSession();
    _teachSubscription = stream.listen((events) {
      _actionTrace.addAll(events);
      _statusMessage = 'Recording... ${_actionTrace.length} actions captured';
      notifyListeners();
    });
  }

  Future<void> stopTeaching() async {
    _state = AppState.synthesizing;
    _statusMessage = 'Analyzing your actions...';
    notifyListeners();

    _teachSubscription?.cancel();
    _teachSubscription = null;

    try {
      final finalTrace = await _bridge.stopTeachSession();
      _actionTrace = finalTrace;

      if (_actionTrace.isEmpty) {
        _state = AppState.error;
        _statusMessage = 'No actions recorded. Make sure you tapped something!';
        notifyListeners();
        return;
      }

      // Synthesize flow
      final flow = await _synthesizer.synthesize(
        _teachUtterance ?? 'Recovered Task',
        _actionTrace,
      );
      _lastSynthesizedFlow = flow;

      // Save flow and embedding
      await _store.saveFlow(flow);
      final embedding = await _localModel.embed(flow.triggerIntent);
      await _store.saveEmbedding(flow.flowId, embedding);
      await _store.loadEmbeddingsIntoMemory();
      _flows = await _store.getAllFlows();

      await _store.logSession(
        flowId: flow.flowId,
        sessionType: 'teach',
        status: 'success',
      );

      _state = AppState.idle;
      _say(
        'I learned ${flow.triggerIntent}. You can now reuse it with different inputs.',
      );
      await _loadPendingTeach();
      notifyListeners();
    } catch (e) {
      _state = AppState.error;
      _statusMessage = 'Error synthesizing flow: $e';
      notifyListeners();
    }
  }

  Future<void> _startCommand(
    String utterance,
    Map<String, dynamic> extractedSlots,
  ) async {
    _state = AppState.matching;
    _statusMessage = 'Finding matching flow...';
    notifyListeners();

    try {
      final turn = _turn;
      final result = await _matcher.match(
        utterance,
        extractedSlots: extractedSlots,
      );

      if (turn != _turn || _disposed) return;
      if (result.isUnknown) {
        _state = AppState.waitingForClarification;
        _clarificationQuestion = "I don't have a learned workflow for that task. Would you like to teach me?";
        _statusMessage = _clarificationQuestion!;
        _clarificationContext = ClarificationContext.unknownIntent;
        _pendingUtterance = utterance;
        notifyListeners();
        return;
      }

      if (result.flow != null &&
          result.needsClarification &&
          result.resolvedSlots.values.every((v) => v != null)) {
        _pendingFlow = result.flow;
        _pendingCandidates = result.candidates;
        _pendingSlots = result.resolvedSlots;
        _clarificationContext = ClarificationContext.flowLowConfidence;
        _clarificationQuestion = result.clarificationQuestion;
        _state = AppState.waitingForClarification;
        _say(_clarificationQuestion ?? 'Run this workflow?');
        return;
      }
      if (result.needsClarification || result.flow == null) {
        _state = AppState.waitingForClarification;
        _clarificationQuestion =
            result.clarificationQuestion ??
            'I couldn\'t find a matching flow. Could you be more specific?';
        _statusMessage = _clarificationQuestion!;
        _clarificationContext = ClarificationContext.flowNeedsClarification;
        _pendingUtterance = utterance;
        _pendingSlots = result.resolvedSlots;
        _pendingFlow = result.flow;
        _pendingCandidates = result.candidates;
        notifyListeners();
        return;
      }

      if (result.confidence < 0.4) {
        _state = AppState.waitingForClarification;
        _clarificationQuestion =
            'I found "${result.flow!.triggerIntent}" but I\'m not very confident. Should I proceed?';
        _statusMessage = _clarificationQuestion!;
        _clarificationContext = ClarificationContext.flowLowConfidence;
        _pendingFlow = result.flow;
        _pendingCandidates = result.candidates;
        _pendingSlots = result.resolvedSlots;
        notifyListeners();
        return;
      }

      await _executeFlow(result.flow!, result.resolvedSlots);
    } catch (e) {
      _state = AppState.error;
      _statusMessage = 'Error: $e';
      notifyListeners();
    }
  }

  Future<void> _executeFlow(
    Flow flow,
    Map<String, dynamic> slotValues, {
    ReplaySession? checkpoint,
  }) async {
    if (!_isAccessibilityEnabled) {
      await checkAccessibility();
      if (!_isAccessibilityEnabled) {
        _state = AppState.error;
        _statusMessage =
            'Enable the SAAR accessibility service before running a flow.';
        notifyListeners();
        return;
      }
    }

    _state = AppState.executing;
    notifyListeners();

    await _replaySubscription?.cancel();
    _replaySubscription = _replay.stateStream.listen((replayState) {
      _replayState = replayState;
      _statusMessage = replayState.message ?? 'Executing...';

      if (replayState.status == ReplayStatus.waitingForUser) {
        _state = AppState.waitingForClarification;
        _clarificationQuestion = replayState.clarificationQuestion;
        _clarificationContext = ClarificationContext.replayStuck;
        final interruption = _pendingInterruption;
        _pendingInterruption = null;
        if (interruption != null) unawaited(provideClarification(interruption));
      }

      notifyListeners();
    });

    ReplayState? result;
    String? failure;
    try {
      result = await _replay.execute(flow, slotValues, checkpoint: checkpoint);
    } catch (e) {
      failure = 'Could not run the flow: $e';
      debugPrint('Replay failure: $e');
    } finally {
      await _replaySubscription?.cancel();
      _replaySubscription = null;
    }

    final session = _replay.session;
    final report = ExecutionReport(
      runId: session?.runId ?? 'unknown',
      flowId: flow.flowId,
      flowName: flow.triggerIntent,
      status: _reportStatusFor(result),
      stepsCompleted: session?.currentStep ?? 0,
      totalSteps: flow.steps.length,
      recoveriesAttempted: session?.recoveryAttempts ?? 0,
      clarificationsRequested: session?.clarificationCount ?? 0,
      reason: failure ?? result?.message,
      startTime: session?.startedAt ?? DateTime.now(),
      endTime: DateTime.now(),
    );
    try {
      await _reporter.save(report);
    } catch (e) {
      debugPrint('Failed to save execution report: $e');
    }

    _replayState = null;
    _clarificationQuestion = null;
    _clarificationContext = null;
    _state = failure != null ? AppState.error : AppState.idle;
    _say(failure ?? result?.message ?? 'Finished execution.');
    notifyListeners();
  }

  ReportStatus _reportStatusFor(ReplayState? result) {
    switch (result?.status) {
      case ReplayStatus.completed:
        return ReportStatus.completed;
      case ReplayStatus.cancelled:
        return ReportStatus.cancelled;
      default:
        return ReportStatus.halted;
    }
  }

  void stopExecution() {
    // Also required while waiting for clarification: the replay engine is
    // parked on a resume signal that only stop() can release.
    if (_initialized) _replay.stop();
    _state = AppState.idle;
    _statusMessage = 'Execution stopped';
    _replayState = null;
    _clarificationQuestion = null;
    _clarificationContext = null;
    notifyListeners();
  }

  Future<void> provideClarification(String response) async {
    final ctx = _clarificationContext;
    _clarificationQuestion = null;
    _clarificationContext = null;

    final lower = response.trim().toLowerCase();
    final approved = [
      'yes',
      'yes please',
      'yeah',
      'sure',
      'proceed',
    ].contains(lower);

    if (ctx == ClarificationContext.unknownIntent) {
      if (approved) {
        await _startTeaching(_pendingUtterance ?? '', _pendingUtterance ?? '');
      } else {
        _state = AppState.idle;
        _statusMessage = 'Ok, cancelling.';
        notifyListeners();
      }
      return;
    }

    if (ctx == ClarificationContext.flowNeedsClarification) {
      if (_pendingFlow == null && _pendingCandidates.isNotEmpty) {
        final index = int.tryParse(response.trim());
        final byName = _pendingCandidates.where(
          (f) => f.triggerIntent.toLowerCase() == lower,
        );
        if (index != null && index >= 1 && index <= _pendingCandidates.length) {
          _pendingFlow = _pendingCandidates[index - 1];
        } else if (byName.length == 1) {
          _pendingFlow = byName.single;
        } else {
          _clarificationContext = ctx;
          _clarificationQuestion =
              'Choose a workflow number: ${List.generate(_pendingCandidates.length, (i) => "${i + 1}. ${_pendingCandidates[i].triggerIntent}").join("; ")}';
          _say(_clarificationQuestion!);
          return;
        }
        final flow = _pendingFlow!;
        _pendingSlots = {
          for (final slot in flow.slots) slot.name: _pendingSlots?[slot.name],
        };
        _pendingCandidates = [];
        final missing = _pendingSlots!.entries
            .where((e) => e.value == null)
            .toList();
        _clarificationContext = missing.isEmpty
            ? ClarificationContext.flowLowConfidence
            : ctx;
        _clarificationQuestion = missing.isEmpty
            ? 'Run “${flow.triggerIntent}” with $_pendingSlots? Say yes to start.'
            : 'What ${missing.first.key} should I use?';
        _say(_clarificationQuestion!);
        return;
      }
      final flow = _pendingFlow;
      if (flow != null) {
        final values = _pendingSlots ?? <String, dynamic>{};
        final missing = flow.slots
            .where((s) => values[s.name] == null)
            .toList();
        if (missing.isNotEmpty) values[missing.first.name] = response.trim();
        final remaining = flow.slots
            .where((s) => values[s.name] == null)
            .toList();
        _pendingSlots = values;
        _clarificationContext = remaining.isEmpty
            ? ClarificationContext.flowLowConfidence
            : ctx;
        _clarificationQuestion = remaining.isEmpty
            ? 'Run “${flow.triggerIntent}” with $values? Say yes to start.'
            : 'What ${remaining.first.name} should I use?';
        _say(_clarificationQuestion!);
        return;
      }
      await _processUtterance("$_pendingUtterance $response");
      return;
    }

    if (ctx == ClarificationContext.flowLowConfidence) {
      final pending = _pendingFlow;
      if (pending != null && approved) {
        await _executeFlow(pending, _pendingSlots ?? {});
      } else {
        _state = AppState.idle;
        _statusMessage = 'Ok, cancelling.';
        notifyListeners();
      }
      return;
    }

    if (ctx == ClarificationContext.replayStuck) {
      if (!['continue', 'resume', 'done', 'step completed'].contains(lower)) {
        final updates = SlotExtractor().extract(response);
        final names = _replay.session!.flow.slots.map((s) => s.name).toSet();
        updates.removeWhere((key, value) => !names.contains(key));
        if (updates.isEmpty || _replay.session!.actionPending) {
          _clarificationContext = ctx;
          _clarificationQuestion = 'Your task is paused. Say continue to retry observing the screen, step completed if you completed it manually, or cancel.';
          _say(_clarificationQuestion!);
          return;
        }
        final used = _replay.session!.flow.steps
            .take(_replay.session!.currentStep)
            .map((s) => s.valueSlot)
            .toSet();
        if (updates.keys.any(used.contains)) {
          _clarificationContext = ctx;
          _clarificationQuestion = 'That value was already used. Change it in the app, then say continue, or cancel and start with the new value.';
          _say(_clarificationQuestion!);
          return;
        }
        _replay.resume(slots: updates);
      } else {
        _replay.resume(stepCompleted: lower == 'step completed');
      }
      _state = AppState.executing;
      _statusMessage = 'Continuing...';
      notifyListeners();
      return;
    }

    _state = AppState.idle;
    notifyListeners();
  }

  Future<void> deleteFlow(String flowId) async {
    await _store.deleteFlow(flowId);
    _flows = await _store.getAllFlows();
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _turn++;
    _teachSubscription?.cancel();
    _replaySubscription?.cancel();
    try {
      if (_initialized) _replay.dispose();
    } catch (_) {}
    super.dispose();
  }
}

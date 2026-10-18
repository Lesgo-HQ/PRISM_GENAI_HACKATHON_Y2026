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
import 'services/adaptive_agent.dart';
import 'services/memory_context.dart';
import 'models/agent_task.dart';
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
  agentApp,
  agentConfirm,
  agentInput,
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
  AdaptiveAgent? _agent;
  AgentTask? _agentRecovered;
  String? _agentGoal;
  String? _agentPackage;
  List<Map<String, dynamic>> _availableApps = [];
  StreamSubscription<String>? _controlSubscription;
  bool _processing = false;
  String? _pendingInterruption;
  bool _disposed = false;
  int _turn = 0;
  ReplaySession? _recovered;
  bool get hasActiveTask =>
      _initialized && (_replay.isActive || (_agent?.running ?? false));
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
      _flows = await _store.getAllFlows();
      // A damaged optional search index must not hide persisted workflows.
      try {
        await _store.loadEmbeddingsIntoMemory();
      } catch (e) {
        debugPrint('Could not load workflow search index: $e');
      }
      await checkAccessibility();
      await _checkRecoverTeaching();
      _agentRecovered = await _store.loadAgentCheckpoint();
      _conversation.memory = await _store.readMemory('user');
      _controlSubscription = _bridge.agentControls.listen((command) {
        if (command == 'talk') {
          startListening();
        } else {
          submitTypedCommand(command);
        }
      }, onError: (_) {});
      _recovered = await _store.loadCheckpoint();
      if (_agentRecovered != null) {
        _say(
          'Your adaptive task is saved: ${_agentRecovered!.goal}. Say resume task to continue or cancel.',
        );
      } else if (_recovered != null) {
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

  Future<String?> _loadPendingTeach({bool clear = false}) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/pending_teach.txt');
      if (await file.exists()) {
        final text = await file.readAsString();
        if (clear) await file.delete();
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
    if (hasActiveTask) {
      _replay.pause();
      _agent?.pause();
    }
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
    if (_state == AppState.teaching &&
        ['stop', 'stop recording', 'save recording', 'done'].contains(lower)) {
      await stopTeaching();
      return;
    }
    if (['stop', 'cancel', 'stop task', 'cancel task'].contains(lower)) {
      _turn++;
      if (_state == AppState.teaching) {
        await _teachSubscription?.cancel();
        _teachSubscription = null;
        await _bridge.stopTeachSession();
        _actionTrace = [];
        await _loadPendingTeach(clear: true);
      }
      stopExecution();
      _recovered = null;
      _agentRecovered = null;
      if (_initialized) {
        await _store.clearCheckpoint();
        await _store.clearAgentCheckpoint();
      }
      _say('Task cancelled.');
      return;
    }
    if (!_initialized) {
      _say('SAAR is still starting. Please try again in a moment.');
      return;
    }
    if (['pause', 'wait', 'hold on'].contains(lower) && hasActiveTask) {
      _replay.pause();
      _agent?.pause();
      _say('Pausing at the next action boundary. Your progress is kept.');
      return;
    }
    if (_clarificationContext != null) {
      await provideClarification(text);
      return;
    }
    if (_agentRecovered != null &&
        ['resume', 'resume task', 'continue'].contains(lower)) {
      final task = _agentRecovered!;
      _agentRecovered = null;
      await _runAgent(task);
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
      _agent?.pause();
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
    if (lower.startsWith('remember ')) {
      final content = '${_conversation.memory}\n${text.substring(9).trim()}'
          .trim();
      try {
        await _store.writeMemory('user', content);
        _conversation.memory = content;
        _say('I saved that in your local memory.');
      } catch (_) {
        _say('Could not save memory. Keep it under 8 KB.');
      }
      return;
    }
    if (lower == 'forget my preferences') {
      await _store.writeMemory('user', '');
      _conversation.memory = '';
      _say('Your saved preferences are cleared.');
      return;
    }
    if (lower.startsWith('do ')) {
      await _prepareAgent(text.substring(3));
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
              ? 'Hi! I can operate an app with “do …”, or learn a task by watching you and reuse it with new inputs. Say “teach me to search for a product” to begin.'
              : 'I remember: ${_flows.map((f) => f.triggerIntent).join('; ')}. Which task would you like?',
        );
        return;
      }
      _statusMessage = 'Thinking…';
      notifyListeners();
      final exact = await _matcher.matchExact(text);
      if (turn != _turn || _disposed) return;
      if (exact != null) {
        await _startCommand(text, {}, match: exact);
        return;
      }
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
      } else if (decision.kind == 'run' ||
          (decision.kind == 'clarify' && decision.flowId != null)) {
        final flow = _flows.singleWhere((f) => f.flowId == decision.flowId);
        _pendingFlow = flow;
        _pendingSlots = {
          for (final slot in flow.slots)
            slot.name: decision.slots[slot.name] ?? slot.defaultValue,
        };
        final missing = _pendingSlots!.entries
            .where((e) => e.value == null)
            .map((e) => e.key)
            .toList();
        _clarificationContext = missing.isEmpty
            ? ClarificationContext.flowLowConfidence
            : ClarificationContext.flowNeedsClarification;
        final review = decision.kind == 'clarify' ? '${decision.reply}\n' : '';
        _clarificationQuestion = missing.isEmpty
            ? '${review}Run “${flow.triggerIntent}” with $_pendingSlots? Say yes to start.'
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
    final turn = _turn;
    await checkAccessibility();
    if (_disposed || turn != _turn) return;
    if (!_isAccessibilityEnabled) {
      _state = AppState.error;
      _statusMessage =
          'Enable the SAAR accessibility service before teaching a flow.';
      notifyListeners();
      return;
    }

    _teachUtterance = utterance;
    _actionTrace = [];
    await _savePendingTeach(utterance);
    try {
      await _teachSubscription?.cancel();
      final stream = await _bridge.startTeachSession();
      _teachSubscription = stream.listen(
        (events) {
          _actionTrace.addAll(events);
          _statusMessage =
              'Recording... ${_actionTrace.length} actions captured';
          notifyListeners();
        },
        onError: (Object error) {
          _statusMessage = 'Live recording updates interrupted. Return here and stop to save the captured actions.';
          notifyListeners();
        },
      );
      _state = AppState.teaching;
      _statusMessage = 'Recording your actions... Perform the task now.';
    } catch (e) {
      _state = AppState.error;
      _statusMessage = 'Could not start recording. Check accessibility access and try again.';
      await _loadPendingTeach(clear: true);
    }
    notifyListeners();
  }

  Future<void> stopTeaching() async {
    if (_state != AppState.teaching) return;
    _state = AppState.synthesizing;
    _statusMessage = 'Saving your demonstration...';
    notifyListeners();

    await _teachSubscription?.cancel();
    _teachSubscription = null;

    try {
      final finalTrace = await _bridge.stopTeachSession();
      if (finalTrace.isNotEmpty) _actionTrace = finalTrace;

      if (_actionTrace.isEmpty) {
        _state = AppState.error;
        _statusMessage = 'No actions recorded. Make sure accessibility is enabled, then demonstrate the task again.';
        notifyListeners();
        return;
      }

      final flow = await _synthesizer.synthesize(
        _teachUtterance ?? 'Recovered Task',
        _actionTrace,
      );
      await _store.saveFlow(flow);
      _lastSynthesizedFlow = flow;
      _flows = await _store.getAllFlows();
      // Exact reuse depends only on the committed flow, not this optional index.
      try {
        final embedding = await _localModel.embed(flow.triggerIntent);
        await _store.saveEmbedding(flow.flowId, embedding);
        await _store.loadEmbeddingsIntoMemory();
      } catch (e) {
        debugPrint('Workflow saved; search index unavailable: $e');
      }
      try {
        await _store.logSession(
          flowId: flow.flowId,
          sessionType: 'teach',
          status: 'success',
        );
      } catch (e) {
        debugPrint('Workflow saved; session log unavailable: $e');
      }
      await _loadPendingTeach(clear: true);
      _state = AppState.idle;
      final manual = flow.steps
          .where((step) => step.action == 'stop_before')
          .length;
      _say(
        'Saved “${flow.triggerIntent}” with ${flow.steps.length} steps. '
        'Say the same command to reuse it.'
        '${manual > 0 ? ' $manual steps need your help because their targets were sensitive or unreadable.' : ''}',
      );
      notifyListeners();
    } catch (e) {
      _state = AppState.error;
      _statusMessage = 'Error synthesizing flow: $e';
      notifyListeners();
    }
  }

  Future<void> _startCommand(
    String utterance,
    Map<String, dynamic> extractedSlots, {
    MatchResult? match,
  }) async {
    _state = AppState.matching;
    _statusMessage = 'Finding matching flow...';
    notifyListeners();

    try {
      final turn = _turn;
      final result =
          match ??
          await _matcher.match(utterance, extractedSlots: extractedSlots);

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

      _pendingFlow = result.flow;
      _pendingSlots = result.resolvedSlots;
      _clarificationContext = ClarificationContext.flowLowConfidence;
      _clarificationQuestion =
          'Run “${result.flow!.triggerIntent}” with ${result.resolvedSlots}? Say yes to start.';
      _state = AppState.waitingForClarification;
      _say(_clarificationQuestion!);
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
      unawaited(_bridge.updateCapsule(_statusMessage));

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

    unawaited(_bridge.updateCapsule(null));
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
    _agent?.stop();
    unawaited(_bridge.updateCapsule(null));
    _state = AppState.idle;
    _statusMessage = 'Execution stopped';
    unawaited(_bridge.updateCapsule(null));
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

    if (ctx == ClarificationContext.agentApp) {
      final number = int.tryParse(response.trim());
      final names = _availableApps
          .where(
            (a) =>
                (a['appName'] as String).toLowerCase() == lower ||
                a['packageName'] == response.trim(),
          )
          .toList();
      final selected =
          number != null && number > 0 && number <= _availableApps.length
          ? _availableApps[number - 1]
          : (names.length == 1 ? names.single : null);
      if (selected == null) {
        _clarificationContext = ctx;
        _clarificationQuestion =
            'Choose an installed app by number or exact name.';
        _say(_clarificationQuestion!);
        return;
      }
      _agentPackage = selected['packageName'] as String;
      _clarificationContext = ClarificationContext.agentConfirm;
      _clarificationQuestion =
          'Let SAAR operate ${selected['appName']} to “$_agentGoal”? The current screen text will be sent to your configured model. Say yes to start.';
      _say(_clarificationQuestion!);
      return;
    }
    if (ctx == ClarificationContext.agentConfirm) {
      if (approved) {
        await _runAgent(
          AgentTask(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            goal: _agentGoal!,
            package: _agentPackage!,
          ),
        );
      } else {
        _state = AppState.idle;
        _say('Task cancelled.');
      }
      return;
    }
    if (ctx == ClarificationContext.agentInput) {
      _agent?.resume(response);
      _state = AppState.executing;
      _statusMessage = 'Continuing with your update…';
      notifyListeners();
      return;
    }

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
          for (final slot in flow.slots)
            slot.name: _pendingSlots?[slot.name] ?? slot.defaultValue,
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

  Future<void> _prepareAgent(String goal) async {
    final turn = ++_turn;
    if (goal.trim().isEmpty) {
      _say('Tell me the task after “do”.');
      return;
    }
    await checkAccessibility();
    if (_disposed || turn != _turn) return;
    if (!_isAccessibilityEnabled) {
      _say(
        'Enable accessibility in Settings before asking me to operate an app.',
      );
      return;
    }
    try {
      _availableApps = (await _bridge.installedApps())
          .where((a) => a['packageName'] != 'com.lesgo.saar')
          .toList();
      if (_disposed || turn != _turn) return;
      final seen = <String>{};
      _availableApps.removeWhere((a) => !seen.add(a['packageName'] as String));
      _availableApps.sort(
        (a, b) => (a['appName'] as String).compareTo(b['appName'] as String),
      );
      if (_availableApps.isEmpty) {
        _say('No launchable apps were found.');
        return;
      }
      _agentGoal = goal;
      _state = AppState.waitingForClarification;
      _clarificationContext = ClarificationContext.agentApp;
      _clarificationQuestion =
          'Which app should I use?\n${_availableApps.asMap().entries.map((e) => "${e.key + 1}. ${e.value['appName']}").join("\n")}';
      _say(_clarificationQuestion!);
    } catch (_) {
      _say('Could not read installed apps. Check accessibility access.');
    }
  }

  Future<void> _runAgent(AgentTask task) async {
    if (hasActiveTask) {
      _say('Pause or finish the current task first.');
      return;
    }
    _state = AppState.executing;
    _agent = AdaptiveAgent(
      bridge: _bridge,
      checkpoint: _store.saveAgentCheckpoint,
      onStatus: (message, waiting) {
        _statusMessage = message;
        _state = waiting
            ? AppState.waitingForClarification
            : AppState.executing;
        _clarificationContext = waiting
            ? ClarificationContext.agentInput
            : null;
        _clarificationQuestion = waiting ? message : null;
        unawaited(_bridge.updateCapsule(message));
        if (waiting && _pendingInterruption != null) {
          final update = _pendingInterruption!;
          _pendingInterruption = null;
          unawaited(provideClarification(update));
        }
        notifyListeners();
      },
    );
    try {
      await _agent!.run(
        task,
        _flows,
        memory: MemoryContext.recall(
          user: _conversation.memory,
          app: await _store.readMemory(task.package),
        ),
      );
      if (task.status == 'completed') {
        await _store.writeMemory(
          task.package,
          'Previously verified task: ${task.goal}'.substring(
            0,
            ('Previously verified task: ${task.goal}').length.clamp(0, 2000),
          ),
        );
      }
    } catch (_) {
      if (task.status != 'completed' && task.status != 'cancelled') {
        task.status = 'paused';
      }
      _statusMessage = 'Task interrupted. Check storage and model connection before resuming.';
    } finally {
      _agentRecovered = task.status == 'paused' ? task : null;
      _clarificationContext = null;
      _clarificationQuestion = null;
      _state = AppState.idle;
      await _bridge.updateCapsule(null);
      _say(_statusMessage);
    }
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
    _controlSubscription?.cancel();
    _agent?.stop();
    unawaited(_bridge.updateCapsule(null));
    _replaySubscription?.cancel();
    try {
      if (_initialized) _replay.dispose();
    } catch (_) {}
    super.dispose();
  }
}

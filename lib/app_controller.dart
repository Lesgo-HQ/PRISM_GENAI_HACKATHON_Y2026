import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'models/flow.dart';
import 'models/action_trace_event.dart';
import 'models/replay_session.dart';
import 'services/accessibility_bridge.dart';
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
  final AccessibilityBridge _bridge = AccessibilityBridge();
  final AsrService _asr = AsrService();
  late final FlowStore _store;
  late final FlowMatcher _matcher;
  late final ReplayEngine _replay;
  late final FlowSynthesizer _synthesizer;
  late final ClarificationService _clarification;
  late final LocalIntentModel _localModel;
  late final ExecutionReporter _reporter;

  AppState _state = AppState.idle;
  AppState get state => _state;

  List<ExecutionReport> get executionReports => _reporter.reports;
  Map<String, dynamic> get reportStatistics => _reporter.statistics;

  String _statusMessage = 'Ready';
  String get statusMessage => _statusMessage;

  List<Flow> _flows = [];
  List<Flow> get flows => _flows;

  // Teach mode state
  List<ActionTraceEvent> _actionTrace = [];
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
  Map<String, dynamic>? _pendingSlots;

  bool _isAccessibilityEnabled = false;
  bool get isAccessibilityEnabled => _isAccessibilityEnabled;

  bool _initialized = false;

  Future<void> initialize() async {
    try {
      _store = FlowStore();
      _clarification = ClarificationService();
      _localModel = LocalIntentModel();
      await _localModel.initialize();
      _reporter = ExecutionReporter(_store);
      await _reporter.loadFromStore();
      _matcher = FlowMatcher(_store, localModel: _localModel);
      _replay = ReplayEngine(_bridge, _clarification);
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
    } catch (e) {
      debugPrint('AppController init error: $e');
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
    _state = AppState.listening;
    _statusMessage = 'Listening...';
    notifyListeners();

    final transcript = await _asr.listenOnce();
    if (transcript == null || transcript.isEmpty) {
      _state = AppState.idle;
      _statusMessage = 'No speech detected. Try again.';
      notifyListeners();
      return;
    }

    await _processUtterance(transcript);
  }

  Future<void> _processUtterance(String utterance) async {
    _statusMessage = 'Understanding: "$utterance"';
    notifyListeners();
    final lower = utterance.toLowerCase();
    if (lower.startsWith('teach') || lower.contains('teach me')) {
      await _startTeaching(utterance, utterance);
      return;
    }
    try {
      await _startCommand(utterance, {});
    } catch (e, stack) {
      print('CRITICAL ERROR in processUtterance: $e\n$stack');
      _state = AppState.idle;
      _statusMessage = 'I didn\'t understand that. Try saying "teach me to..." or "order..."';
      notifyListeners();
    }
  }

  Future<void> _startTeaching(String utterance, String taskDescription) async {
    _state = AppState.teaching;
    _teachUtterance = utterance;
    _statusMessage = 'Recording your actions... Perform the task now.';
    _actionTrace = [];
    await _savePendingTeach(utterance);
    notifyListeners();

    // Start teach session via bridge
    final stream = _bridge.startTeachSession();
    stream.listen((events) {
      _actionTrace.addAll(events);
      _statusMessage = 'Recording... ${_actionTrace.length} actions captured';
      notifyListeners();
    });
  }

  Future<void> stopTeaching() async {
    _state = AppState.synthesizing;
    _statusMessage = 'Analyzing your actions...';
    notifyListeners();

    try {
      final finalTrace = await _bridge.stopTeachSession();
      _actionTrace.addAll(finalTrace);

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
      final embedding = [
        0.0,
      ]; // bypass localModel embed for now since we're using ONNX directly
      await _store.saveEmbedding(flow.flowId, embedding);
      await _store.loadEmbeddingsIntoMemory();
      _flows = await _store.getAllFlows();

      await _store.logSession(
        flowId: flow.flowId,
        sessionType: 'teach',
        status: 'success',
      );

      _state = AppState.idle;
      _statusMessage = 'Flow saved: ${flow.triggerIntent}';
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
      final result = await _matcher.match(
        utterance,
        extractedSlots: extractedSlots,
      );

      if (result.isUnknown) {
        _state = AppState.waitingForClarification;
        _clarificationQuestion = "I don't have a learned workflow for that task. Would you like to teach me?";
        _statusMessage = _clarificationQuestion!;
        _clarificationContext = ClarificationContext.unknownIntent;
        _pendingUtterance = utterance;
        notifyListeners();
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
        _pendingSlots = extractedSlots;
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

  Future<void> _executeFlow(Flow flow, Map<String, dynamic> slotValues) async {
    _state = AppState.executing;
    notifyListeners();

    _replaySubscription = _replay.stateStream.listen((replayState) {
      _replayState = replayState;
      _statusMessage = replayState.message ?? 'Executing...';

      if (replayState.status == ReplayStatus.waitingForUser) {
        _state = AppState.waitingForClarification;
        _clarificationQuestion = replayState.clarificationQuestion;
        _clarificationContext = ClarificationContext.replayStuck;
      }

      notifyListeners();
    });

    final result = await _replay.execute(flow, slotValues);
    _replaySubscription?.cancel();

    final session = _replay.session;
    final report = ExecutionReport(
      runId: session?.runId ?? 'unknown',
      flowId: flow.flowId,
      flowName: flow.triggerIntent,
      status: result.status == ReplayStatus.completed
          ? ReportStatus.completed
          : ReportStatus.halted,
      stepsCompleted: session?.currentStep ?? 0,
      totalSteps: flow.steps.length,
      recoveriesAttempted: session?.recoveryAttempts ?? 0,
      clarificationsRequested: session?.clarificationCount ?? 0,
      reason: result.message,
      startTime: session?.startedAt ?? DateTime.now(),
      endTime: DateTime.now(),
    );
    await _reporter.save(report);

    _state = AppState.idle;
    _statusMessage = result.message ?? 'Finished execution.';
    notifyListeners();
  }

  void stopExecution() {
    if (_state == AppState.executing) {
      _replay.stop();
    }
    _state = AppState.idle;
    _statusMessage = 'Execution stopped';
    _replayState = null;
    notifyListeners();
  }

  Future<void> provideClarification(String response) async {
    final ctx = _clarificationContext;
    _clarificationQuestion = null;
    _clarificationContext = null;

    final lower = response.toLowerCase();

    if (ctx == ClarificationContext.unknownIntent) {
      if (lower.contains('yes') ||
          lower.contains('yeah') ||
          lower.contains('sure')) {
        await _startTeaching(_pendingUtterance ?? '', _pendingUtterance ?? '');
      } else {
        _state = AppState.idle;
        _statusMessage = 'Ok, cancelling.';
        notifyListeners();
      }
      return;
    }

    if (ctx == ClarificationContext.flowNeedsClarification) {
      await _processUtterance("$_pendingUtterance $response");
      return;
    }

    if (ctx == ClarificationContext.flowLowConfidence) {
      if (lower.contains('yes') ||
          lower.contains('yeah') ||
          lower.contains('sure')) {
        await _executeFlow(_pendingFlow!, _pendingSlots ?? {});
      } else {
        _state = AppState.idle;
        _statusMessage = 'Ok, cancelling.';
        notifyListeners();
      }
      return;
    }

    if (ctx == ClarificationContext.replayStuck) {
      _replay.resume();
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
  void dispose() {
    _replaySubscription?.cancel();
    try {
      if (_initialized) _replay.dispose();
    } catch (_) {}
    super.dispose();
  }
}

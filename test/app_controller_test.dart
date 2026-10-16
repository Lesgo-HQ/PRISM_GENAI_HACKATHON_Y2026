import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:saar/app_controller.dart';
import 'package:saar/models/chat_message.dart';
import 'package:saar/models/agent_task.dart';
import 'package:saar/models/flow.dart';
import 'package:saar/models/parsed_intent.dart';
import 'package:saar/models/replay_session.dart';
import 'package:saar/services/accessibility_bridge.dart';
import 'package:saar/services/asr_service.dart';
import 'package:saar/services/conversation_service.dart';
import 'package:saar/services/flow_store.dart';
import 'package:saar/services/intent_model.dart';

class MemoryStore extends FlowStore {
  MemoryStore({this.saved = const [], List<FlowEmbedding>? embeddings})
    : seeded = embeddings ?? const [];
  final List<Flow> saved;
  final List<FlowEmbedding> seeded;
  @override
  Future<List<Flow>> getAllFlows() async => saved;
  @override
  Future<Flow?> getFlow(String flowId) async {
    for (final flow in saved) {
      if (flow.flowId == flowId) return flow;
    }
    return null;
  }

  @override
  List<FlowEmbedding> get embeddings => seeded;
  @override
  Future<List<Map<String, dynamic>>> getSessionLogs({int limit = 50}) async =>
      [];
  @override
  Future<void> loadEmbeddingsIntoMemory() async {}
  @override
  Future<ReplaySession?> loadCheckpoint() async => null;
  @override
  Future<void> clearCheckpoint() async {}
  @override
  Future<AgentTask?> loadAgentCheckpoint() async => null;
  @override
  Future<void> clearAgentCheckpoint() async {}
  @override
  Future<String> readMemory(String scope) async => '';

  @override
  Future<void> logSession({
    required String? flowId,
    required String sessionType,
    required String status,
    String? details,
  }) async {}
}

class SilentBridge extends AccessibilityBridge {
  @override
  Stream<String> get agentControls => const Stream.empty();
  @override
  Future<void> updateCapsule(String? message) async {}
  @override
  Future<bool> isServiceEnabled() async => false;
  @override
  Future<bool> isRecording() async => false;
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stopSpeaking() async {}
}

class NoSpeech extends AsrService {
  @override
  Future<bool> initialize() async => false;
}

class Baseline extends LocalIntentModel {
  @override
  Future<void> initialize() async {}
}

class DelayedConversation extends ConversationService {
  final result = Completer<ConversationDecision?>();
  final started = Completer<void>();
  @override
  Future<ConversationDecision?> respond(
    String text,
    List<ChatMessage> messages,
    List<Flow> flows,
  ) {
    started.complete();
    return result.future;
  }
}

class ScriptedConversation extends ConversationService {
  ScriptedConversation(this.replies);
  final List<ConversationDecision?> replies;
  int calls = 0;
  @override
  Future<ConversationDecision?> respond(
    String text,
    List<ChatMessage> messages,
    List<Flow> flows,
  ) async => calls < replies.length ? replies[calls++] : null;
}

class RankedModel extends LocalIntentModel {
  @override
  Future<void> initialize() async {}
  @override
  Future<ParsedIntent> parse(String text) async =>
      ParsedIntent(intent: 'search', slots: const {}, confidence: 0.6);
  @override
  Future<List<double>> embed(String text) async {
    final lower = text.toLowerCase();
    if (lower.contains('amazon')) return [1.0, 0.0];
    if (lower.contains('zepto')) return [0.0, 1.0];
    return [0.735, 0.678];
  }
}

Flow _skill(String id, String goal) => Flow(
  flowId: id,
  appPackage: 'shop',
  triggerIntent: goal,
  exampleUtterances: const [],
  slots: [Slot(name: 'query')],
  steps: const [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('cancel invalidates a model response that arrives later', () async {
    final conversation = DelayedConversation();
    final app = AppController(
      store: MemoryStore(),
      bridge: SilentBridge(),
      asr: NoSpeech(),
      intentModel: Baseline(),
      conversation: conversation,
    );
    await app.initialize();
    final request = app.submitTypedCommand('Tell me about coffee');
    await conversation.started.future;
    await app.submitTypedCommand('cancel');
    conversation.result.complete(
      const ConversationDecision('chat', 'Stale reply', null, {}, 1),
    );
    await request;
    expect(app.messages.any((m) => m.text == 'Stale reply'), isFalse);
    expect(app.statusMessage, 'Task cancelled.');
    expect(app.state, AppState.idle);
    app.dispose();
  });

  test(
    'verified skill still requires an explicit yes before execution',
    () async {
      final search = _skill('search', 'Search the catalog for coffee');
      final app = AppController(
        store: MemoryStore(saved: [search]),
        bridge: SilentBridge(),
        asr: NoSpeech(),
        intentModel: Baseline(),
        conversation: ScriptedConversation([
          const ConversationDecision('run', 'Ready', 'search', {
            'query': 'pizza',
          }, 0.95),
        ]),
      );
      await app.initialize();
      await app.submitTypedCommand('Search the catalog for pizza');
      expect(app.state, AppState.waitingForClarification);
      expect(app.hasActiveTask, isFalse);
      expect(app.statusMessage, contains('Say yes'));
      await app.submitTypedCommand('1');
      expect(app.state, AppState.idle);
      expect(app.statusMessage, 'Ok, cancelling.');
      app.dispose();
    },
  );

  test(
    'yes after skill confirmation does not invent accessibility access',
    () async {
      final search = _skill('search', 'Search the catalog for coffee');
      final app = AppController(
        store: MemoryStore(saved: [search]),
        bridge: SilentBridge(),
        asr: NoSpeech(),
        intentModel: Baseline(),
        conversation: ScriptedConversation([
          const ConversationDecision('run', 'Ready', 'search', {
            'query': 'pizza',
          }, 0.95),
        ]),
      );
      await app.initialize();
      await app.submitTypedCommand('Search the catalog for pizza');
      await app.submitTypedCommand('yes');
      expect(app.hasActiveTask, isFalse);
      expect(
        app.statusMessage,
        contains('Enable the SAAR accessibility service'),
      );
      app.dispose();
    },
  );

  test('chat replies are shown instead of a fake analyzing message', () async {
    final app = AppController(
      store: MemoryStore(),
      bridge: SilentBridge(),
      asr: NoSpeech(),
      intentModel: Baseline(),
      conversation: ScriptedConversation([
        const ConversationDecision('chat', 'Coffee is a drink.', null, {}, 1),
      ]),
    );
    await app.initialize();
    await app.submitTypedCommand('Why do people buy coffee?');
    expect(app.messages.any((m) => m.text == 'Coffee is a drink.'), isTrue);
    expect(
      app.messages.any((m) => m.text.contains('Analyzing command')),
      isFalse,
    );
    expect(app.hasActiveTask, isFalse);
    app.dispose();
  });

  test(
    'numbered clarification selects that workflow instead of rematching',
    () async {
      final amazon = _skill('amazon-search', 'Search Amazon');
      final zepto = _skill('zepto-search', 'Search Zepto');
      final app = AppController(
        store: MemoryStore(
          saved: [amazon, zepto],
          embeddings: [
            FlowEmbedding(flowId: amazon.flowId, vector: const [1.0, 0.0]),
            FlowEmbedding(flowId: zepto.flowId, vector: const [0.0, 1.0]),
          ],
        ),
        bridge: SilentBridge(),
        asr: NoSpeech(),
        intentModel: RankedModel(),
        conversation: ScriptedConversation([null]),
      );
      await app.initialize();
      await app.submitTypedCommand('search for headphones');
      expect(app.state, AppState.waitingForClarification);
      expect(app.clarificationQuestion, contains('1. Search Amazon'));
      await app.submitTypedCommand('1');
      expect(app.clarificationQuestion, contains('Search Amazon'));
      expect(app.clarificationQuestion, contains('Say yes to start'));
      expect(app.hasActiveTask, isFalse);
      app.dispose();
    },
  );
}

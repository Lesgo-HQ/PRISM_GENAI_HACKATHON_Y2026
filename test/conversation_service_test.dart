import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:saar/models/chat_message.dart';
import 'package:saar/models/flow.dart';
import 'package:saar/services/conversation_service.dart';
import 'package:saar/services/intent_model.dart';
import 'package:saar/services/llm_client.dart';

class ScriptedClient extends LlmClient {
  ScriptedClient(this.replies);
  final List<String?> replies;
  final prompts = <String>[];
  int calls = 0;
  @override
  Future<String?> generateContent(
    String prompt, {
    String? systemInstruction,
    List<Map<String, String>> history = const [],
    Map<String, dynamic>? schema,
    String schemaName = 'saar_decision',
  }) async {
    prompts.add(prompt);
    return calls < replies.length ? replies[calls++] : null;
  }
}

void main() {
  final skill = Flow(
    flowId: 'search',
    appPackage: 'shop',
    triggerIntent: 'Search the catalog for coffee',
    exampleUtterances: [],
    slots: [Slot(name: 'query')],
    steps: [],
  );
  Map<String, dynamic> decision({
    String kind = 'run',
    String flowId = 'search',
    Map<String, dynamic>? slots,
    double confidence = 0.9,
    String reply = 'Ready',
  }) => {
    'kind': kind,
    'reply': reply,
    'flow_id': kind == 'run' ? flowId : null,
    'slots': slots ?? {'query': 'pizza'},
    'confidence': confidence,
  };
  Future<ConversationDecision?> decide(String text, List<String?> replies) {
    return ConversationService(client: ScriptedClient(replies))
        .respond(text, const <ChatMessage>[], [skill]);
  }

  test('accepts a known skill with typed parameters', () {
    final result = ConversationDecision.parse(jsonEncode(decision()), [skill]);
    expect(result.slots['query'], 'pizza');
  });
  test('rejects invented skill, parameters and malformed confidence', () {
    for (final invalid in [
      decision()..['flow_id'] = 'invented',
      decision()..['slots'] = {'amount': 500},
      decision()..['confidence'] = 3,
      decision()
        ..['slots'] = {
          'query': {'code': 'execute'},
        },
    ]) {
      expect(
        () => ConversationDecision.parse(jsonEncode(invalid), [skill]),
        throwsFormatException,
      );
    }
  });

  test('compatible catalog search can run after verification', () async {
    final result = await decide('Search the catalog for pizza', [
      jsonEncode(decision()),
      '{"matches":true}',
    ]);
    expect(result?.kind, 'run');
    expect(result?.flowId, 'search');
    expect(result?.slots['query'], 'pizza');
  });

  test(
    'model confidence cannot map money transfer onto catalog search',
    () async {
      final client = ScriptedClient([
        jsonEncode(
          decision(
            reply: 'Sending money',
            slots: {'query': '500'},
            confidence: 0.99,
          ),
        ),
        '{"matches":true}',
      ]);
      final result = await ConversationService(client: client).respond(
        'Transfer 500 rupees to my friend',
        const <ChatMessage>[],
        [skill],
      );
      expect(result?.kind, 'clarify');
      expect(result?.flowId, isNull);
      expect(client.calls, 1);
    },
  );

  test('travel request does not reuse a search skill', () async {
    final result = await decide('Book a flight to Tokyo', [
      jsonEncode(decision(slots: {'query': 'Tokyo'})),
      '{"matches":true}',
    ]);
    expect(result?.kind, 'clarify');
  });

  test('unverified or malformed skill match does not run', () async {
    for (final verify in [
      null,
      'not-json',
      '{"matches":false}',
      '{"matches":"true"}',
    ]) {
      final result = await decide('Find headphones in the catalog', [
        jsonEncode(decision(slots: {'query': 'headphones'})),
        verify,
      ]);
      expect(result?.kind, 'clarify', reason: '$verify');
    }
  });

  test('ordinary chat skips skill verification', () async {
    final client = ScriptedClient([
      jsonEncode(
        decision(kind: 'chat', reply: 'Coffee is a drink.', slots: {}),
      ),
    ]);
    final result = await ConversationService(client: client)
        .respond('Why do people buy coffee?', const <ChatMessage>[], [skill]);
    expect(result?.kind, 'chat');
    expect(result?.reply, 'Coffee is a drink.');
    expect(client.calls, 1);
  });

  test('keyword fallback does not treat questions as actions', () async {
    final model = LocalIntentModel();
    expect((await model.parse('Why do people buy coffee?')).isUnknown, isTrue);
    expect((await model.parse('Tell me a short joke')).isUnknown, isTrue);
    expect((await model.parse('Search for pizza')).intent, 'search');
  });

  test('operation families distinguish search from transfer and purchase', () {
    expect(operationFamily('Search the catalog for pizza'), 'search');
    expect(operationFamily('Find headphones'), 'search');
    expect(operationFamily('Transfer 500 rupees to my friend'), 'transfer');
    expect(operationFamily('Book a flight to Tokyo'), 'travel');
    expect(operationFamily('Buy coffee'), 'purchase');
    expect(operationFamily('hello'), isNull);
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:saar/models/flow.dart';
import 'package:saar/models/chat_message.dart';
import 'package:saar/models/skill_assessment.dart';
import 'package:saar/services/app_catalog.dart';
import 'package:saar/services/conversation_service.dart';

import 'conversation_service_test.dart' show ScriptedClient;

final note = Flow(
  flowId: 'note',
  appPackage: 'dev.lab.a17',
  triggerIntent: 'Create a note',
  exampleUtterances: ['Write a memo'],
  slots: [Slot(name: 'content', defaultValue: 'Shopping list')],
  steps: [],
);
String routed(String content) => jsonEncode({
  'kind': 'run',
  'reply': 'Ready',
  'flow_id': 'note',
  'slots': {'content': content},
  'confidence': 0.9,
});
String assessed(String verdict) =>
    jsonEncode({'verdict': verdict, 'reason': 'Assessment explanation'});

void main() {
  test('app routing uses installed labels even with opaque package names', () {
    final catalog = AppCatalog(
      installed: {'dev.lab.a17': 'Paper Pad', 'org.other.z9': 'Daylight'},
    );
    expect(catalog.explicitDestinations('Make a list in Paper Pad'), {
      'dev.lab.a17',
    });
    expect(catalog.explicitDestinations('Set a timer using Daylight'), {
      'org.other.z9',
    });
    expect(catalog.explicitDestinations('Find Paper Pad stickers'), isEmpty);
  });
  test('equivalent procedures require an explicit app even when model is confident', () async {
    final other = Flow(
      flowId: 'other-note',
      appPackage: 'dev.other',
      triggerIntent: note.triggerIntent,
      exampleUtterances: [],
      slots: note.slots,
      steps: [],
    );
    final client = ScriptedClient([routed('milk'), assessed('supported')]);
    final service = ConversationService(client: client)
      ..appNames = {
        note.appPackage: 'Paper Pad',
        other.appPackage: 'Cloud Memo',
      };
    final result = await service.respond('Write down milk', [], [note, other]);
    expect(result?.kind, 'clarify');
    expect(result?.flowId, isNull);
    expect(client.calls, 1);
  });
  test('unknown brands cannot be silently substituted', () async {
    final client = ScriptedClient([routed('milk'), assessed('supported')]);
    final service = ConversationService(client: client)
      ..appNames = {'dev.lab.a17': 'Paper Pad', 'org.other.z9': 'Cloud Memo'};
    final result = await service.respond('Write milk in Cloud Memo', [], [
      note,
    ]);
    expect(result?.flowId, isNull);
    expect(client.calls, 1);
  });
  test('semantic review accepts indirect and Hinglish action wording without verb rules', () async {
    for (final text in [
      'I need milk and bread written down',
      'Paper Pad mein doodh aur bread likh do',
    ]) {
      final client = ScriptedClient([
        routed('milk and bread'),
        assessed('review'),
      ]);
      final service = ConversationService(client: client)
        ..appNames = {'dev.lab.a17': 'Paper Pad'};
      final result = await service.respond(text, [], [note]);
      expect(result?.kind, 'clarify');
      expect(result?.flowId, 'note');
      expect(result?.slots['content'], 'milk and bread');
    }
  });
  test('ambiguity, negation and unsupported meaning never create a runnable candidate', () async {
    for (final verdict in ['ambiguous', 'not_action', 'unsupported']) {
      final service = ConversationService(
        client: ScriptedClient([routed('milk'), assessed(verdict)]),
      );
      final result = await service.respond('Put that on my list', [], [note]);
      expect(result?.kind, 'clarify');
      expect(result?.flowId, isNull);
    }
  });
  test(
    'semantic verification receives the context needed to resolve a follow-up',
    () async {
      final client = ScriptedClient([routed('milk'), assessed('supported')]);
      final service = ConversationService(client: client)
        ..appNames = {'dev.lab.a17': 'Paper Pad'};
      final result = await service.respond(
        'In Paper Pad',
        [
          ChatMessage(
            text: 'Write down milk',
            type: ChatMessageType.user,
            timestamp: DateTime.now(),
          ),
          ChatMessage(
            text: 'Which app?',
            type: ChatMessageType.agentQuestion,
            timestamp: DateTime.now(),
          ),
        ],
        [note],
      );
      expect(result?.kind, 'run');
      final input = jsonDecode(client.prompts[1]);
      expect(input['conversation_context'][0]['content'], 'Write down milk');
      expect(input['selected_procedure']['app_name'], 'Paper Pad');
    },
  );
  test(
    'assessment parser rejects invented verdicts and non-text explanations',
    () {
      for (final text in [
        '{"verdict":"run","reason":"yes"}',
        '{"verdict":"supported","reason":true}',
        '{"verdict":"supported","reason":""}',
      ]) {
        expect(() => SkillAssessment.parse(text), throwsFormatException);
      }
    },
  );
}

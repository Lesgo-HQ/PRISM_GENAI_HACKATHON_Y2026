import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saar/models/flow.dart';
import 'package:saar/models/agent_task.dart';
import 'package:saar/models/ui_node.dart';
import 'package:saar/services/action_verifier.dart';
import 'package:saar/services/conversation_service.dart';
import 'package:saar/services/llm_client.dart';

class LoggedClient extends LlmClient {
  @override
  Future<String?> generateContent(
    String prompt, {
    String? systemInstruction,
    List<Map<String, String>> history = const [],
    Map<String, dynamic>? schema,
    String schemaName = 'saar_decision',
  }) async {
    final response = await super.generateContent(
      prompt,
      systemInstruction: systemInstruction,
      history: history,
      schema: schema,
      schemaName: schemaName,
    );
    stdout.writeln(response);
    return response;
  }
}

// Opt-in integration test: never silently contacts a network service in CI.
void main() {
  final enabled = Platform.environment['SAAR_LIVE_MODEL'] == '1';
  test(
    'local model checks actual action outcome with the action verifier',
    () async {
      SharedPreferences.setMockInitialValues({
        'enable_llm': true,
        'model_endpoint':
            Platform.environment['SAAR_MODEL_ENDPOINT'] ??
            'http://127.0.0.1:8080/v1/chat/completions',
        'model_name': Platform.environment['SAAR_MODEL_NAME'] ?? 'local',
      });
      AgentObservation observed(String label) => AgentObservation(
        UiNode.fromJson({
          'packageName': 'test.shop',
          'text': label,
          'isClickable': true,
          'bounds': {'left': 0, 'top': 0, 'right': 100, 'bottom': 100},
          'children': [],
        }),
      );
      const action = AgentAction(
        'tap',
        0,
        '',
        'Open search results',
        'Search results for pizza',
      );
      final before = observed('Search for pizza');
      final success = await ActionVerifier.reflect(
        LoggedClient(),
        goal: 'Find pizza in the catalog',
        action: action,
        before: before,
        after: observed(
          'Search results for pizza: Margherita pizza, Cheese pizza',
        ),
      );
      expect(success.verified, isTrue);
      final wrongPage = await ActionVerifier.reflect(
        LoggedClient(),
        goal: 'Find pizza in the catalog',
        action: action,
        before: before,
        after: observed('Account settings: Profile, Notifications, Sign out'),
      );
      expect(wrongPage.verified, isFalse);
      AgentObservation bluetooth(bool checked) => AgentObservation(
        UiNode.fromJson({
          'packageName': 'com.android.settings',
          'text': 'Bluetooth settings',
          'children': [
            {
              'text': 'Bluetooth',
              'isClickable': true,
              'isCheckable': true,
              'isChecked': checked,
            },
            {'text': 'Device name'},
            {'text': 'Additional settings'},
          ],
        }),
      );
      for (final checked in [false, true]) {
        final result = await ActionVerifier.reflect(
          LoggedClient(),
          goal: 'Open Bluetooth settings without changing Bluetooth from off',
          action: const AgentAction(
            'tap',
            0,
            '',
            'Open Bluetooth settings',
            "Bluetooth settings should open with 'Bluetooth · Off' visible",
          ),
          before: AgentObservation(
            UiNode.fromJson({
              'packageName': 'com.android.settings',
              'text': 'Bluetooth · Off',
              'isClickable': true,
            }),
          ),
          after: bluetooth(checked),
        );
        expect(result.verified, !checked, reason: 'Bluetooth checked=$checked');
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 3)),
  );
  test(
    'local model routes unseen inputs and discussion against learned catalog',
    () async {
      SharedPreferences.setMockInitialValues({
        'enable_llm': true,
        'model_endpoint':
            Platform.environment['SAAR_MODEL_ENDPOINT'] ??
            'http://127.0.0.1:8080/v1/chat/completions',
        'model_name': Platform.environment['SAAR_MODEL_NAME'] ?? 'local',
      });
      final service = ConversationService(client: LoggedClient());
      final skills = [
        Flow(
          flowId: 'catalog-search',
          appPackage: 'test.shop',
          triggerIntent: 'Search the catalog for coffee',
          exampleUtterances: [],
          slots: [Slot(name: 'query', defaultValue: 'coffee')],
          steps: [],
        ),
      ];
      for (final request in [
        'Search the catalog for pizza',
        'Find headphones in the catalog',
      ]) {
        final result = await service.respond(request, [], skills);
        stdout.writeln(
          '$request => ${result?.kind}: ${result?.reply} ${result?.slots}',
        );
        expect(result, isNotNull);
        expect(result!.kind, 'run', reason: request);
        expect(result.flowId, 'catalog-search');
        expect(
          result.slots['query'],
          contains(request.contains('pizza') ? 'pizza' : 'headphones'),
        );
      }
      for (final request in [
        'Why do people buy coffee?',
        'Tell me a short joke',
        'Transfer 500 rupees to my friend',
        'Book a flight to Tokyo',
      ]) {
        final result = await service.respond(request, [], skills);
        stdout.writeln(
          '$request => ${result?.kind}: ${result?.reply} ${result?.slots}',
        );
        expect(result, isNotNull);
        expect(
          result!.kind,
          request == 'Why do people buy coffee?' ||
                  request == 'Tell me a short joke'
              ? 'chat'
              : 'clarify',
          reason: request,
        );
        expect(result.reply, isNotEmpty);
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 6)),
  );
  test(
    'local model understands varied intents across arbitrary apps',
    () async {
      SharedPreferences.setMockInitialValues({
        'enable_llm': true,
        'model_endpoint':
            Platform.environment['SAAR_MODEL_ENDPOINT'] ??
            'http://127.0.0.1:8080/v1/chat/completions',
        'model_name': Platform.environment['SAAR_MODEL_NAME'] ?? 'local',
      });
      final service = ConversationService(client: LoggedClient())
        ..appNames = {
          'dev.a17': 'Paper Pad',
          'dev.b28': 'MelodyBox',
          'dev.c39': 'MealNest',
          'dev.d40': 'Bazaar',
          'dev.e51': 'TwinTone',
        };
      Flow skill(String id, String app, String goal, String parameter) => Flow(
        flowId: id,
        appPackage: app,
        triggerIntent: goal,
        exampleUtterances: [],
        slots: [Slot(name: parameter)],
        steps: [],
      );
      final skills = [
        skill('notes', 'dev.a17', 'Create a note', 'content'),
        skill('music', 'dev.b28', 'Play a song', 'query'),
        skill('food', 'dev.c39', 'Order food', 'query'),
        skill('search', 'dev.d40', 'Search products', 'query'),
        skill('other-music', 'dev.e51', 'Play a song', 'query'),
      ];
      for (final example in [
        ('Put on Believer in MelodyBox', 'music', 'query'),
        ('Paper Pad mein doodh aur bread ki list bana do', 'notes', 'content'),
        ('I want a burger delivered from MealNest', 'food', 'query'),
        ('Could you look up wireless headphones in Bazaar?', 'search', 'query'),
      ]) {
        final result = await service.respond(example.$1, [], skills);
        stdout.writeln(
          '${example.$1} => ${result?.kind} ${result?.flowId} ${result?.slots} ${result?.reply}',
        );
        expect(result?.flowId, example.$2, reason: example.$1);
        expect(result?.slots[example.$3], isNotEmpty, reason: example.$1);
      }
      for (final request in [
        "Don't create a note in Paper Pad",
        'What does Paper Pad do?',
        'Play Believer',
      ]) {
        final result = await service.respond(request, [], skills);
        stdout.writeln(
          '$request => ${result?.kind} ${result?.flowId} ${result?.reply}',
        );
        expect(result, isNotNull);
        expect(result?.flowId, isNull, reason: request);
        expect(result?.kind, isNot('run'), reason: request);
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

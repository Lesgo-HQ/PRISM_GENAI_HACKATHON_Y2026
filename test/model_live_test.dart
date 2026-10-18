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
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saar/services/llm_client.dart';

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'enable_llm': true,
      'model_endpoint': 'http://127.0.0.1:8080/v1/chat/completions',
      'model_name': 'local',
    }),
  );
  test('connection check validates the structured-response path without screen data', () async {
    final client = LlmClient(
      client: MockClient((request) async {
        final body = jsonDecode(request.body);
        expect(
          body['response_format']['json_schema']['name'],
          'saar_connection_check',
        );
        expect(body['messages'].length, 1);
        expect(request.body, isNot(contains('observation')));
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': '{"ready":true}'},
              },
            ],
          }),
          200,
        );
      }),
    );
    expect(await client.connectionIssue(), isNull);
  });
  test('reachable server with invalid structure is not ready', () async {
    final client = LlmClient(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': '{"ready":false}'},
              },
            ],
          }),
          200,
        ),
      ),
    );
    expect(await client.connectionIssue(), contains('structured response'));
  });
  test('network failure tells phone user how to diagnose loopback', () async {
    final client = LlmClient(
      client: MockClient(
        (_) async => throw http.ClientException('Connection refused'),
      ),
    );
    expect(
      await client.connectionIssue(),
      contains('127.0.0.1 means the phone'),
    );
  });
  test('disabled model is reported without a network request', () async {
    SharedPreferences.setMockInitialValues({'enable_llm': false});
    var calls = 0;
    final client = LlmClient(
      client: MockClient((_) async {
        calls++;
        return http.Response('', 500);
      }),
    );
    expect(await client.connectionIssue(), contains('Enable the model'));
    expect(calls, 0);
  });
}

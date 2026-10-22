import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saar/services/llm_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final failure in [429, 503, 0]) {
    test(
      'Groq failure $failure falls back once without leaking its key',
      () async {
        FlutterSecureStorage.setMockInitialValues({
          'groq_api_key': 'test-secret',
        });
        SharedPreferences.setMockInitialValues({
          'enable_llm': true,
          'model_endpoint': 'https://api.groq.com/openai/v1/chat/completions',
          'model_name': 'openai/gpt-oss-20b',
          'ollama_fallback': true,
        });
        final hosts = <String>[];
        final client = LlmClient(
          client: MockClient((request) async {
            hosts.add(request.url.host);
            if (request.url.host == 'api.groq.com') {
              if (failure == 0) throw http.ClientException('offline');
              return http.Response('', failure);
            }
            expect(request.headers.containsKey('Authorization'), isFalse);
            final body = jsonDecode(request.body);
            expect(body['model'], 'qwen3:4b');
            expect(body['response_format']['type'], 'json_schema');
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
        expect(hosts, ['api.groq.com', '127.0.0.1']);
        expect(client.lastProvider, contains('Ollama fallback'));
      },
    );
  }
  test('Groq authentication failure does not silently fall back', () async {
    FlutterSecureStorage.setMockInitialValues({'groq_api_key': 'invalid'});
    SharedPreferences.setMockInitialValues({
      'enable_llm': true,
      'model_endpoint': 'https://api.groq.com/openai/v1/chat/completions',
      'ollama_fallback': true,
    });
    var calls = 0;
    final client = LlmClient(
      client: MockClient((request) async {
        calls++;
        return http.Response('', 401);
      }),
    );
    expect(await client.connectionIssue(), contains('API key rejected'));
    expect(calls, 1);
  });
  test(
    'Groq sends secure key and compatible JSON requests only to Groq',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'groq_api_key': 'test-secret',
      });
      SharedPreferences.setMockInitialValues({
        'enable_llm': true,
        'model_endpoint': 'https://api.groq.com/openai/v1/chat/completions',
        'model_name': 'openai/gpt-oss-20b',
      });
      final client = LlmClient(
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer test-secret');
          final body = jsonDecode(request.body);
          expect(body['reasoning_effort'], 'low');
          expect(body['response_format'], {'type': 'json_object'});
          expect(body['messages'].toString(), contains('schema'));
          expect(request.body, isNot(contains('test-secret')));
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'model_endpoint',
        'https://example.com/v1/chat/completions',
      );
      final other = LlmClient(
        client: MockClient((request) async {
          expect(request.headers.containsKey('Authorization'), isFalse);
          return http.Response('{}', 401);
        }),
      );
      expect(await other.connectionIssue(), contains('API key rejected'));
    },
  );
  test(
    'Groq refuses missing keys and insecure endpoints before network access',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({
        'enable_llm': true,
        'model_endpoint': 'https://api.groq.com/openai/v1/chat/completions',
      });
      final client = LlmClient(
        client: MockClient(
          (_) async => throw StateError('Network must not run'),
        ),
      );
      expect(
        await client.connectionIssue(),
        contains('Enter your Groq API key'),
      );
      await (await SharedPreferences.getInstance()).setString(
        'model_endpoint',
        'http://api.groq.com/openai/v1/chat/completions',
      );
      expect(await client.connectionIssue(), contains('Use https://'));
    },
  );
  test(
    'rate limit returns actionable message without provider response body',
    () async {
      final client = LlmClient(
        client: MockClient(
          (_) async => http.Response('private provider details', 429),
        ),
      );
      expect(await client.connectionIssue(), contains('rate limit'));
    },
  );
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
        expect(body['reasoning_effort'], 'none');
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

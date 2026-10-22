import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Configured OpenAI-compatible model server (Ollama, llama.cpp, etc.).
/// No bundled credentials, implicit cloud fallback, or fabricated success.
class LlmClient {
  static final LlmClient instance = LlmClient();
  final http.Client _http;
  String lastProvider = 'Not connected';
  LlmClient({http.Client? client}) : _http = client ?? http.Client();

  /// Check the same structured-response path needed by execution before
  /// switching away from SAAR. Never send screen data for this probe.
  Future<String?> connectionIssue() async {
    try {
      final raw = await generateContent(
        'Return {"ready":true}. This checks your structured response connection.',
        schemaName: 'saar_connection_check',
        schema: {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'ready': {'type': 'boolean', 'const': true},
          },
          'required': ['ready'],
        },
      );
      if (raw == null) {
        return 'Enable the model in SAAR Settings and test its connection before running an app task. flutter run alone does not start the model server.';
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['ready'] != true) {
        return 'The model did not return the required structured response. Check the server configuration in Settings.';
      }
      return null;
    } on TimeoutException {
      return 'The model connection timed out. Check Settings and confirm the server is running and reachable from this phone.';
    } on StateError catch (e) {
      return e.message.toString();
    } catch (_) {
      return 'Cannot connect to a compatible model server. Check Settings. On a phone, 127.0.0.1 means the phone itself unless USB port forwarding is configured.';
    }
  }

  Future<String?> generateContent(
    String prompt, {
    String? systemInstruction,
    List<Map<String, String>> history = const [],
    Map<String, dynamic>? schema,
    String schemaName = 'saar_decision',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('enable_llm') ?? false)) return null;
    final endpoint = prefs.getString('model_endpoint') ?? '';
    final modelName = prefs.getString('model_name') ?? 'local';
    lastProvider = 'Not connected';
    final uri = Uri.tryParse(endpoint);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Set a valid model endpoint in Settings.');
    }
    final response = await _http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': modelName,
            'messages': [
              if (systemInstruction != null)
                {'role': 'system', 'content': systemInstruction},
              ...history,
              {'role': 'user', 'content': prompt},
            ],
            'temperature': 0.2,
            // Interactive device actions cannot wait for a thinking-token budget.
            'reasoning_effort': 'none',
            'max_tokens': 768,
            if (schema != null)
              'response_format': {
                'type': 'json_schema',
                'json_schema': {
                  'name': schemaName,
                  'strict': true,
                  'schema': schema,
                },
              },
          }),
        )
        // CPU-hosted models need time to process a full accessibility screen.
        .timeout(const Duration(seconds: 120));
    if (response.statusCode != 200) {
      if (response.statusCode == 429) {
        throw StateError(
          'Model rate limit reached. Wait before retrying or check your provider quota.',
        );
      }
      if (response.statusCode >= 500 || response.statusCode == 408) {
        throw StateError(
          'Model server temporarily unavailable (HTTP ${response.statusCode}).',
        );
      }
      throw StateError('Model server returned HTTP ${response.statusCode}.');
    }
    if (response.body.length > 100000) {
      throw const FormatException('Model response too large.');
    }
    final body = jsonDecode(response.body);
    final content = body['choices']?[0]?['message']?['content'];
    if (content is! String || content.trim().isEmpty) {
      throw const FormatException('Model returned no answer.');
    }
    lastProvider = uri.host;
    return content.trim();
  }

  Future<String?> understandIntent(String utterance, List<String> knownFlows) =>
      generateContent(
        jsonEncode({'utterance': utterance, 'intents': knownFlows}),
        systemInstruction: 'Classify the requested action. Return JSON with intent (one of the supplied intents or unknown) and confidence (0 to 1).',
      );
}

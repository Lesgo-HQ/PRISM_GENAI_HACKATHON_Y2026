import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Groq or a configured local model, with an explicitly enabled local fallback.
class LlmClient {
  static const keyStorage = FlutterSecureStorage();
  static const groqKeyName = 'groq_api_key';
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
    lastProvider = 'Not connected';
    try {
      final result = await _request(
        prompt,
        endpoint: endpoint,
        model: prefs.getString('model_name') ?? 'local',
        systemInstruction: systemInstruction,
        history: history,
        schema: schema,
        schemaName: schemaName,
      );
      lastProvider = Uri.tryParse(endpoint)?.host == 'api.groq.com'
          ? 'Groq'
          : 'Local model';
      return result;
    } catch (error) {
      if (Uri.tryParse(endpoint)?.host != 'api.groq.com' ||
          !(prefs.getBool('ollama_fallback') ?? false) ||
          !(error is TimeoutException ||
              error is http.ClientException ||
              error is _RetryableModelError)) {
        rethrow;
      }
      final fallback =
          prefs.getString('ollama_endpoint') ??
          'http://127.0.0.1:11434/v1/chat/completions';
      if (Uri.tryParse(fallback)?.host == 'api.groq.com') {
        throw StateError(
          'Ollama fallback must use your local server endpoint.',
        );
      }
      try {
        final result = await _request(
          prompt,
          endpoint: fallback,
          model: prefs.getString('ollama_model') ?? 'qwen3:4b',
          systemInstruction: systemInstruction,
          history: history,
          schema: schema,
          schemaName: schemaName,
        );
        lastProvider = 'Ollama fallback (Groq unavailable)';
        return result;
      } catch (_) {
        throw StateError(
          'Groq is unavailable and Ollama fallback failed. Check the local server and USB forwarding.',
        );
      }
    }
  }

  Future<String> _request(
    String prompt, {
    required String endpoint,
    required String model,
    String? systemInstruction,
    required List<Map<String, String>> history,
    Map<String, dynamic>? schema,
    required String schemaName,
  }) async {
    final uri = Uri.tryParse(endpoint);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Set a valid model endpoint in Settings.');
    }
    final groq = uri.host.toLowerCase() == 'api.groq.com';
    String? apiKey;
    if (groq) {
      if (uri.scheme != 'https' ||
          uri.path != '/openai/v1/chat/completions' ||
          uri.hasQuery) {
        throw StateError(
          'Use https://api.groq.com/openai/v1/chat/completions for Groq.',
        );
      }
      apiKey = (await keyStorage.read(key: groqKeyName))?.trim();
      if (apiKey == null || apiKey.isEmpty) {
        throw StateError(
          'Enter your Groq API key in SAAR Settings, then save.',
        );
      }
    }
    final response = await _http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (apiKey != null) 'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              if (systemInstruction != null)
                {'role': 'system', 'content': systemInstruction},
              if (groq && schema != null)
                {
                  'role': 'system',
                  'content':
                      'Return only a JSON object matching this schema: ${jsonEncode(schema)}',
                },
              ...history,
              {'role': 'user', 'content': prompt},
            ],
            'temperature': 0.2,
            // Interactive device actions cannot wait for a thinking-token budget.
            if (!groq || model.startsWith('openai/gpt-oss-'))
              'reasoning_effort': groq ? 'low' : 'none',
            'max_tokens': groq ? 2048 : 768,
            // Groq JSON mode accepts our union action schemas; callers validate actions locally.
            if (groq && schema != null)
              'response_format': {'type': 'json_object'},
            if (!groq && schema != null)
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
        .timeout(Duration(seconds: groq ? 30 : 120));
    if (response.statusCode != 200) {
      if (response.statusCode == 401) {
        throw StateError('API key rejected. Check your Groq key in Settings.');
      }
      if (response.statusCode == 429) {
        throw _RetryableModelError(
          'Model rate limit reached. Wait before retrying or check your provider quota.',
        );
      }
      if (response.statusCode >= 500 || response.statusCode == 408) {
        throw _RetryableModelError(
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
    return content.trim();
  }

  Future<String?> understandIntent(String utterance, List<String> knownFlows) =>
      generateContent(
        jsonEncode({'utterance': utterance, 'intents': knownFlows}),
        systemInstruction: 'Classify the requested action. Return JSON with intent (one of the supplied intents or unknown) and confidence (0 to 1).',
      );
}

class _RetryableModelError extends StateError {
  _RetryableModelError(super.message);
}

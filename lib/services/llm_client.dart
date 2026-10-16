import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Explicitly configured OpenAI-compatible local model server (llama.cpp).
/// No bundled credentials, implicit cloud fallback, or fabricated success.
class LlmClient {
  static final LlmClient instance = LlmClient();
  final http.Client _http;
  LlmClient({http.Client? client}) : _http = client ?? http.Client();

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
    final uri = Uri.tryParse(endpoint);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw const FormatException('Set a valid model endpoint in Settings.');
    }
    final response = await _http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': prefs.getString('model_name') ?? 'local',
            'messages': [
              if (systemInstruction != null)
                {'role': 'system', 'content': systemInstruction},
              ...history,
              {'role': 'user', 'content': prompt},
            ],
            'temperature': 0.2,
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
        .timeout(const Duration(seconds: 45));
    if (response.statusCode != 200) {
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

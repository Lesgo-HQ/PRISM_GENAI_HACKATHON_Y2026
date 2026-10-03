import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// LLM client backed by Groq's OpenAI-compatible API.
///
/// Key resolution priority:
///   1. GROQ_API_KEY in .env file  (bundled asset — never committed to git)
///   2. 'groq_api_key' in SharedPreferences  (user entered in Settings screen)
///
/// Model: llama-3.1-8b-instant — fast, free, great for intent classification.
/// Docs : https://console.groq.com/docs/openai
class LlmClient {
  static final LlmClient instance = LlmClient._internal();
  LlmClient._internal();

  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const _defaultModel = 'llama-3.1-8b-instant';

  // ── Key resolution ────────────────────────────────────────────────────────

  /// Returns the first non-empty key found, or null.
  Future<String?> _apiKey() async {
    // 1. .env file (highest priority)
    final envKey = dotenv.maybeGet('GROQ_API_KEY');
    if (envKey != null && envKey.isNotEmpty && !envKey.startsWith('gsk_placeholder')) {
      return envKey;
    }
    // 2. SharedPreferences (entered by user in Settings screen)
    final prefs = await SharedPreferences.getInstance();
    final userKey = prefs.getString('groq_api_key');
    if (userKey != null && userKey.isNotEmpty) return userKey;
    return null;
  }

  String get _model => dotenv.maybeGet('GROQ_MODEL') ?? _defaultModel;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Sends a prompt to Groq and returns the text response.
  Future<String?> generateContent(
    String prompt, {
    String? systemInstruction,
  }) async {
    final apiKey = await _apiKey();
    if (apiKey == null) return null;

    final messages = <Map<String, String>>[];
    if (systemInstruction != null) {
      messages.add({'role': 'system', 'content': systemInstruction});
    }
    messages.add({'role': 'user', 'content': prompt});

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': messages,
              'temperature': 0.1,
              'max_tokens': 512,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices']?[0]?['message']?['content'] as String?;
      }
    } catch (_) {
      // Network unavailable — fall back silently
    }
    return null;
  }

  /// Classifies a user utterance against known flow names.
  Future<String?> understandIntent(
    String utterance,
    List<String> knownFlows,
  ) async {
    final prompt =
        'Classify the intent of: "$utterance"\n'
        'Known intents: ${knownFlows.join(", ")}\n'
        'Reply ONLY with JSON: {"intent":"<intent>","confidence":<0-1>}';
    final response = await generateContent(
      prompt,
      systemInstruction: 'You are a concise intent classifier. Return valid JSON only.',
    );
    if (response == null) return null;
    final match = RegExp(r'\{.*?\}', dotAll: true).firstMatch(response);
    return match?.group(0) ?? response;
  }

  /// Plans a multi-step UI automation sequence.
  Future<Map<String, dynamic>?> planActions(
    String task,
    String screenDescription,
  ) async {
    final prompt =
        'Task: "$task"\nScreen: "$screenDescription"\n'
        'Return JSON with "taskSummary" (string) and "steps" '
        '(array of {action, description}).';
    final response = await generateContent(
      prompt,
      systemInstruction: 'You are a UI automation planner. Return valid JSON only.',
    );
    if (response == null) return null;
    try {
      final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(response);
      return match != null ? jsonDecode(match.group(0)!) : null;
    } catch (_) {
      return null;
    }
  }
}

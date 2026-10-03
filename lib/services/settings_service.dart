import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  final SharedPreferences _prefs;

  SettingsService._(this._prefs);

  static Future<SettingsService> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService._(prefs);
  }

  String? get groqApiKey => _prefs.getString('groq_api_key');
  Future<void> setGroqApiKey(String? value) async {
    if (value == null) {
      await _prefs.remove('groq_api_key');
    } else {
      await _prefs.setString('groq_api_key', value);
    }
  }

  bool get enableLlm => _prefs.getBool('enable_llm') ?? true;
  Future<void> setEnableLlm(bool value) async {
    await _prefs.setBool('enable_llm', value);
  }

  int get stepDelayMs => _prefs.getInt('step_delay_ms') ?? 800;
  Future<void> setStepDelayMs(int value) async {
    await _prefs.setInt('step_delay_ms', value);
  }

  int get maxRetries => _prefs.getInt('max_retries') ?? 5;
  Future<void> setMaxRetries(int value) async {
    await _prefs.setInt('max_retries', value);
  }
}

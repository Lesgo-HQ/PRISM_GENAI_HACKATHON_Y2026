import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_controller.dart';
import '../services/llm_client.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _endpoint = TextEditingController();
  final _model = TextEditingController();
  final _apiKey = TextEditingController();
  final _ollamaEndpoint = TextEditingController();
  final _ollamaModel = TextEditingController();
  bool _fallback = true;
  bool _keySaved = false;
  bool _enabled = false;
  bool _busy = false;
  String _status = 'Connection not tested';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final keySaved = await LlmClient.keyStorage.containsKey(
      key: LlmClient.groqKeyName,
    );
    if (!mounted) return;
    setState(() {
      _endpoint.text =
          prefs.getString('model_endpoint') ??
          'https://api.groq.com/openai/v1/chat/completions';
      _model.text = prefs.getString('model_name') ?? 'openai/gpt-oss-20b';
      _ollamaEndpoint.text =
          prefs.getString('ollama_endpoint') ??
          'http://127.0.0.1:11434/v1/chat/completions';
      _ollamaModel.text = prefs.getString('ollama_model') ?? 'qwen3:4b';
      _fallback = prefs.getBool('ollama_fallback') ?? true;
      _enabled = prefs.getBool('enable_llm') ?? false;
      _keySaved = keySaved;
    });
  }

  Future<void> _save({bool test = false}) async {
    final uri = Uri.tryParse(_endpoint.text.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      setState(
        () => _status =
            'Enter a valid HTTP or HTTPS endpoint without credentials.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final fallbackUri = Uri.tryParse(_ollamaEndpoint.text.trim());
      if (_fallback &&
          (fallbackUri == null ||
              !['http', 'https'].contains(fallbackUri.scheme) ||
              fallbackUri.host.isEmpty ||
              fallbackUri.userInfo.isNotEmpty ||
              fallbackUri.host == 'api.groq.com' ||
              _ollamaModel.text.trim().isEmpty)) {
        throw StateError(
          'Enter a valid Ollama endpoint and model for fallback.',
        );
      }
      final prefs = await SharedPreferences.getInstance();
      if (_apiKey.text.trim().isNotEmpty) {
        await LlmClient.keyStorage.write(
          key: LlmClient.groqKeyName,
          value: _apiKey.text.trim(),
        );
        _apiKey.clear();
        _keySaved = true;
      }
      await prefs.setString('model_endpoint', uri.toString());
      await prefs.setString('model_name', _model.text.trim());
      await prefs.setBool('enable_llm', _enabled);
      await prefs.setBool('ollama_fallback', _fallback);
      await prefs.setString('ollama_endpoint', _ollamaEndpoint.text.trim());
      await prefs.setString('ollama_model', _ollamaModel.text.trim());
      var status = 'Settings saved. Connection not tested.';
      if (test) {
        final issue = await LlmClient.instance.connectionIssue();
        status =
            issue ??
            'Connected via ${LlmClient.instance.lastProvider}. Model response verified.';
      }
      if (mounted) setState(() => _status = status);
    } catch (e) {
      if (mounted) setState(() => _status = 'Connection failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _model.dispose();
    _apiKey.dispose();
    _ollamaEndpoint.dispose();
    _ollamaModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Conversation model',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'Connect your model server for conversation, skill selection and app tasks. '
            'Your messages, screen text and learned skill descriptions are sent to this address. Groq processes them in the cloud. '
            'Device actions remain controlled by SAAR.',
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable AI model'),
            value: _enabled,
            onChanged: _busy
                ? null
                : (value) => setState(() => _enabled = value),
          ),
          TextField(
            controller: _endpoint,
            decoration: const InputDecoration(
              labelText: 'Primary model endpoint',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _model,
            decoration: const InputDecoration(
              labelText: 'Model name / server alias',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _endpoint.text =
                        'https://api.groq.com/openai/v1/chat/completions';
                    _model.text = 'openai/gpt-oss-20b';
                    _enabled = true;
                  }),
            child: const Text('Use Groq as primary'),
          ),
          TextField(
            controller: _apiKey,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Groq API key',
              helperText: _keySaved
                  ? 'Key saved securely. Leave blank to keep it.'
                  : 'Stored securely on this phone; sent only to api.groq.com.',
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use Ollama when Groq is unavailable'),
            subtitle: const Text(
              'Fallback for network failures, timeouts, rate limits and server errors.',
            ),
            value: _fallback,
            onChanged: _busy
                ? null
                : (value) => setState(() => _fallback = value),
          ),
          if (_fallback) ...[
            TextField(
              controller: _ollamaEndpoint,
              decoration: const InputDecoration(
                labelText: 'Ollama fallback endpoint',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ollamaModel,
              decoration: const InputDecoration(
                labelText: 'Ollama fallback model',
              ),
            ),
          ],
          const Text(
            'For an Android emulator use 10.0.2.2 instead of 127.0.0.1. '
            'For Ollama on a USB-connected computer, forward port 11434 as described in the setup guide. '
            'Local servers must support JSON schema responses. Groq needs internet; no USB model forwarding is needed.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: [
              FilledButton(
                onPressed: _busy ? null : () => _save(),
                child: const Text('Save'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _save(test: true),
                child: const Text('Save & test connection'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_busy ? 'Contacting model…' : _status),
          Text('Last response source: ${LlmClient.instance.lastProvider}'),
          const Divider(height: 48),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Android accessibility'),
            subtitle: Text(
              app.isAccessibilityEnabled
                  ? 'Enabled'
                  : 'Enable to teach and run tasks',
            ),
            trailing: TextButton(
              onPressed: app.openAccessibilitySettings,
              child: const Text('Manage'),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Learned skills'),
            subtitle: Text('${app.flows.length} stored on this device'),
          ),
          ListTile(
            title: const Text('Open source licenses'),
            onTap: () =>
                showLicensePage(context: context, applicationName: 'SAAR'),
          ),
          const Text(
            'Speech recognition uses the device speech service. Offline availability depends on installed language packs. '
            'Credential and payment steps stay under your control.',
          ),
        ],
      ),
    );
  }
}

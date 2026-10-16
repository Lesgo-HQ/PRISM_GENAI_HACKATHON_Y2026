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
    if (!mounted) return;
    setState(() {
      _endpoint.text =
          prefs.getString('model_endpoint') ??
          'http://127.0.0.1:8080/v1/chat/completions';
      _model.text = prefs.getString('model_name') ?? 'local';
      _enabled = prefs.getBool('enable_llm') ?? false;
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('model_endpoint', uri.toString());
      await prefs.setString('model_name', _model.text.trim());
      await prefs.setBool('enable_llm', _enabled);
      var status = 'Settings saved. Connection not tested.';
      if (test) {
        final answer = await LlmClient.instance.generateContent(
          'Reply with a short greeting.',
        );
        status = answer == null
            ? 'Enable local model conversation first.'
            : 'Connected. Model replied: $answer';
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
            'Connect your own llama.cpp server for natural conversation and skill selection. '
            'Your messages and learned skill descriptions are sent only to this address. '
            'Device actions remain controlled by SAAR.',
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable local model conversation'),
            value: _enabled,
            onChanged: _busy
                ? null
                : (value) => setState(() => _enabled = value),
          ),
          TextField(
            controller: _endpoint,
            decoration: const InputDecoration(
              labelText: 'Chat completion endpoint',
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
          const Text(
            'For an Android emulator use 10.0.2.2 instead of 127.0.0.1. '
            'For a USB-connected phone, forward port 8080 as described in the README. '
            'The server must support JSON schema responses.',
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
          const Text(
            'Speech recognition uses the device speech service. Offline availability depends on installed language packs. '
            'Credential and payment steps stay under your control.',
          ),
        ],
      ),
    );
  }
}

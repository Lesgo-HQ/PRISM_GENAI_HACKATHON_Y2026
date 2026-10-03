import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_controller.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _apiKeyController = TextEditingController();
  bool _llmEnabled = true;
  bool _showApiKey = false;
  double _stepDelay = 800;
  double _maxRetries = 5;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _apiKeyController.text = prefs.getString('groq_api_key') ?? '';
          _llmEnabled = prefs.getBool('llm_enabled') ?? true;
          _stepDelay = (prefs.getInt('step_delay_ms') ?? 800).toDouble();
          _maxRetries = (prefs.getInt('max_retries') ?? 5).toDouble();
        });
      }
    } catch (_) {}
  }

  Future<void> _saveApiKey() async {
    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('groq_api_key', _apiKeyController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API key saved'),
            backgroundColor: AppTheme.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('llm_enabled', _llmEnabled);
      await prefs.setInt('step_delay_ms', _stepDelay.toInt());
      await prefs.setInt('max_retries', _maxRetries.toInt());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        backgroundColor: AppTheme.background,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          _sectionHeader('AI Configuration'),
          _card([
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Groq API Key',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _apiKeyController,
                          obscureText: !_showApiKey,
                          style: const TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'AIza...',
                            hintStyle: const TextStyle(color: AppTheme.textSecondary),
                            filled: true,
                            fillColor: AppTheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showApiKey ? Icons.visibility_off : Icons.visibility,
                                color: AppTheme.textSecondary,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _showApiKey = !_showApiKey),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveApiKey,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Get a free key at console.groq.com',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            _divider(),
            SwitchListTile(
              title: const Text('Enable LLM', style: TextStyle(color: AppTheme.textPrimary)),
              subtitle: const Text(
                'Use Groq LLM for enhanced understanding',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              value: _llmEnabled,
              activeThumbColor: AppTheme.primary,
              activeTrackColor: AppTheme.primary,
              onChanged: (val) {
                setState(() => _llmEnabled = val);
                _savePrefs();
              },
            ),
            _divider(),
            const ListTile(
              leading: Icon(Icons.model_training, color: AppTheme.accent),
              title: Text('Model', style: TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text('Llama 3.1 8B (Groq)', style: TextStyle(color: AppTheme.textSecondary)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: AppTheme.success, size: 16),
                  SizedBox(width: 4),
                  Text('Active', style: TextStyle(color: AppTheme.success, fontSize: 12)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 24),
          _sectionHeader('Accessibility'),
          _card([
            ListTile(
              leading: Icon(
                controller.isAccessibilityEnabled ? Icons.accessibility_new : Icons.accessibility,
                color: controller.isAccessibilityEnabled ? AppTheme.success : AppTheme.error,
              ),
              title: const Text('Service Status', style: TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text(
                controller.isAccessibilityEnabled ? 'Enabled — SAAR is active' : 'Disabled — tap to enable',
                style: TextStyle(
                  color: controller.isAccessibilityEnabled ? AppTheme.success : AppTheme.error,
                  fontSize: 12,
                ),
              ),
              trailing: TextButton(
                onPressed: controller.openAccessibilitySettings,
                child: Text(
                  controller.isAccessibilityEnabled ? 'Manage' : 'Enable',
                  style: TextStyle(
                    color: controller.isAccessibilityEnabled ? AppTheme.textSecondary : AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          _sectionHeader('Automation'),
          _card([
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Step Delay', style: TextStyle(color: AppTheme.textPrimary)),
                      Text('${_stepDelay.toInt()} ms',
                          style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: _stepDelay,
                    min: 300,
                    max: 2000,
                    divisions: 17,
                    activeColor: AppTheme.primary,
                    inactiveColor: AppTheme.surface,
                    onChanged: (v) => setState(() => _stepDelay = v),
                    onChangeEnd: (_) => _savePrefs(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Max Retries', style: TextStyle(color: AppTheme.textPrimary)),
                      Text('${_maxRetries.toInt()}x',
                          style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: _maxRetries,
                    min: 2,
                    max: 10,
                    divisions: 8,
                    activeColor: AppTheme.primary,
                    inactiveColor: AppTheme.surface,
                    onChanged: (v) => setState(() => _maxRetries = v),
                    onChangeEnd: (_) => _savePrefs(),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 24),
          _sectionHeader('Data'),
          _card([
            ListTile(
              leading: const Icon(Icons.storage_rounded, color: AppTheme.accent),
              title: const Text('Saved Workflows', style: TextStyle(color: AppTheme.textPrimary)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${controller.flows.length}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            _divider(),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppTheme.error),
              title: const Text('Clear All Workflows', style: TextStyle(color: AppTheme.error)),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppTheme.card,
                    title: const Text('Confirm Delete'),
                    content: const Text('Delete all saved workflows? This cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete All'),
                      ),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  for (final f in controller.flows.toList()) {
                    await controller.deleteFlow(f.flowId);
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All workflows deleted'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                }
              },
            ),
          ]),
          const SizedBox(height: 24),
          _sectionHeader('About'),
          _card([
            const ListTile(
              leading: Icon(Icons.info_outline_rounded, color: AppTheme.accent),
              title: Text('SAAR AI Assistant', style: TextStyle(color: AppTheme.textPrimary)),
              subtitle: Text(
                'v1.0.0 — Smart Automated Action Replay',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
            _divider(),
            ListTile(
              leading: const Icon(Icons.code_rounded, color: AppTheme.accent),
              title: const Text('GitHub', style: TextStyle(color: AppTheme.textPrimary)),
              subtitle: const Text('github.com/lesgo/saar',
                  style: TextStyle(color: AppTheme.accent, fontSize: 12)),
              trailing: const Icon(Icons.open_in_new_rounded, color: AppTheme.textSecondary, size: 18),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('github.com/lesgo/saar')),
              ),
            ),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.accent,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.8,
        ),
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 16, endIndent: 16, color: AppTheme.surface);

  Widget _card(List<Widget> children) {
    return Card(
      margin: EdgeInsets.zero,
      color: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(children: children),
    );
  }
}



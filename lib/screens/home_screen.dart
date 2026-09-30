import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_controller.dart';
import 'teach_screen.dart';
import 'replay_screen.dart';
import 'settings_screen.dart';
import 'flow_library_screen.dart';
import 'report_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AppController>().checkAccessibility();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>().state;

    Widget body;
    switch (state) {
      case AppState.teaching:
      case AppState.synthesizing:
        body = const TeachScreen();
        break;
      case AppState.executing:
      case AppState.waitingForClarification:
        body = const ReplayScreen();
        break;
      default:
        body = const _HomeView();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: body,
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  final _commandController = TextEditingController();
  bool _showTypedCommand = false;

  @override
  void dispose() {
    _commandController.dispose();
    super.dispose();
  }

  void _submitTypedCommand(AppController controller) {
    final text = _commandController.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    _commandController.clear();
    setState(() => _showTypedCommand = false);
    controller.submitTypedCommand(text);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', height: 28),
            const SizedBox(width: 12),
            Text(
              'SAAR',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.analytics_rounded, color: Theme.of(context).primaryColor),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportScreen()),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.library_books_rounded,
              color: Theme.of(context).primaryColor,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FlowLibraryScreen()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings_rounded, color: Theme.of(context).primaryColor),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!controller.isAccessibilityEnabled)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.warning_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Accessibility disabled',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: TextButton(
                  onPressed: controller.openAccessibilitySettings,
                  child: const Text('ENABLE'),
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 32.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            controller.state == AppState.error
                                ? Icons.error_outline_rounded
                                : Icons.auto_awesome_rounded,
                            color: controller.state == AppState.error
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              controller.statusMessage,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 60),
                    GestureDetector(
                      onTapDown: (_) => controller.startListening(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: controller.state == AppState.listening
                            ? 160
                            : 140,
                        height: controller.state == AppState.listening
                            ? 160
                            : 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: controller.state == AppState.listening
                                ? [
                                    Theme.of(context).primaryColorDark,
                                    Theme.of(context).primaryColor,
                                  ]
                                : [
                                    Theme.of(context).primaryColor,
                                    Theme.of(context).colorScheme.secondary,
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).primaryColor
                                  .withValues(alpha: 0.3),
                              blurRadius: controller.state == AppState.listening
                                  ? 40
                                  : 20,
                              spreadRadius:
                                  controller.state == AppState.listening
                                  ? 10
                                  : 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.mic_rounded,
                          size: controller.state == AppState.listening
                              ? 72
                              : 56,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      controller.state == AppState.listening
                          ? 'Listening...'
                          : 'Tap and speak',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_showTypedCommand)
                      TextField(
                        controller: _commandController,
                        autofocus: true,
                        textInputAction: TextInputAction.send,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. teach me to order coffee',
                          filled: true,
                          fillColor: Theme.of(context).cardTheme.color,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              Icons.send_rounded,
                              color: Theme.of(context).primaryColor,
                            ),
                            onPressed: () => _submitTypedCommand(controller),
                          ),
                        ),
                        onSubmitted: (_) => _submitTypedCommand(controller),
                      )
                    else
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _showTypedCommand = true),
                        icon: const Icon(Icons.keyboard_rounded, size: 20),
                        label: const Text('Type a command instead'),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).textTheme.bodyMedium?.color ??
                              Colors.white70,
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
          if (controller.flows.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Workflows',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FlowLibraryScreen(),
                          ),
                        ),
                        child: Text(
                          'View All',
                          style: TextStyle(color: Theme.of(context).primaryColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...controller.flows
                      .take(3)
                      .map(
                        (flow) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                              child: Icon(
                                Icons.bolt_rounded,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            title: Text(
                              flow.triggerIntent,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text('${flow.steps.length} steps'),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

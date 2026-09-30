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

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', height: 28),
            const SizedBox(width: 12),
            const Text(
              'SAAR',
              style: TextStyle(
                color: Color(0xFF007BFF),
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_rounded, color: Color(0xFF007BFF)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.library_books_rounded,
              color: Color(0xFF007BFF),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FlowLibraryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Color(0xFF007BFF)),
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
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.warning_rounded,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Accessibility disabled',
                  style: TextStyle(
                    color: Colors.redAccent,
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF007BFF)
                                .withValues(alpha: 0.1),
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
                                ? Colors.redAccent
                                : const Color(0xFF007BFF),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              controller.statusMessage,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1E293B),
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
                                    const Color(0xFF0056b3),
                                    const Color(0xFF007BFF),
                                  ]
                                : [
                                    const Color(0xFF007BFF),
                                    const Color(0xFF3399FF),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF007BFF)
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
          if (controller.flows.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Workflows',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FlowLibraryScreen(),
                          ),
                        ),
                        child: const Text(
                          'View All',
                          style: TextStyle(color: Color(0xFF007BFF)),
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
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE0F2FE),
                              child: Icon(
                                Icons.bolt_rounded,
                                color: Color(0xFF0EA5E9),
                              ),
                            ),
                            title: Text(
                              flow.triggerIntent,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(' •  steps'),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF94A3B8),
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

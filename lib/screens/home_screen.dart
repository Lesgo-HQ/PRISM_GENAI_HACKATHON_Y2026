import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_controller.dart';
import 'teach_screen.dart';
import 'replay_screen.dart';
import 'settings_screen.dart';
import 'flow_library_screen.dart';
import '../models/chat_message.dart';
import '../theme.dart';


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

class _HomeViewState extends State<_HomeView> with SingleTickerProviderStateMixin {
  final _commandController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showTypedCommand = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _commandController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
  
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _submitTypedCommand(AppController controller) {
    final text = _commandController.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    _commandController.clear();
    
    // Add user message
    controller.addMessage(ChatMessage(
      text: text,
      isUser: true,
      type: ChatMessageType.user,
      timestamp: DateTime.now(),
    ));
    
    // Add agent thinking mock
    Future.delayed(const Duration(milliseconds: 500), () {
      controller.addMessage(ChatMessage(
        text: 'Analyzing command...',
        isUser: false,
        type: ChatMessageType.agentThinking,
        timestamp: DateTime.now(),
      ));
    });

    setState(() => _showTypedCommand = false);
    controller.submitTypedCommand(text);
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final isListening = controller.state == AppState.listening;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _scrollController.position.pixels < _scrollController.position.maxScrollExtent) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context, controller),
      body: Column(
        children: [
          if (!controller.isAccessibilityEnabled) _buildAccessibilityBanner(context, controller),
          Expanded(
            child: controller.messages.isEmpty 
              ? _buildEmptyState(context)
              : _buildChatList(context, controller),
          ),
          _buildBottomArea(context, controller, isListening),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, AppController controller) {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bubble_chart_rounded, color: AppTheme.primary, size: 28),
          const SizedBox(width: 8),
          const Text(
            'SAAR',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: controller.state == AppState.error 
                  ? AppTheme.error.withValues(alpha: 0.2)
                  : AppTheme.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: controller.state == AppState.error 
                  ? AppTheme.error.withValues(alpha: 0.5)
                  : AppTheme.primary.withValues(alpha: 0.5),
              )
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: controller.state == AppState.error ? AppTheme.error : AppTheme.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  controller.state == AppState.idle ? 'Online' : controller.statusMessage,
                  style: TextStyle(
                    fontSize: 12,
                    color: controller.state == AppState.error ? AppTheme.error : AppTheme.success,
                    fontWeight: FontWeight.w600,
                  ),
                )
              ],
            ),
          )
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_rounded, color: AppTheme.textSecondary),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildAccessibilityBanner(BuildContext context, AppController controller) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: const Icon(Icons.warning_amber_rounded, color: AppTheme.error),
        title: const Text(
          'Accessibility service disabled',
          style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        trailing: TextButton(
          onPressed: controller.openAccessibilitySettings,
          child: const Text('ENABLE', style: TextStyle(color: AppTheme.error)),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.smart_toy_rounded, size: 64, color: AppTheme.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text(
            'How can I help you today?',
            style: TextStyle(fontSize: 18, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
          )
        ],
      ),
    );
  }

  Widget _buildChatList(BuildContext context, AppController controller) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      itemCount: controller.messages.length,
      itemBuilder: (context, index) {
        final msg = controller.messages[index];
        return _buildMessageBubble(msg);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    
    Color textColor = AppTheme.textPrimary;
    Widget content = Text(msg.text, style: TextStyle(color: textColor));
    Color bgColor = AppTheme.card;
    
    switch (msg.type) {
      case ChatMessageType.user:
      case ChatMessageType.userCommand:
        bgColor = AppTheme.primary;
        content = Text(msg.text, style: TextStyle(color: textColor, fontSize: 16));
        break;
      case ChatMessageType.agentThinking:
        bgColor = AppTheme.card;
        textColor = AppTheme.textSecondary;
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
            ),
            const SizedBox(width: 12),
            Text(msg.text, style: TextStyle(color: textColor, fontStyle: FontStyle.italic)),
          ],
        );
        break;
      case ChatMessageType.agentAction:
        bgColor = AppTheme.surface;
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow_rounded, color: AppTheme.accent, size: 20),
            const SizedBox(width: 8),
            Text(msg.text, style: TextStyle(color: textColor)),
          ],
        );
        break;
      case ChatMessageType.agentResult:
      case ChatMessageType.agentSuccess:
        bgColor = AppTheme.success.withValues(alpha: 0.15);
        textColor = AppTheme.success;
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 20),
            const SizedBox(width: 8),
            Flexible(child: Text(msg.text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
          ],
        );
        break;
      case ChatMessageType.agentFailure:
        bgColor = AppTheme.error.withValues(alpha: 0.15);
        textColor = AppTheme.error;
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cancel_rounded, color: AppTheme.error, size: 20),
            const SizedBox(width: 8),
            Flexible(child: Text(msg.text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
          ],
        );
        break;
      case ChatMessageType.agentQuestion:
        bgColor = AppTheme.card;
        content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.help_outline_rounded, color: AppTheme.accent, size: 20),
            const SizedBox(width: 8),
            Flexible(child: Text(msg.text, style: TextStyle(color: textColor))),
          ],
        );
        break;
      case ChatMessageType.systemInfo:
        bgColor = AppTheme.surface;
        textColor = AppTheme.textSecondary;
        content = Text(msg.text, style: TextStyle(color: textColor, fontSize: 12));
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
              child: const Icon(Icons.smart_toy_rounded, size: 18, color: AppTheme.accent),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                border: !isUser && msg.type != ChatMessageType.agentResult
                  ? Border.all(color: AppTheme.surface)
                  : null,
              ),
              child: content,
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.surface,
              child: Icon(Icons.person_rounded, size: 18, color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomArea(BuildContext context, AppController controller, bool isListening) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(top: BorderSide(color: AppTheme.surface)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller.flows.isNotEmpty && !_showTypedCommand)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: controller.flows.take(4).map((flow) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    backgroundColor: AppTheme.card,
                    side: const BorderSide(color: AppTheme.surface),
                    label: Text(flow.triggerIntent, style: const TextStyle(color: AppTheme.textPrimary)),
                    onPressed: () {
                       controller.submitTypedCommand(flow.triggerIntent);
                       controller.addMessage(ChatMessage(text: flow.triggerIntent, isUser: true, type: ChatMessageType.user, timestamp: DateTime.now()));
                    },
                  ),
                )).toList(),
              ),
            ),
          if (_showTypedCommand)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commandController,
                    autofocus: true,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Type your request...',
                      hintStyle: const TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.card,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _submitTypedCommand(controller),
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  backgroundColor: AppTheme.primary,
                  radius: 24,
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    onPressed: () => _submitTypedCommand(controller),
                  ),
                )
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.keyboard_rounded, color: AppTheme.textSecondary, size: 28),
                  onPressed: () => setState(() => _showTypedCommand = true),
                ),
                const SizedBox(width: 24),
                GestureDetector(
                  onTapDown: (_) => controller.startListening(),
                  child: isListening
                      ? ScaleTransition(
                          scale: _pulseAnimation,
                          child: _buildMicButton(true),
                        )
                      : _buildMicButton(false),
                ),
                const SizedBox(width: 24),
                IconButton(
                  icon: const Icon(Icons.library_books_rounded, color: AppTheme.textSecondary, size: 28),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FlowLibraryScreen()),
                  ),
                ),
              ],
            )
        ],
      ),
    );
  }

  Widget _buildMicButton(bool isListening) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: isListening
              ? [AppTheme.accent, AppTheme.primary]
              : [AppTheme.primary, AppTheme.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: isListening ? 0.6 : 0.3),
            blurRadius: isListening ? 30 : 15,
            spreadRadius: isListening ? 8 : 0,
          )
        ],
      ),
      child: const Icon(Icons.mic_rounded, size: 36, color: Colors.white),
    );
  }
}

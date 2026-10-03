// Chat message model for the conversation-style UI.
// SAAR shows both user commands and agent responses as chat bubbles,
// similar to how Doubao / UI-TARS presents its agent interaction loop.

enum ChatMessageType {
  // User messages
  user,
  userCommand,

  // Agent thinking / planning
  agentThinking,

  // Agent performing an action
  agentAction,

  // Agent result (generic — kept for compat)
  agentResult,

  // Agent finished successfully
  agentSuccess,

  // Agent finished with failure
  agentFailure,

  // Agent asking for clarification
  agentQuestion,

  // System notification
  systemInfo,
}

class ChatMessage {
  final String? id;
  final String text;
  final bool isUser;
  final ChatMessageType type;
  final DateTime timestamp;
  final bool isSuccess;
  final Map<String, dynamic>? metadata;

  ChatMessage({
    this.id,
    required this.text,
    bool? isUser,
    required this.type,
    required this.timestamp,
    bool? isSuccess,
    this.metadata,
  })  : isUser = isUser ??
            (type == ChatMessageType.user ||
                type == ChatMessageType.userCommand),
        isSuccess = isSuccess ??
            (type == ChatMessageType.agentSuccess ||
                type == ChatMessageType.agentResult);

  bool get isAgent =>
      type == ChatMessageType.agentThinking ||
      type == ChatMessageType.agentAction ||
      type == ChatMessageType.agentSuccess ||
      type == ChatMessageType.agentFailure ||
      type == ChatMessageType.agentResult ||
      type == ChatMessageType.agentQuestion;

  bool get isFailure => type == ChatMessageType.agentFailure;
  bool get isThinking => type == ChatMessageType.agentThinking;
  bool get isAction => type == ChatMessageType.agentAction;
  bool get isQuestion => type == ChatMessageType.agentQuestion;
  bool get isSystemInfo => type == ChatMessageType.systemInfo;

  @override
  String toString() =>
      'ChatMessage(type: $type, text: ${text.substring(0, text.length.clamp(0, 40))})';
}

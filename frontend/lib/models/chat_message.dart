/// Who a chat message came from.
///
/// `error` never comes from the backend. It is added locally when a send fails,
/// so the failure appears in the thread instead of vanishing.
enum ChatRole { user, assistant, error }

class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  const ChatMessage.user(this.content) : role = ChatRole.user;
  const ChatMessage.assistant(this.content) : role = ChatRole.assistant;
  const ChatMessage.error(this.content) : role = ChatRole.error;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] == 'assistant' ? ChatRole.assistant : ChatRole.user,
      content: json['content'] as String,
    );
  }

  final ChatRole role;
  final String content;
}

/// What the backend sends back from a chat turn.
class ChatReply {
  const ChatReply({required this.reply, required this.boardChanged});

  factory ChatReply.fromJson(Map<String, dynamic> json) {
    return ChatReply(
      reply: json['reply'] as String,
      boardChanged: json['boardChanged'] as bool? ?? false,
    );
  }

  final String reply;
  final bool boardChanged;
}

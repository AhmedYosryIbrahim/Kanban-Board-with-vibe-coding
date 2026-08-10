import 'dart:async';

import 'package:kanban_frontend/data/chat_repository.dart';
import 'package:kanban_frontend/models/chat_message.dart';

/// In-memory stand-in for [ChatRepository].
class FakeChatRepository implements ChatRepository {
  FakeChatRepository({
    List<ChatMessage>? history,
    this.reply = 'Done.',
    this.boardChanged = false,
    this.loadError,
  }) : history = history ?? [];

  final List<ChatMessage> history;
  String reply;
  bool boardChanged;
  Object? loadError;
  Object? failNextWith;

  /// When set, a send blocks until this completes, so tests can inspect the
  /// pending state.
  Completer<ChatReply>? holdSend;

  final List<String> sent = [];

  @override
  Future<List<ChatMessage>> fetchMessages() async {
    final error = loadError;
    if (error != null) throw error;

    return history;
  }

  @override
  Future<ChatReply> send(String message) async {
    sent.add(message);

    final failure = failNextWith;
    if (failure != null) {
      failNextWith = null;
      throw failure;
    }

    final hold = holdSend;
    if (hold != null) return hold.future;

    return ChatReply(reply: reply, boardChanged: boardChanged);
  }
}

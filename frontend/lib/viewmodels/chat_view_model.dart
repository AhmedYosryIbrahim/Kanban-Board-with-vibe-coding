import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';
import '../models/chat_message.dart';
import 'board_view_model.dart';

/// The conversation plus whether a reply is currently in flight.
class ChatState {
  const ChatState({this.messages = const [], this.isSending = false});

  final List<ChatMessage> messages;
  final bool isSending;

  ChatState copyWith({List<ChatMessage>? messages, bool? isSending}) {
    return ChatState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
    );
  }
}

/// Owns the chat thread.
///
/// The thread is loaded from the backend, so it survives a reload. When the AI
/// reports that it changed the board, the board provider is invalidated and the
/// board refreshes with no user action.
class ChatViewModel extends AsyncNotifier<ChatState> {
  @override
  Future<ChatState> build() async {
    final messages = await ref.read(chatRepositoryProvider).fetchMessages();
    return ChatState(messages: messages);
  }

  /// Sends a message. Throws if the send fails, after putting the thread back
  /// the way it was and adding an error entry, so the caller can restore the
  /// text the user typed.
  Future<void> send(String message) async {
    final before = state.value!.messages;

    state = AsyncData(
      ChatState(
        messages: [...before, ChatMessage.user(message)],
        isSending: true,
      ),
    );

    try {
      final reply = await ref.read(chatRepositoryProvider).send(message);

      state = AsyncData(
        ChatState(
          messages: [
            ...before,
            ChatMessage.user(message),
            ChatMessage.assistant(reply.reply),
          ],
        ),
      );

      if (reply.boardChanged) {
        ref.invalidate(boardViewModelProvider);
      }
    } catch (error) {
      // The message never reached the backend, so it does not belong in the
      // thread. The error takes its place and the caller restores the input.
      state = AsyncData(
        ChatState(messages: [...before, ChatMessage.error('$error')]),
      );
      rethrow;
    }
  }
}

final chatViewModelProvider = AsyncNotifierProvider<ChatViewModel, ChatState>(
  ChatViewModel.new,
);

/// Whether the sidebar is open. Starts closed so the board has the full width.
class ChatOpen extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;

  void close() => state = false;
}

final chatOpenProvider = NotifierProvider<ChatOpen, bool>(ChatOpen.new);

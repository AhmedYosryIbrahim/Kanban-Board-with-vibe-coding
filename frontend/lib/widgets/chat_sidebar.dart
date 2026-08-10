import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../theme/app_colors.dart';
import '../viewmodels/chat_view_model.dart';

const chatSidebarWidth = 340.0;

/// Collapsible assistant panel down the right hand side of the board.
class ChatSidebar extends ConsumerStatefulWidget {
  const ChatSidebar({super.key});

  @override
  ConsumerState<ChatSidebar> createState() => _ChatSidebarState();
}

class _ChatSidebarState extends ConsumerState<ChatSidebar> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;

    final chat = ref.read(chatViewModelProvider);
    if (chat.value?.isSending ?? false) return;

    _controller.clear();

    try {
      await ref.read(chatViewModelProvider.notifier).send(message);
    } catch (_) {
      // The thread already shows the failure; give the text back so the user
      // can retry without retyping.
      _controller.text = message;
    }

    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatViewModelProvider);

    ref.listen(chatViewModelProvider, (_, _) => _scrollToEnd());

    return Container(
      width: chatSidebarWidth,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Color(0xFFE7EAF0))),
      ),
      child: Column(
        children: [
          _header(context),
          Expanded(
            child: switch (chat) {
              AsyncError(:final error) => _centred('$error'),
              AsyncData(:final value) => _thread(value),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
          _composer(chat.value?.isSending ?? false),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.only(left: 16, right: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE7EAF0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Assistant',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: 'Close assistant',
            icon: const Icon(Icons.close, size: 20, color: AppColors.grayText),
            onPressed: () => ref.read(chatOpenProvider.notifier).close(),
          ),
        ],
      ),
    );
  }

  Widget _centred(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.grayText, fontSize: 13),
        ),
      ),
    );
  }

  Widget _thread(ChatState chat) {
    if (chat.messages.isEmpty && !chat.isSending) {
      return _centred('Ask me to add, move, or rename anything on the board.');
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: chat.messages.length + (chat.isSending ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= chat.messages.length) return const _Pending();
        return _Bubble(message: chat.messages[index]);
      },
    );
  }

  Widget _composer(bool isSending) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE7EAF0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            // Enter sends, Shift+Enter makes a newline. A multiline TextField
            // never fires onSubmitted, so the key event is handled here.
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.enter &&
                    !HardwareKeyboard.instance.isShiftPressed) {
                  _send();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Ask the assistant',
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Send',
            onPressed: isSending ? null : _send,
            icon: const Icon(Icons.send, size: 20),
            color: AppColors.purpleSecondary,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final isError = message.role == ChatRole.error;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: switch (message.role) {
            ChatRole.user => AppColors.bluePrimary.withValues(alpha: 0.10),
            ChatRole.assistant => const Color(0xFFEDF1F5),
            ChatRole.error => AppColors.purpleSecondary.withValues(alpha: 0.10),
          },
          borderRadius: BorderRadius.circular(10),
          border: isError
              ? Border.all(
                  color: AppColors.purpleSecondary.withValues(alpha: 0.4),
                )
              : null,
        ),
        child: Text(
          message.content,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.35,
            color: isError ? AppColors.purpleSecondary : AppColors.darkNavy,
          ),
        ),
      ),
    );
  }
}

class _Pending extends StatelessWidget {
  const _Pending();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEDF1F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const SizedBox(
          height: 14,
          width: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

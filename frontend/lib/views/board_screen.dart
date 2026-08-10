import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/board.dart';
import '../theme/app_colors.dart';
import '../viewmodels/auth_view_model.dart';
import '../viewmodels/board_view_model.dart';
import '../viewmodels/chat_view_model.dart';
import '../widgets/chat_sidebar.dart';
import '../widgets/column_widget.dart';

/// Top-level screen showing the single Kanban board with its columns.
class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardState = ref.watch(boardViewModelProvider);
    final isChatOpen = ref.watch(chatOpenProvider);

    final board = switch (boardState) {
      AsyncError(:final error) => _BoardError(
        message: '$error',
        onRetry: () => ref.invalidate(boardViewModelProvider),
      ),
      AsyncData(:final value) => _BoardBody(board: value),
      _ => const Center(child: CircularProgressIndicator()),
    };

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _WebTopBar(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final content = Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: board,
                  );

                  if (!isChatOpen) return content;

                  // Below this width there is not enough room for the board and
                  // the panel side by side, so the panel goes over the board
                  // instead of squeezing it.
                  final overlay = constraints.maxWidth < 900;

                  if (overlay) {
                    return Stack(
                      children: [
                        Positioned.fill(child: content),
                        const Positioned(
                          top: 0,
                          right: 0,
                          bottom: 0,
                          child: ChatSidebar(),
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: content),
                      const ChatSidebar(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardBody extends StatelessWidget {
  const _BoardBody({required this.board});

  final Board board;

  @override
  Widget build(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final boardViewportHeight = math.min(
      760.0,
      math.max(320.0, viewportHeight - 280),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1320),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E8EE)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x11000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    board.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    board.subtitle,
                    style: const TextStyle(
                      color: Color(0xFF6D7482),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: boardViewportHeight,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final column in board.columns)
                            ColumnWidget(column: column),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardError extends StatelessWidget {
  const _BoardError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Could not load the board',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _WebTopBar extends ConsumerWidget {
  const _WebTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final username = ref.watch(authViewModelProvider).value;

    return Container(
      height: 72,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE7EAF0))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The nav labels and the username are the first things to go
                // when the bar runs out of room; the controls have to stay.
                final roomy = constraints.maxWidth >= 720;

                return Row(
                  children: [
                    const Text(
                      'KANBAN',
                      style: TextStyle(
                        fontSize: 17,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF032147),
                      ),
                    ),
                    if (roomy) ...[
                      const SizedBox(width: 24),
                      Text(
                        'Board',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'Projects',
                        style: TextStyle(
                          color: Color(0xFF6D7482),
                          fontSize: 14,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (username != null && roomy)
                      Text(
                        username,
                        style: const TextStyle(
                          color: AppColors.grayText,
                          fontSize: 14,
                        ),
                      ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () =>
                          ref.read(chatOpenProvider.notifier).toggle(),
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Assistant'),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: () =>
                          ref.read(authViewModelProvider.notifier).signOut(),
                      child: const Text('Log out'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

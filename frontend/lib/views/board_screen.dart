import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/board_view_model.dart';
import '../widgets/column_widget.dart';

/// Top-level screen showing the single Kanban board with its columns.
class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(boardViewModelProvider);
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final boardViewportHeight = math.min(
      760.0,
      math.max(320.0, viewportHeight - 280),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _WebTopBar(),
            const SizedBox(height: 18),
            Expanded(
              child: Center(
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
                              'Product Roadmap',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Q4 delivery board',
                              style: TextStyle(
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WebTopBar extends StatelessWidget {
  const _WebTopBar();

  @override
  Widget build(BuildContext context) {
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
            child: Row(
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
                const SizedBox(width: 24),
                Text('Board', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 14),
                const Text(
                  'Projects',
                  style: TextStyle(color: Color(0xFF6D7482), fontSize: 14),
                ),
                const Spacer(),
                TextButton(onPressed: () {}, child: const Text('Share')),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: () {}, child: const Text('New task')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

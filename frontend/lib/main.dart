import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/app_theme.dart';
import 'views/board_screen.dart';

void main() {
  runApp(const ProviderScope(child: KanbanApp()));
}

class KanbanApp extends StatelessWidget {
  const KanbanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kanban Board',
      theme: AppTheme.light,
      home: const BoardScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/app_theme.dart';
import 'viewmodels/auth_view_model.dart';
import 'views/board_screen.dart';
import 'views/login_screen.dart';

void main() {
  runApp(const ProviderScope(child: KanbanApp()));
}

class KanbanApp extends ConsumerWidget {
  const KanbanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authViewModelProvider);

    return MaterialApp(
      title: 'Kanban Board',
      theme: AppTheme.light,
      home: auth.when(
        loading: () => const _SessionCheck(),
        // A failed session check means no usable session, so ask for one.
        error: (error, stackTrace) => const LoginScreen(),
        data: (username) =>
            username == null ? const LoginScreen() : const BoardScreen(),
      ),
    );
  }
}

class _SessionCheck extends StatelessWidget {
  const _SessionCheck();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

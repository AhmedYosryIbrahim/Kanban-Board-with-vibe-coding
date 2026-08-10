import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kanban_frontend/main.dart';

void main() {
  testWidgets('Board screen shows dummy columns and cards', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KanbanApp()));

    expect(find.text('To Do'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Blocked'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Design onboarding flow'), findsOneWidget);
  });
}

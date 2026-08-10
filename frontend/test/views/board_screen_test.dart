import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_frontend/data/board_repository.dart';
import 'package:kanban_frontend/models/board.dart';
import 'package:kanban_frontend/models/board_column.dart';
import 'package:kanban_frontend/models/card_item.dart';

import '../support/test_app.dart';

void main() {
  testWidgets('the board renders from the repository, not from dummy data', (
    tester,
  ) async {
    useWideSurface(tester);
    final repository = FakeBoardRepository(
      board: const Board(
        id: 7,
        name: 'Migration plan',
        subtitle: 'Owned by platform',
        columns: [
          BoardColumn(
            id: 'a',
            title: 'Inbox',
            cards: [CardItem(id: 'x', title: 'Only card', details: 'From API')],
          ),
          BoardColumn(id: 'b', title: 'Shipped'),
        ],
      ),
    );

    await pumpSignedInApp(tester, board: repository);

    expect(find.text('Migration plan'), findsOneWidget);
    expect(find.text('Owned by platform'), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Shipped'), findsOneWidget);
    expect(find.text('Only card'), findsOneWidget);

    // The old hardcoded strings and dummy cards must be gone.
    expect(find.text('Product Roadmap'), findsNothing);
    expect(find.text('To Do'), findsNothing);
    expect(find.text('Design onboarding flow'), findsNothing);
  });

  testWidgets('a spinner shows while the board is loading', (tester) async {
    useWideSurface(tester);
    final repository = FakeBoardRepository()..holdLoad = Completer<Board>();

    // Cannot settle here: the load is deliberately held open.
    await pumpSignedInApp(tester, board: repository, settle: false);
    await tester.pump();
    await tester.pump();

    // The top bar belongs to BoardScreen, so this is the board loading rather
    // than the session check.
    expect(find.text('KANBAN'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('To Do'), findsNothing);

    repository.holdLoad!.complete(repository.board);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('To Do'), findsOneWidget);
  });

  testWidgets('a failed load shows the error state with the message', (
    tester,
  ) async {
    useWideSurface(tester);
    final repository = FakeBoardRepository(
      loadError: const BoardException('Not signed in'),
    );

    await pumpSignedInApp(tester, board: repository);

    expect(find.text('Could not load the board'), findsOneWidget);
    expect(find.text('Not signed in'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('To Do'), findsNothing);
  });

  testWidgets('retrying after a failed load shows the board', (tester) async {
    useWideSurface(tester);
    final repository = FakeBoardRepository(
      loadError: const BoardException('Not signed in'),
    );

    await pumpSignedInApp(tester, board: repository);
    expect(find.text('Could not load the board'), findsOneWidget);

    repository.loadError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Could not load the board'), findsNothing);
    expect(find.text('To Do'), findsOneWidget);
    expect(find.text('Design onboarding flow'), findsOneWidget);
  });

  testWidgets('a failed mutation reverts the board and reports the failure', (
    tester,
  ) async {
    useWideSurface(tester);
    final repository = FakeBoardRepository();

    await pumpSignedInApp(tester, board: repository);

    repository.failNextWith = const BoardException('Card not found');
    await tester.tap(
      find
          .descendant(
            of: find.ancestor(
              of: find.text('Design onboarding flow'),
              matching: find.byType(Row),
            ),
            matching: find.byIcon(Icons.close),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Design onboarding flow'), findsOneWidget);
    expect(find.text('Card not found'), findsOneWidget);
  });
}

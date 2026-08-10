import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_frontend/viewmodels/board_view_model.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('board starts with 5 columns populated with dummy data', () {
    final board = container.read(boardViewModelProvider);

    expect(board.columns, hasLength(5));
    expect(board.columns.every((c) => c.cards.isNotEmpty), isTrue);
  });

  test('renameColumn updates only the target column title', () {
    final notifier = container.read(boardViewModelProvider.notifier);

    notifier.renameColumn('todo', 'Backlog');

    final board = container.read(boardViewModelProvider);
    expect(board.columns.firstWhere((c) => c.id == 'todo').title, 'Backlog');
    expect(
      board.columns.firstWhere((c) => c.id == 'done').title,
      isNot('Backlog'),
    );
  });

  test('addCard appends a new card to the target column', () {
    final notifier = container.read(boardViewModelProvider.notifier);
    final before = container
        .read(boardViewModelProvider)
        .columns
        .firstWhere((c) => c.id == 'todo')
        .cards
        .length;

    notifier.addCard('todo', 'New task', 'Some details');

    final column = container
        .read(boardViewModelProvider)
        .columns
        .firstWhere((c) => c.id == 'todo');
    expect(column.cards.length, before + 1);
    expect(column.cards.last.title, 'New task');
    expect(column.cards.last.details, 'Some details');
  });

  test('deleteCard removes the card from its column', () {
    final notifier = container.read(boardViewModelProvider.notifier);
    final cardId = container
        .read(boardViewModelProvider)
        .columns
        .firstWhere((c) => c.id == 'todo')
        .cards
        .first
        .id;

    notifier.deleteCard('todo', cardId);

    final column = container
        .read(boardViewModelProvider)
        .columns
        .firstWhere((c) => c.id == 'todo');
    expect(column.cards.any((c) => c.id == cardId), isFalse);
  });

  test('moveCard transfers a card between columns', () {
    final notifier = container.read(boardViewModelProvider.notifier);
    final cardId = container
        .read(boardViewModelProvider)
        .columns
        .firstWhere((c) => c.id == 'todo')
        .cards
        .first
        .id;

    notifier.moveCard(cardId: cardId, fromColumnId: 'todo', toColumnId: 'done');

    final board = container.read(boardViewModelProvider);
    final fromColumn = board.columns.firstWhere((c) => c.id == 'todo');
    final toColumn = board.columns.firstWhere((c) => c.id == 'done');
    expect(fromColumn.cards.any((c) => c.id == cardId), isFalse);
    expect(toColumn.cards.any((c) => c.id == cardId), isTrue);
  });

  test('moveCard reorders cards within the same column', () {
    final notifier = container.read(boardViewModelProvider.notifier);
    notifier.addCard('todo', 'Third task', 'Created for reorder test');
    final before = container.read(boardViewModelProvider);
    final todoCards = before.columns.firstWhere((c) => c.id == 'todo').cards;
    final firstCardId = todoCards.first.id;

    notifier.moveCard(
      cardId: firstCardId,
      fromColumnId: 'todo',
      toColumnId: 'todo',
      targetIndex: todoCards.length,
    );

    final after = container.read(boardViewModelProvider);
    final reordered = after.columns.firstWhere((c) => c.id == 'todo').cards;
    expect(reordered.last.id, firstCardId);
    expect(reordered.length, todoCards.length);
  });

  test('moveCard inserts into target column at provided index', () {
    final notifier = container.read(boardViewModelProvider.notifier);
    final board = container.read(boardViewModelProvider);
    final movedCardId = board.columns
        .firstWhere((c) => c.id == 'todo')
        .cards
        .first
        .id;

    notifier.moveCard(
      cardId: movedCardId,
      fromColumnId: 'todo',
      toColumnId: 'in-progress',
      targetIndex: 0,
    );

    final after = container.read(boardViewModelProvider);
    final inProgress = after.columns.firstWhere((c) => c.id == 'in-progress');
    expect(inProgress.cards.first.id, movedCardId);
  });
}

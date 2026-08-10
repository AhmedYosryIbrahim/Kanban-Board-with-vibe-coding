import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_frontend/data/board_repository.dart';
import 'package:kanban_frontend/models/board.dart';
import 'package:kanban_frontend/viewmodels/board_view_model.dart';

import '../support/fake_board_repository.dart';

void main() {
  late ProviderContainer container;
  late FakeBoardRepository repository;

  setUp(() {
    repository = FakeBoardRepository();
    container = ProviderContainer(
      overrides: [boardRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  /// Riverpod 3 auto-disposes providers with no listeners, and a bare
  /// `read(provider.future)` does not create one - the provider would be torn
  /// down mid-build. Holding a subscription keeps it alive for the test.
  Future<void> load() {
    container.listen(
      boardViewModelProvider,
      (previous, next) {},
      onError: (error, stackTrace) {},
    );
    return container.read(boardViewModelProvider.future);
  }

  Board board() => container.read(boardViewModelProvider).value!;

  List<String> titlesIn(String columnId) => board().columns
      .firstWhere((c) => c.id == columnId)
      .cards
      .map((c) => c.title)
      .toList();

  BoardViewModel notifier() =>
      container.read(boardViewModelProvider.notifier);

  test('the board is loaded from the repository', () async {
    await load();

    expect(repository.calls, ['fetchBoard']);
    expect(board().name, 'Product Roadmap');
    expect(board().subtitle, 'Q4 delivery board');
    expect(board().columns, hasLength(5));
  });

  test('a failed load surfaces as an error state', () async {
    repository.loadError = const BoardException('Not signed in');

    container.listen(
      boardViewModelProvider,
      (previous, next) {},
      onError: (error, stackTrace) {},
    );
    for (var i = 0;
        i < 10 && container.read(boardViewModelProvider).isLoading;
        i++) {
      await Future<void>.delayed(Duration.zero);
    }

    // Asserted on the state rather than `provider.future`, which never
    // completes when the build fails - the UI renders this state, not that
    // future.
    final state = container.read(boardViewModelProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<BoardException>());
  });

  test('renameColumn updates only the target column and calls the API',
      () async {
    await load();

    await notifier().renameColumn('todo', 'Backlog');

    expect(board().columns.firstWhere((c) => c.id == 'todo').title, 'Backlog');
    expect(board().columns.firstWhere((c) => c.id == 'done').title, 'Done');
    expect(repository.calls, contains('renameColumn:todo:Backlog'));
  });

  test('addCard appends the card the backend created', () async {
    await load();

    await notifier().addCard('todo', 'Third task', 'Some details');

    final cards = board().columns.firstWhere((c) => c.id == 'todo').cards;
    expect(cards.last.title, 'Third task');
    expect(cards.last.details, 'Some details');
    expect(cards.last.id, 'server-card-1');
    expect(repository.calls, contains('createCard:todo:Third task'));
  });

  test('a failed addCard leaves the board untouched', () async {
    await load();
    repository.failNextWith = const BoardException('Title is required');

    await expectLater(
      notifier().addCard('todo', 'Third task', ''),
      throwsA(isA<BoardException>()),
    );

    expect(titlesIn('todo'), [
      'Design onboarding flow',
      'Set up CI pipeline',
    ]);
  });

  test('updateCard changes only the target card', () async {
    await load();

    await notifier().updateCard('todo', 'c1', 'Renamed', 'New details');

    final cards = board().columns.firstWhere((c) => c.id == 'todo').cards;
    expect(cards.first.title, 'Renamed');
    expect(cards.first.details, 'New details');
    expect(cards.last.title, 'Set up CI pipeline');
    expect(repository.calls, contains('updateCard:c1:Renamed'));
  });

  test('deleteCard removes the card from its column', () async {
    await load();

    await notifier().deleteCard('todo', 'c1');

    expect(titlesIn('todo'), ['Set up CI pipeline']);
    expect(repository.calls, contains('deleteCard:c1'));
  });

  test('moveCard transfers a card between columns', () async {
    await load();

    await notifier().moveCard(
      cardId: 'c1',
      fromColumnId: 'todo',
      toColumnId: 'done',
    );

    expect(titlesIn('todo'), ['Set up CI pipeline']);
    expect(titlesIn('done'), [
      'Project kickoff meeting',
      'Design onboarding flow',
    ]);
    expect(repository.calls, contains('moveCard:c1:done:1'));
  });

  test('moveCard inserts into the target column at the given index', () async {
    await load();

    await notifier().moveCard(
      cardId: 'c1',
      fromColumnId: 'todo',
      toColumnId: 'in-progress',
      targetIndex: 0,
    );

    expect(titlesIn('in-progress'), [
      'Design onboarding flow',
      'Implement drag and drop',
    ]);
    expect(repository.calls, contains('moveCard:c1:in-progress:0'));
  });

  test('moveCard reorders within a column, decrementing a downward move',
      () async {
    await load();

    // Drop below both existing cards: index 2 before removal, 1 after.
    await notifier().moveCard(
      cardId: 'c1',
      fromColumnId: 'todo',
      toColumnId: 'todo',
      targetIndex: 2,
    );

    expect(titlesIn('todo'), [
      'Set up CI pipeline',
      'Design onboarding flow',
    ]);
    expect(repository.calls, contains('moveCard:c1:todo:1'));
  });

  test('moveCard reorders upward within a column without decrementing',
      () async {
    await load();

    await notifier().moveCard(
      cardId: 'c2',
      fromColumnId: 'todo',
      toColumnId: 'todo',
      targetIndex: 0,
    );

    expect(titlesIn('todo'), [
      'Set up CI pipeline',
      'Design onboarding flow',
    ]);
    expect(repository.calls, contains('moveCard:c2:todo:0'));
  });

  test('a failed move reverts the optimistic change', () async {
    await load();
    repository.failNextWith = const BoardException('Column not found');

    await expectLater(
      notifier().moveCard(
        cardId: 'c1',
        fromColumnId: 'todo',
        toColumnId: 'done',
      ),
      throwsA(isA<BoardException>()),
    );

    expect(titlesIn('todo'), [
      'Design onboarding flow',
      'Set up CI pipeline',
    ]);
    expect(titlesIn('done'), ['Project kickoff meeting']);
  });

  test('a failed rename reverts the optimistic change', () async {
    await load();
    repository.failNextWith = const BoardException('Title is required');

    await expectLater(
      notifier().renameColumn('todo', 'Backlog'),
      throwsA(isA<BoardException>()),
    );

    expect(board().columns.firstWhere((c) => c.id == 'todo').title, 'To Do');
  });

  test('a failed delete puts the card back', () async {
    await load();
    repository.failNextWith = const BoardException('Card not found');

    await expectLater(
      notifier().deleteCard('todo', 'c1'),
      throwsA(isA<BoardException>()),
    );

    expect(titlesIn('todo'), [
      'Design onboarding flow',
      'Set up CI pipeline',
    ]);
  });

  test('moving an unknown card is a no-op and calls nothing', () async {
    await load();

    await notifier().moveCard(
      cardId: 'does-not-exist',
      fromColumnId: 'todo',
      toColumnId: 'done',
    );

    expect(repository.calls, ['fetchBoard']);
  });
}

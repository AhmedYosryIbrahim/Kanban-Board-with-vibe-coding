import 'dart:async';

import 'package:kanban_frontend/data/board_repository.dart';
import 'package:kanban_frontend/models/board.dart';
import 'package:kanban_frontend/models/card_item.dart';

import 'board_fixture.dart';

/// In-memory stand-in for [BoardRepository].
///
/// Records the calls the viewmodel makes, and can be told to fail the next
/// mutation so the revert path can be exercised.
class FakeBoardRepository implements BoardRepository {
  FakeBoardRepository({Board? board, this.loadError})
    : board = board ?? buildFixtureBoard();

  Board board;
  Object? loadError;
  Object? failNextWith;

  /// When set, the load blocks until this completes, so tests can inspect the
  /// loading state.
  Completer<Board>? holdLoad;

  final List<String> calls = [];
  int _createdCards = 0;

  void _record(String call) {
    calls.add(call);

    final failure = failNextWith;
    if (failure != null) {
      failNextWith = null;
      throw failure;
    }
  }

  @override
  Future<Board> fetchBoard() async {
    final error = loadError;
    if (error != null) throw error;

    calls.add('fetchBoard');

    final hold = holdLoad;
    if (hold != null) return hold.future;

    return board;
  }

  @override
  Future<void> renameColumn(String columnId, String title) async {
    _record('renameColumn:$columnId:$title');
  }

  @override
  Future<CardItem> createCard(
    String columnId,
    String title,
    String details,
  ) async {
    _record('createCard:$columnId:$title');

    _createdCards += 1;
    return CardItem(
      id: 'server-card-$_createdCards',
      title: title,
      details: details,
    );
  }

  @override
  Future<void> updateCard(String cardId, String title, String details) async {
    _record('updateCard:$cardId:$title');
  }

  @override
  Future<void> deleteCard(String cardId) async {
    _record('deleteCard:$cardId');
  }

  @override
  Future<void> moveCard(
    String cardId,
    String toColumnId,
    int position,
  ) async {
    _record('moveCard:$cardId:$toColumnId:$position');
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/board_repository.dart';
import '../models/board.dart';
import '../models/card_item.dart';

/// Owns the board state and all mutations (MVVM ViewModel).
///
/// Mutations apply to local state first and call the backend after, so the UI
/// responds immediately. If the call fails the previous state is restored and
/// the error is rethrown for the caller to surface.
class BoardViewModel extends AsyncNotifier<Board> {
  @override
  Future<Board> build() => _repository.fetchBoard();

  BoardRepository get _repository => ref.read(boardRepositoryProvider);

  Board get _board => state.value!;

  Future<void> _apply(Board next, Future<void> Function() call) async {
    final previous = _board;
    state = AsyncData(next);

    try {
      await call();
    } catch (error) {
      state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = AsyncData(await _repository.fetchBoard());
  }

  Future<void> renameColumn(String columnId, String newTitle) {
    return _apply(
      _board.copyWith(
        columns: [
          for (final column in _board.columns)
            if (column.id == columnId)
              column.copyWith(title: newTitle)
            else
              column,
        ],
      ),
      () => _repository.renameColumn(columnId, newTitle),
    );
  }

  /// Creates through the backend first, because the card id is assigned there.
  Future<void> addCard(String columnId, String title, String details) async {
    final card = await _repository.createCard(columnId, title, details);

    state = AsyncData(
      _board.copyWith(
        columns: [
          for (final column in _board.columns)
            if (column.id == columnId)
              column.copyWith(cards: [...column.cards, card])
            else
              column,
        ],
      ),
    );
  }

  Future<void> updateCard(
    String columnId,
    String cardId,
    String title,
    String details,
  ) {
    return _apply(
      _board.copyWith(
        columns: [
          for (final column in _board.columns)
            if (column.id == columnId)
              column.copyWith(
                cards: [
                  for (final card in column.cards)
                    if (card.id == cardId)
                      card.copyWith(title: title, details: details)
                    else
                      card,
                ],
              )
            else
              column,
        ],
      ),
      () => _repository.updateCard(cardId, title, details),
    );
  }

  Future<void> deleteCard(String columnId, String cardId) {
    return _apply(
      _board.copyWith(
        columns: [
          for (final column in _board.columns)
            if (column.id == columnId)
              column.copyWith(
                cards: column.cards.where((c) => c.id != cardId).toList(),
              )
            else
              column,
        ],
      ),
      () => _repository.deleteCard(cardId),
    );
  }

  Future<void> moveCard({
    required String cardId,
    required String fromColumnId,
    required String toColumnId,
    int? targetIndex,
  }) {
    final fromColumn = _board.columns.firstWhere((c) => c.id == fromColumnId);
    final fromIndex = fromColumn.cards.indexWhere((c) => c.id == cardId);
    if (fromIndex == -1) return Future.value();
    final card = fromColumn.cards[fromIndex];

    late final Board next;
    late final int finalIndex;

    if (fromColumnId == toColumnId) {
      final withoutDragged = [
        for (final current in fromColumn.cards)
          if (current.id != cardId) current,
      ];
      var index = targetIndex ?? withoutDragged.length;
      // The card is removed before reinsertion, so a downward move lands one
      // slot early without this.
      if (index > fromIndex) index -= 1;
      finalIndex = index.clamp(0, withoutDragged.length);

      next = _board.copyWith(
        columns: [
          for (final column in _board.columns)
            if (column.id == fromColumnId)
              column.copyWith(
                cards: _insertAt(withoutDragged, card, finalIndex),
              )
            else
              column,
        ],
      );
    } else {
      final toColumn = _board.columns.firstWhere((c) => c.id == toColumnId);
      finalIndex = (targetIndex ?? toColumn.cards.length).clamp(
        0,
        toColumn.cards.length,
      );

      next = _board.copyWith(
        columns: [
          for (final column in _board.columns)
            if (column.id == fromColumnId)
              column.copyWith(
                cards: column.cards.where((c) => c.id != cardId).toList(),
              )
            else if (column.id == toColumnId)
              column.copyWith(cards: _insertAt(column.cards, card, finalIndex))
            else
              column,
        ],
      );
    }

    return _apply(
      next,
      () => _repository.moveCard(cardId, toColumnId, finalIndex),
    );
  }

  List<CardItem> _insertAt(List<CardItem> cards, CardItem card, int? index) {
    final updated = [...cards];
    final safeIndex = (index ?? updated.length).clamp(0, updated.length);
    updated.insert(safeIndex, card);
    return updated;
  }
}

final boardViewModelProvider = AsyncNotifierProvider<BoardViewModel, Board>(
  BoardViewModel.new,
);

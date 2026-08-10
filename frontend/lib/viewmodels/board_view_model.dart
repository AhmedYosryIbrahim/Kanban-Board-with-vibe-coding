import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/dummy_data.dart';
import '../models/board.dart';
import '../models/card_item.dart';

const _uuid = Uuid();

/// Owns the board state and all mutations (MVVM ViewModel).
class BoardViewModel extends Notifier<Board> {
  @override
  Board build() => buildDummyBoard();

  void renameColumn(String columnId, String newTitle) {
    state = state.copyWith(
      columns: [
        for (final column in state.columns)
          if (column.id == columnId)
            column.copyWith(title: newTitle)
          else
            column,
      ],
    );
  }

  void addCard(String columnId, String title, String details) {
    final newCard = CardItem(id: _uuid.v4(), title: title, details: details);
    state = state.copyWith(
      columns: [
        for (final column in state.columns)
          if (column.id == columnId)
            column.copyWith(cards: [...column.cards, newCard])
          else
            column,
      ],
    );
  }

  void deleteCard(String columnId, String cardId) {
    state = state.copyWith(
      columns: [
        for (final column in state.columns)
          if (column.id == columnId)
            column.copyWith(
              cards: column.cards.where((c) => c.id != cardId).toList(),
            )
          else
            column,
      ],
    );
  }

  void moveCard({
    required String cardId,
    required String fromColumnId,
    required String toColumnId,
    int? targetIndex,
  }) {
    final fromColumn = state.columns.firstWhere((c) => c.id == fromColumnId);
    final fromIndex = fromColumn.cards.indexWhere((c) => c.id == cardId);
    if (fromIndex == -1) return;
    final card = fromColumn.cards[fromIndex];

    if (fromColumnId == toColumnId) {
      final cardsWithoutDragged = [
        for (final current in fromColumn.cards)
          if (current.id != cardId) current,
      ];
      var index = targetIndex ?? cardsWithoutDragged.length;
      if (index > fromIndex) {
        index -= 1;
      }
      final reordered = _insertAt(cardsWithoutDragged, card, index);

      state = state.copyWith(
        columns: [
          for (final column in state.columns)
            if (column.id == fromColumnId)
              column.copyWith(cards: reordered)
            else
              column,
        ],
      );
      return;
    }

    state = state.copyWith(
      columns: [
        for (final column in state.columns)
          if (column.id == fromColumnId)
            column.copyWith(
              cards: column.cards.where((c) => c.id != cardId).toList(),
            )
          else if (column.id == toColumnId)
            column.copyWith(cards: _insertAt(column.cards, card, targetIndex))
          else
            column,
      ],
    );
  }

  List<CardItem> _insertAt(List<CardItem> cards, CardItem card, int? index) {
    final updated = [...cards];
    final safeIndex = (index ?? updated.length).clamp(0, updated.length);
    updated.insert(safeIndex, card);
    return updated;
  }
}

final boardViewModelProvider = NotifierProvider<BoardViewModel, Board>(
  BoardViewModel.new,
);

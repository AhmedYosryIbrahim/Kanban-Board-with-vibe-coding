import 'board_column.dart';

/// The single Kanban board, holding its fixed set of columns.
class Board {
  const Board({required this.columns});

  final List<BoardColumn> columns;

  Board copyWith({List<BoardColumn>? columns}) {
    return Board(columns: columns ?? this.columns);
  }
}

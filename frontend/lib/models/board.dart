import 'board_column.dart';

/// The single Kanban board, holding its fixed set of columns.
class Board {
  const Board({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.columns,
  });

  factory Board.fromJson(Map<String, dynamic> json) {
    return Board(
      id: json['id'] as int,
      name: json['name'] as String,
      subtitle: json['subtitle'] as String? ?? '',
      columns: [
        for (final column in json['columns'] as List<dynamic>)
          BoardColumn.fromJson(column as Map<String, dynamic>),
      ],
    );
  }

  final int id;
  final String name;
  final String subtitle;
  final List<BoardColumn> columns;

  Board copyWith({List<BoardColumn>? columns}) {
    return Board(
      id: id,
      name: name,
      subtitle: subtitle,
      columns: columns ?? this.columns,
    );
  }
}

import 'card_item.dart';

/// A board column with a title and an ordered list of cards.
class BoardColumn {
  const BoardColumn({
    required this.id,
    required this.title,
    this.cards = const [],
  });

  factory BoardColumn.fromJson(Map<String, dynamic> json) {
    return BoardColumn(
      id: json['id'] as String,
      title: json['title'] as String,
      cards: [
        for (final card in json['cards'] as List<dynamic>)
          CardItem.fromJson(card as Map<String, dynamic>),
      ],
    );
  }

  final String id;
  final String title;
  final List<CardItem> cards;

  BoardColumn copyWith({String? title, List<CardItem>? cards}) {
    return BoardColumn(
      id: id,
      title: title ?? this.title,
      cards: cards ?? this.cards,
    );
  }
}

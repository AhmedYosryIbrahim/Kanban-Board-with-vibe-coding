import 'card_item.dart';

/// A board column with a title and an ordered list of cards.
class BoardColumn {
  const BoardColumn({
    required this.id,
    required this.title,
    this.cards = const [],
  });

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

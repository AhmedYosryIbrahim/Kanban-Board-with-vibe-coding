/// A single Kanban card with a title and details.
class CardItem {
  const CardItem({required this.id, required this.title, this.details = ''});

  factory CardItem.fromJson(Map<String, dynamic> json) {
    return CardItem(
      id: json['id'] as String,
      title: json['title'] as String,
      details: json['details'] as String? ?? '',
    );
  }

  final String id;
  final String title;
  final String details;

  CardItem copyWith({String? title, String? details}) {
    return CardItem(
      id: id,
      title: title ?? this.title,
      details: details ?? this.details,
    );
  }
}

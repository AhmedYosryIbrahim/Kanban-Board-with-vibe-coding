import 'package:flutter/material.dart';

import '../models/card_item.dart';
import '../theme/app_colors.dart';

/// Visual representation of a single Kanban card, draggable between columns.
class CardWidget extends StatelessWidget {
  const CardWidget({
    super.key,
    required this.card,
    required this.columnId,
    required this.fromIndex,
    required this.onEdit,
    required this.onDelete,
  });

  final CardItem card;
  final String columnId;
  final int fromIndex;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Draggable<DraggedCard>(
      hitTestBehavior: HitTestBehavior.opaque,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      maxSimultaneousDrags: 1,
      data: DraggedCard(
        cardId: card.id,
        fromColumnId: columnId,
        fromIndex: fromIndex,
      ),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 260, child: _CardContent(card: card)),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _CardContent(card: card, onEdit: onEdit, onDelete: onDelete),
      ),
      child: _CardContent(card: card, onEdit: onEdit, onDelete: onDelete),
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent({required this.card, this.onEdit, this.onDelete});

  final CardItem card;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: AppColors.accentYellow, width: 3),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (card.details.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    card.details,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          if (onEdit != null)
            InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppColors.grayText,
                ),
              ),
            ),
          if (onDelete != null)
            InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close, size: 18, color: AppColors.grayText),
              ),
            ),
        ],
      ),
    );
  }
}

/// Payload carried while dragging a card, identifying its origin column.
class DraggedCard {
  const DraggedCard({
    required this.cardId,
    required this.fromColumnId,
    required this.fromIndex,
  });

  final String cardId;
  final String fromColumnId;
  final int fromIndex;
}

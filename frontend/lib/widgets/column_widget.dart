import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/board_column.dart';
import '../theme/app_colors.dart';
import '../viewmodels/board_view_model.dart';
import 'card_dialog.dart';
import 'card_widget.dart';

/// A single Kanban column: editable title, card list, and drop target.
class ColumnWidget extends ConsumerStatefulWidget {
  const ColumnWidget({super.key, required this.column});

  final BoardColumn column;

  @override
  ConsumerState<ColumnWidget> createState() => _ColumnWidgetState();
}

class _ColumnWidgetState extends ConsumerState<ColumnWidget> {
  bool _isEditingTitle = false;
  bool _isDraggingOverColumn = false;
  int? _hoverInsertIndex;
  late final TextEditingController _titleController;
  final GlobalKey _listAreaKey = GlobalKey();
  final Map<String, GlobalKey> _cardKeys = {};

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.column.title);
  }

  @override
  void didUpdateWidget(covariant ColumnWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditingTitle && oldWidget.column.title != widget.column.title) {
      _titleController.text = widget.column.title;
    }

    final cardIds = widget.column.cards.map((card) => card.id).toSet();
    _cardKeys.removeWhere((cardId, key) => !cardIds.contains(cardId));
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _commitTitle() {
    final newTitle = _titleController.text.trim();
    if (newTitle.isNotEmpty) {
      ref
          .read(boardViewModelProvider.notifier)
          .renameColumn(widget.column.id, newTitle);
    } else {
      _titleController.text = widget.column.title;
    }
    setState(() => _isEditingTitle = false);
  }

  @override
  Widget build(BuildContext context) {
    final column = widget.column;

    return Container(
      width: 280,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF1F5),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          top: BorderSide(color: AppColors.accentYellow, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, column),
          const SizedBox(height: 12),
          Expanded(child: _buildCardList(column)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => showAddCardDialog(
              context: context,
              onSubmit: (title, details) {
                ref
                    .read(boardViewModelProvider.notifier)
                    .addCard(column.id, title, details);
              },
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add card'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, BoardColumn column) {
    if (_isEditingTitle) {
      return TextField(
        controller: _titleController,
        autofocus: true,
        style: Theme.of(context).textTheme.titleMedium,
        decoration: const InputDecoration(isDense: true),
        onSubmitted: (_) => _commitTitle(),
        onTapOutside: (_) => _commitTitle(),
      );
    }

    return InkWell(
      onTap: () => setState(() => _isEditingTitle = true),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                column.title,
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${column.cards.length}',
              style: const TextStyle(color: AppColors.grayText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardList(BoardColumn column) {
    return DragTarget<DraggedCard>(
      onWillAcceptWithDetails: (_) => true,
      onMove: (details) {
        setState(() {
          _isDraggingOverColumn = true;
          _hoverInsertIndex = _calculateInsertIndex(details.offset, column);
        });
      },
      onLeave: (_) {
        setState(() {
          _isDraggingOverColumn = false;
          _hoverInsertIndex = null;
        });
      },
      onAcceptWithDetails: (details) {
        final targetIndex = _calculateInsertIndex(details.offset, column);
        ref
            .read(boardViewModelProvider.notifier)
            .moveCard(
              cardId: details.data.cardId,
              fromColumnId: details.data.fromColumnId,
              toColumnId: column.id,
              targetIndex: targetIndex,
            );

        setState(() {
          _isDraggingOverColumn = false;
          _hoverInsertIndex = null;
        });
      },
      builder: (context, candidateData, rejectedData) {
        final showHover = _isDraggingOverColumn || candidateData.isNotEmpty;
        final insertionIndex = _hoverInsertIndex ?? column.cards.length;

        return AnimatedContainer(
          key: _listAreaKey,
          duration: const Duration(milliseconds: 110),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: showHover
                ? AppColors.bluePrimary.withValues(alpha: 0.08)
                : Colors.transparent,
            border: showHover
                ? Border.all(
                    color: AppColors.bluePrimary.withValues(alpha: 0.22),
                  )
                : null,
          ),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 8),
            physics: const NeverScrollableScrollPhysics(),
            children: _buildCardListChildren(
              column: column,
              insertionIndex: insertionIndex,
              showIndicator: showHover,
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildCardListChildren({
    required BoardColumn column,
    required int insertionIndex,
    required bool showIndicator,
  }) {
    final widgets = <Widget>[];

    if (column.cards.isEmpty) {
      widgets.add(
        Container(
          height: 120,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.bluePrimary.withValues(alpha: 0.2),
            ),
            color: AppColors.bluePrimary.withValues(alpha: 0.03),
          ),
          alignment: Alignment.center,
          child: const Text(
            'Drop cards here',
            style: TextStyle(color: AppColors.grayText, fontSize: 13),
          ),
        ),
      );
      if (showIndicator && insertionIndex == 0) {
        widgets.insert(0, const _InsertIndicator());
      }
      return widgets;
    }

    for (var index = 0; index <= column.cards.length; index++) {
      if (showIndicator && insertionIndex == index) {
        widgets.add(const _InsertIndicator());
      }

      if (index == column.cards.length) {
        break;
      }

      final card = column.cards[index];
      final cardKey = _cardKeys.putIfAbsent(card.id, () => GlobalKey());
      widgets.add(
        Container(
          key: cardKey,
          child: CardWidget(
            card: card,
            columnId: column.id,
            fromIndex: index,
            onEdit: () => showEditCardDialog(
              context: context,
              card: card,
              onSubmit: (title, details) {
                ref
                    .read(boardViewModelProvider.notifier)
                    .updateCard(column.id, card.id, title, details);
              },
            ),
            onDelete: () => ref
                .read(boardViewModelProvider.notifier)
                .deleteCard(column.id, card.id),
          ),
        ),
      );
    }

    return widgets;
  }

  int _calculateInsertIndex(Offset globalOffset, BoardColumn column) {
    if (column.cards.isEmpty) return 0;

    for (var index = 0; index < column.cards.length; index++) {
      final key = _cardKeys[column.cards[index].id];
      final context = key?.currentContext;
      if (context == null) continue;

      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;

      final cardTop = box.localToGlobal(Offset.zero).dy;
      final cardMid = cardTop + (box.size.height / 2);
      if (globalOffset.dy < cardMid) {
        return index;
      }
    }

    return column.cards.length;
  }
}

class _InsertIndicator extends StatelessWidget {
  const _InsertIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        color: AppColors.bluePrimary.withValues(alpha: 0.16),
        border: Border.all(
          color: AppColors.bluePrimary.withValues(alpha: 0.46),
        ),
      ),
    );
  }
}

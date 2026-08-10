import 'package:flutter/material.dart';

import '../models/card_item.dart';
import '../theme/app_colors.dart';

/// Dialog for creating a new card with a title and optional details.
Future<void> showAddCardDialog({
  required BuildContext context,
  required void Function(String title, String details) onSubmit,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _CardDialog(
      heading: 'Add card',
      submitLabel: 'Add',
      onSubmit: onSubmit,
    ),
  );
}

/// Dialog for editing an existing card, prefilled with its current values.
Future<void> showEditCardDialog({
  required BuildContext context,
  required CardItem card,
  required void Function(String title, String details) onSubmit,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _CardDialog(
      heading: 'Edit card',
      submitLabel: 'Save',
      initialTitle: card.title,
      initialDetails: card.details,
      onSubmit: onSubmit,
    ),
  );
}

/// Shared form behind the add and edit dialogs.
class _CardDialog extends StatefulWidget {
  const _CardDialog({
    required this.heading,
    required this.submitLabel,
    required this.onSubmit,
    this.initialTitle = '',
    this.initialDetails = '',
  });

  final String heading;
  final String submitLabel;
  final String initialTitle;
  final String initialDetails;
  final void Function(String title, String details) onSubmit;

  @override
  State<_CardDialog> createState() => _CardDialogState();
}

class _CardDialogState extends State<_CardDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _detailsController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _detailsController = TextEditingController(text: widget.initialDetails);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    widget.onSubmit(
      _titleController.text.trim(),
      _detailsController.text.trim(),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.heading),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Title is required'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _detailsController,
              decoration: const InputDecoration(labelText: 'Details'),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.purpleSecondary,
          ),
          onPressed: _submit,
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

/// Runs a board mutation and reports failures to the user.
///
/// The viewmodel has already restored the previous state by the time this sees
/// the error, so the board visibly snaps back; the message says why.
Future<void> runBoardAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$error')));
  }
}

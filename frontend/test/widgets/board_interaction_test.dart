import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kanban_frontend/widgets/card_widget.dart';

import '../support/test_app.dart';

Finder _cardNamed(String title) =>
    find.widgetWithText(CardWidget, title);

void main() {
  testWidgets('tapping edit opens the dialog prefilled with the card values', (
    tester,
  ) async {
    useWideSurface(tester);
    await pumpSignedInApp(tester);

    await tester.tap(
      find.descendant(
        of: _cardNamed('Design onboarding flow'),
        matching: find.byIcon(Icons.edit_outlined),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit card'), findsOneWidget);

    final fields = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList();
    expect(fields, hasLength(2));
    expect(fields[0].controller.text, 'Design onboarding flow');
    expect(
      fields[1].controller.text,
      'Sketch wireframes for the new user onboarding.',
    );
  });

  testWidgets('editing a card updates it on the board', (tester) async {
    useWideSurface(tester);
    await pumpSignedInApp(tester);

    await tester.tap(
      find.descendant(
        of: _cardNamed('Design onboarding flow'),
        matching: find.byIcon(Icons.edit_outlined),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Renamed task');
    await tester.enterText(find.byType(TextFormField).last, 'Fresh details');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Renamed task'), findsOneWidget);
    expect(find.text('Fresh details'), findsOneWidget);
    expect(find.text('Design onboarding flow'), findsNothing);
  });

  testWidgets('an empty title is rejected by the edit dialog', (tester) async {
    useWideSurface(tester);
    await pumpSignedInApp(tester);

    await tester.tap(
      find.descendant(
        of: _cardNamed('Design onboarding flow'),
        matching: find.byIcon(Icons.edit_outlined),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '   ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Title is required'), findsOneWidget);
    expect(find.text('Edit card'), findsOneWidget);
  });

  testWidgets('dragging a card moves it to another column', (tester) async {
    useWideSurface(tester);
    await pumpSignedInApp(tester);

    // "Set up CI pipeline" starts in To Do; drag it onto In Progress.
    final source = tester.getCenter(find.text('Set up CI pipeline'));
    final target = tester.getCenter(find.text('Implement drag and drop'));

    final gesture = await tester.startGesture(source);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(Offset(source.dx + 60, source.dy));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(Offset(target.dx, target.dy - 30));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(Offset(target.dx, target.dy - 20));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pumpAndSettle();

    final moved = tester.widget<CardWidget>(_cardNamed('Set up CI pipeline'));
    expect(moved.columnId, 'in-progress');
  });
}

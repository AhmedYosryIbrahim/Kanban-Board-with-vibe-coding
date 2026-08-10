import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_frontend/data/chat_repository.dart';
import 'package:kanban_frontend/models/board.dart';
import 'package:kanban_frontend/models/card_item.dart';
import 'package:kanban_frontend/models/chat_message.dart';
import 'package:kanban_frontend/widgets/chat_sidebar.dart';

import '../support/board_fixture.dart';
import '../support/test_app.dart';

Finder get _sidebar => find.byType(ChatSidebar);
Finder get _input =>
    find.descendant(of: _sidebar, matching: find.byType(TextField));
Finder get _sendButton =>
    find.descendant(of: _sidebar, matching: find.byIcon(Icons.send));

Future<void> _openSidebar(WidgetTester tester) async {
  await tester.tap(find.text('Assistant'));
  await tester.pumpAndSettle();
}

Future<void> _ask(WidgetTester tester, String message) async {
  await tester.enterText(_input, message);
  await tester.tap(_sendButton);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the sidebar is closed until it is opened, and closes again', (
    tester,
  ) async {
    useWideSurface(tester);
    await pumpSignedInApp(tester);

    expect(_sidebar, findsNothing);

    await _openSidebar(tester);
    expect(_sidebar, findsOneWidget);

    await tester.tap(
      find.descendant(of: _sidebar, matching: find.byIcon(Icons.close)),
    );
    await tester.pumpAndSettle();

    expect(_sidebar, findsNothing);
  });

  testWidgets('the stored thread is shown when the sidebar opens', (
    tester,
  ) async {
    useWideSurface(tester);
    final chat = FakeChatRepository(
      history: const [
        ChatMessage.user('Earlier question'),
        ChatMessage.assistant('Earlier answer'),
      ],
    );

    await pumpSignedInApp(tester, chat: chat);
    await _openSidebar(tester);

    expect(find.text('Earlier question'), findsOneWidget);
    expect(find.text('Earlier answer'), findsOneWidget);
  });

  testWidgets('sending renders the user message and the reply', (tester) async {
    useWideSurface(tester);
    final chat = FakeChatRepository(reply: 'Added it.');

    await pumpSignedInApp(tester, chat: chat);
    await _openSidebar(tester);
    await _ask(tester, 'Add a card called Deploy');

    expect(find.text('Add a card called Deploy'), findsOneWidget);
    expect(find.text('Added it.'), findsOneWidget);
    expect(chat.sent, ['Add a card called Deploy']);

    // The composer is cleared after a successful send.
    expect(tester.widget<TextField>(_input).controller!.text, isEmpty);
  });

  testWidgets('a pending indicator shows while the reply is in flight', (
    tester,
  ) async {
    useWideSurface(tester);
    final chat = FakeChatRepository()..holdSend = Completer<ChatReply>();

    await pumpSignedInApp(tester, chat: chat);
    await _openSidebar(tester);

    await tester.enterText(_input, 'Add a card');
    await tester.tap(_sendButton);
    await tester.pump();

    expect(
      find.descendant(
        of: _sidebar,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    chat.holdSend!.complete(
      const ChatReply(reply: 'Added it.', boardChanged: false),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: _sidebar,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    expect(find.text('Added it.'), findsOneWidget);
  });

  testWidgets('a failed send shows the error and gives the text back', (
    tester,
  ) async {
    useWideSurface(tester);
    final chat = FakeChatRepository()
      ..failNextWith = const ChatException('Message is required');

    await pumpSignedInApp(tester, chat: chat);
    await _openSidebar(tester);
    await _ask(tester, 'Add a card');

    expect(find.text('Message is required'), findsOneWidget);
    expect(tester.widget<TextField>(_input).controller!.text, 'Add a card');
  });

  testWidgets('a board change from chat refreshes the board with no action', (
    tester,
  ) async {
    useWideSurface(tester);
    final board = FakeBoardRepository();
    final chat = FakeChatRepository(reply: 'Added it.', boardChanged: true);

    await pumpSignedInApp(tester, board: board, chat: chat);
    await _openSidebar(tester);

    expect(find.text('From the assistant'), findsNothing);

    // What the backend would return once the AI has applied its operations.
    final fixture = buildFixtureBoard();
    board.board = Board(
      id: fixture.id,
      name: fixture.name,
      subtitle: fixture.subtitle,
      columns: [
        fixture.columns.first.copyWith(
          cards: [
            ...fixture.columns.first.cards,
            const CardItem(id: 'new', title: 'From the assistant'),
          ],
        ),
        ...fixture.columns.skip(1),
      ],
    );

    await _ask(tester, 'Add a card called From the assistant');

    expect(find.text('From the assistant'), findsOneWidget);
    expect(board.calls, ['fetchBoard', 'fetchBoard']);
  });

  testWidgets('the board is not refetched when nothing changed', (
    tester,
  ) async {
    useWideSurface(tester);
    final board = FakeBoardRepository();
    final chat = FakeChatRepository(reply: 'You have 6 cards.');

    await pumpSignedInApp(tester, board: board, chat: chat);
    await _openSidebar(tester);
    await _ask(tester, 'How many cards?');

    expect(find.text('You have 6 cards.'), findsOneWidget);
    expect(board.calls, ['fetchBoard']);
  });

  testWidgets('on a wide viewport the sidebar shrinks the board beside it', (
    tester,
  ) async {
    useWideSurface(tester);
    await pumpSignedInApp(tester);

    final before = tester.getRect(find.text('Product Roadmap')).left;
    await _openSidebar(tester);
    final after = tester.getRect(find.text('Product Roadmap')).left;

    expect(after, lessThan(before));
    expect(find.text('To Do'), findsOneWidget);
  });

  testWidgets('on a narrow viewport the sidebar overlays instead of squeezing',
      (tester) async {
    tester.view.physicalSize = const Size(700, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpSignedInApp(tester);

    final before = tester.getRect(find.text('Product Roadmap')).left;
    await _openSidebar(tester);
    final after = tester.getRect(find.text('Product Roadmap')).left;

    expect(after, before);
    expect(tester.getRect(_sidebar).right, 700);
    expect(tester.getRect(_sidebar).width, chatSidebarWidth);
  });
}

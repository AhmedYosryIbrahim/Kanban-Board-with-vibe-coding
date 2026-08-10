import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanban_frontend/data/board_repository.dart';
import 'package:kanban_frontend/data/chat_repository.dart';
import 'package:kanban_frontend/models/chat_message.dart';
import 'package:kanban_frontend/viewmodels/board_view_model.dart';
import 'package:kanban_frontend/viewmodels/chat_view_model.dart';

import '../support/fake_board_repository.dart';
import '../support/fake_chat_repository.dart';

void main() {
  late ProviderContainer container;
  late FakeChatRepository chat;
  late FakeBoardRepository board;

  setUp(() {
    chat = FakeChatRepository();
    board = FakeBoardRepository();
    container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(chat),
        boardRepositoryProvider.overrideWithValue(board),
      ],
    );
    addTearDown(container.dispose);
  });

  /// Riverpod 3 auto-disposes providers with no listeners, so hold one.
  Future<void> load() {
    container.listen(
      chatViewModelProvider,
      (previous, next) {},
      onError: (error, stackTrace) {},
    );
    return container.read(chatViewModelProvider.future);
  }

  ChatState chatState() => container.read(chatViewModelProvider).value!;

  List<(ChatRole, String)> thread() =>
      chatState().messages.map((m) => (m.role, m.content)).toList();

  ChatViewModel notifier() => container.read(chatViewModelProvider.notifier);

  test('the thread is loaded from the backend so it survives a reload', () async {
    chat.history.addAll(const [
      ChatMessage.user('Earlier question'),
      ChatMessage.assistant('Earlier answer'),
    ]);

    await load();

    expect(thread(), [
      (ChatRole.user, 'Earlier question'),
      (ChatRole.assistant, 'Earlier answer'),
    ]);
  });

  test('sending appends the user message then the reply', () async {
    await load();
    chat.reply = 'Added it.';

    await notifier().send('Add a card');

    expect(thread(), [
      (ChatRole.user, 'Add a card'),
      (ChatRole.assistant, 'Added it.'),
    ]);
    expect(chat.sent, ['Add a card']);
    expect(chatState().isSending, isFalse);
  });

  test('a failed send replaces the message with an error and rethrows',
      () async {
    await load();
    chat.failNextWith = const ChatException('Message is required');

    await expectLater(
      notifier().send('Add a card'),
      throwsA(isA<ChatException>()),
    );

    // The message never reached the backend, so it is not left in the thread.
    expect(thread(), [(ChatRole.error, 'Message is required')]);
    expect(chatState().isSending, isFalse);
  });

  test('a failed send keeps earlier messages', () async {
    chat.history.add(const ChatMessage.user('Earlier'));
    await load();
    chat.failNextWith = const ChatException('Boom');

    await expectLater(notifier().send('Next'), throwsA(isA<ChatException>()));

    expect(thread(), [
      (ChatRole.user, 'Earlier'),
      (ChatRole.error, 'Boom'),
    ]);
  });

  test('boardChanged true reloads the board', () async {
    await load();
    await container.read(boardViewModelProvider.future);
    expect(board.calls, ['fetchBoard']);

    chat.boardChanged = true;
    await notifier().send('Add a card');
    await container.read(boardViewModelProvider.future);

    expect(board.calls, ['fetchBoard', 'fetchBoard']);
  });

  test('boardChanged false leaves the board alone', () async {
    await load();
    await container.read(boardViewModelProvider.future);

    chat.boardChanged = false;
    await notifier().send('What is on my board?');
    await container.read(boardViewModelProvider.future);

    expect(board.calls, ['fetchBoard']);
  });

  test('a failed load surfaces as an error state', () async {
    chat.loadError = const ChatException('Not signed in');

    container.listen(
      chatViewModelProvider,
      (previous, next) {},
      onError: (error, stackTrace) {},
    );
    for (var i = 0;
        i < 10 && container.read(chatViewModelProvider).isLoading;
        i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(container.read(chatViewModelProvider).hasError, isTrue);
  });
}

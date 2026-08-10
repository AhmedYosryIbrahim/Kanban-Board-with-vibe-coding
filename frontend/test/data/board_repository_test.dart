import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kanban_frontend/data/board_repository.dart';

final _baseUri = Uri.parse('http://localhost:3000/');

const _boardJson = {
  'id': 1,
  'name': 'Product Roadmap',
  'subtitle': 'Q4 delivery board',
  'columns': [
    {
      'id': 'col-1',
      'title': 'To Do',
      'cards': [
        {'id': 'card-1', 'title': 'First', 'details': 'Details'},
      ],
    },
    {'id': 'col-2', 'title': 'Done', 'cards': <Map<String, dynamic>>[]},
  ],
};

/// Captures the single request the repository makes.
class _Captured {
  late http.Request request;
  String get body => request.body;
  Map<String, dynamic> get json =>
      jsonDecode(request.body) as Map<String, dynamic>;
}

(BoardRepository, _Captured) repositoryReturning(
  Object? body, {
  int status = 200,
}) {
  final captured = _Captured();
  final client = MockClient((request) async {
    captured.request = request;
    return http.Response(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );
  });

  return (BoardRepository(client: client, baseUri: _baseUri), captured);
}

void main() {
  test('fetchBoard parses the board', () async {
    final (repository, captured) = repositoryReturning(_boardJson);

    final board = await repository.fetchBoard();

    expect(captured.request.method, 'GET');
    expect(captured.request.url.path, '/api/board');
    expect(board.id, 1);
    expect(board.name, 'Product Roadmap');
    expect(board.subtitle, 'Q4 delivery board');
    expect(board.columns, hasLength(2));
    expect(board.columns.first.cards.single.title, 'First');
    expect(board.columns.last.cards, isEmpty);
  });

  test('renameColumn PATCHes the column with the new title', () async {
    final (repository, captured) = repositoryReturning({
      'id': 'col-1',
      'title': 'Backlog',
    });

    await repository.renameColumn('col-1', 'Backlog');

    expect(captured.request.method, 'PATCH');
    expect(captured.request.url.path, '/api/columns/col-1');
    expect(captured.json, {'title': 'Backlog'});
  });

  test('createCard POSTs the card and returns it with the server id', () async {
    final (repository, captured) = repositoryReturning({
      'id': 'server-id',
      'title': 'New',
      'details': 'Details',
    }, status: 201);

    final card = await repository.createCard('col-1', 'New', 'Details');

    expect(captured.request.method, 'POST');
    expect(captured.request.url.path, '/api/cards');
    expect(captured.json, {
      'columnId': 'col-1',
      'title': 'New',
      'details': 'Details',
    });
    expect(card.id, 'server-id');
    expect(card.title, 'New');
  });

  test('updateCard PATCHes the card', () async {
    final (repository, captured) = repositoryReturning({
      'id': 'card-1',
      'title': 'Renamed',
      'details': 'Fresh',
    });

    await repository.updateCard('card-1', 'Renamed', 'Fresh');

    expect(captured.request.method, 'PATCH');
    expect(captured.request.url.path, '/api/cards/card-1');
    expect(captured.json, {'title': 'Renamed', 'details': 'Fresh'});
  });

  test('deleteCard DELETEs the card and tolerates an empty 204', () async {
    final (repository, captured) = repositoryReturning(null, status: 204);

    await repository.deleteCard('card-1');

    expect(captured.request.method, 'DELETE');
    expect(captured.request.url.path, '/api/cards/card-1');
  });

  test('moveCard POSTs the destination column and position', () async {
    final (repository, captured) = repositoryReturning(_boardJson);

    await repository.moveCard('card-1', 'col-2', 3);

    expect(captured.request.method, 'POST');
    expect(captured.request.url.path, '/api/cards/card-1/move');
    expect(captured.json, {'toColumnId': 'col-2', 'position': 3});
  });

  test('an error response throws with the backend message', () async {
    final (repository, _) = repositoryReturning({
      'error': 'Title is required',
    }, status: 400);

    await expectLater(
      repository.renameColumn('col-1', ''),
      throwsA(
        isA<BoardException>().having(
          (e) => e.message,
          'message',
          'Title is required',
        ),
      ),
    );
  });

  test('a 401 on load throws rather than returning an empty board', () async {
    final (repository, _) = repositoryReturning({
      'error': 'Not signed in',
    }, status: 401);

    await expectLater(
      repository.fetchBoard(),
      throwsA(isA<BoardException>()),
    );
  });

  test('an error with an empty body still throws', () async {
    final (repository, _) = repositoryReturning(null, status: 500);

    await expectLater(
      repository.deleteCard('card-1'),
      throwsA(isA<BoardException>()),
    );
  });

  test('paths resolve against the base uri the app was served from', () async {
    final captured = _Captured();
    final client = MockClient((request) async {
      captured.request = request;
      return http.Response(jsonEncode(_boardJson), 200);
    });
    final repository = BoardRepository(
      client: client,
      baseUri: Uri.parse('http://example.test:8080/some/page'),
    );

    await repository.fetchBoard();

    expect(captured.request.url.toString(), 'http://example.test:8080/api/board');
  });
}

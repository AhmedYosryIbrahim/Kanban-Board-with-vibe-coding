import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/board.dart';
import '../models/card_item.dart';

/// Raised when a board request fails, carrying the backend's message.
class BoardException implements Exception {
  const BoardException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Wraps the board endpoints. The session cookie rides along automatically
/// because the app is served from the same origin as the API.
class BoardRepository {
  BoardRepository({http.Client? client, Uri? baseUri})
    : _client = client ?? http.Client(),
      _baseUri = baseUri ?? Uri.base;

  final http.Client _client;
  final Uri _baseUri;

  static const _json = {'content-type': 'application/json'};

  Uri _url(String path) => _baseUri.resolve(path);

  Future<Board> fetchBoard() async {
    final response = await _client.get(_url('/api/board'));

    return Board.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<void> renameColumn(String columnId, String title) async {
    final response = await _client.patch(
      _url('/api/columns/$columnId'),
      headers: _json,
      body: jsonEncode({'title': title}),
    );

    _decode(response);
  }

  Future<CardItem> createCard(
    String columnId,
    String title,
    String details,
  ) async {
    final response = await _client.post(
      _url('/api/cards'),
      headers: _json,
      body: jsonEncode({
        'columnId': columnId,
        'title': title,
        'details': details,
      }),
    );

    return CardItem.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Future<void> updateCard(String cardId, String title, String details) async {
    final response = await _client.patch(
      _url('/api/cards/$cardId'),
      headers: _json,
      body: jsonEncode({'title': title, 'details': details}),
    );

    _decode(response);
  }

  Future<void> deleteCard(String cardId) async {
    final response = await _client.delete(_url('/api/cards/$cardId'));

    _decode(response);
  }

  Future<void> moveCard(String cardId, String toColumnId, int position) async {
    final response = await _client.post(
      _url('/api/cards/$cardId/move'),
      headers: _json,
      body: jsonEncode({'toColumnId': toColumnId, 'position': position}),
    );

    _decode(response);
  }

  /// Returns the parsed body, or throws with the backend's error message.
  Object? _decode(http.Response response) {
    if (response.statusCode == 204 || response.body.isEmpty) {
      if (response.statusCode >= 400) {
        throw BoardException('Request failed (${response.statusCode})');
      }
      return null;
    }

    final body = jsonDecode(response.body);

    if (response.statusCode >= 400) {
      final message = body is Map<String, dynamic> ? body['error'] : null;
      throw BoardException(message as String? ?? 'Request failed');
    }

    return body;
  }
}

final boardRepositoryProvider = Provider<BoardRepository>(
  (ref) => BoardRepository(),
);

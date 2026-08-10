import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/chat_message.dart';

/// Raised when a chat request fails, carrying the backend's message.
class ChatException implements Exception {
  const ChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Wraps the chat endpoints.
class ChatRepository {
  ChatRepository({http.Client? client, Uri? baseUri})
    : _client = client ?? http.Client(),
      _baseUri = baseUri ?? Uri.base;

  final http.Client _client;
  final Uri _baseUri;

  Uri _url(String path) => _baseUri.resolve(path);

  Future<List<ChatMessage>> fetchMessages() async {
    final response = await _client.get(_url('/api/chat'));
    final body = _decode(response) as Map<String, dynamic>;

    return [
      for (final message in body['messages'] as List<dynamic>)
        ChatMessage.fromJson(message as Map<String, dynamic>),
    ];
  }

  Future<ChatReply> send(String message) async {
    final response = await _client.post(
      _url('/api/chat'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'message': message}),
    );

    return ChatReply.fromJson(_decode(response) as Map<String, dynamic>);
  }

  Object? _decode(http.Response response) {
    if (response.body.isEmpty) {
      if (response.statusCode >= 400) {
        throw ChatException('Request failed (${response.statusCode})');
      }
      return null;
    }

    final body = jsonDecode(response.body);

    if (response.statusCode >= 400) {
      final message = body is Map<String, dynamic> ? body['error'] : null;
      throw ChatException(message as String? ?? 'Request failed');
    }

    return body;
  }
}

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(),
);

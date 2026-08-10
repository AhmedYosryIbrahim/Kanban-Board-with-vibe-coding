import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Raised when the backend rejects a sign in attempt.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Talks to the session endpoints on the backend.
///
/// The app is served from the same origin as the API, so the browser attaches
/// the session cookie by itself and nothing here handles it explicitly.
class AuthRepository {
  AuthRepository({http.Client? client, Uri? baseUri})
    : _client = client ?? http.Client(),
      _baseUri = baseUri ?? Uri.base;

  final http.Client _client;
  final Uri _baseUri;

  Uri _url(String path) => _baseUri.resolve(path);

  /// Returns the signed in username, or null when there is no session.
  Future<String?> currentUser() async {
    final response = await _client.get(_url('/api/me'));

    if (response.statusCode == 401) return null;
    if (response.statusCode != 200) {
      throw AuthException('Could not reach the server');
    }

    return (jsonDecode(response.body) as Map<String, dynamic>)['username']
        as String;
  }

  Future<String> signIn(String username, String password) async {
    final response = await _client.post(
      _url('/api/login'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 401) {
      throw const AuthException('Invalid username or password');
    }
    if (response.statusCode != 200) {
      throw const AuthException('Could not reach the server');
    }

    return (jsonDecode(response.body) as Map<String, dynamic>)['username']
        as String;
  }

  Future<void> signOut() async {
    await _client.post(_url('/api/logout'));
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

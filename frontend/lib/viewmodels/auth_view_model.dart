import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';

/// Holds the signed in username, or null when signed out.
///
/// The session lives in an HttpOnly cookie the browser owns, so on start up
/// the only way to know whether one exists is to ask the backend.
class AuthViewModel extends AsyncNotifier<String?> {
  @override
  Future<String?> build() {
    return ref.read(authRepositoryProvider).currentUser();
  }

  /// Throws [AuthException] when the credentials are rejected, so the login
  /// screen can show the message without the provider entering an error state.
  Future<void> signIn(String username, String password) async {
    final signedIn = await ref
        .read(authRepositoryProvider)
        .signIn(username, password);

    state = AsyncData(signedIn);
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();

    state = const AsyncData(null);
  }
}

final authViewModelProvider = AsyncNotifierProvider<AuthViewModel, String?>(
  AuthViewModel.new,
);

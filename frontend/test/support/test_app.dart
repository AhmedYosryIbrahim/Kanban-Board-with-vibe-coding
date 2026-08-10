import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kanban_frontend/data/auth_repository.dart';
import 'package:kanban_frontend/data/board_repository.dart';
import 'package:kanban_frontend/main.dart';

import 'fake_board_repository.dart';

export 'fake_board_repository.dart';

/// In-memory stand-in for [AuthRepository].
///
/// Private members of [AuthRepository] are not part of its interface outside
/// its own library, so implementing the three public methods is enough.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.signedInAs, this.acceptsCredentials = true});

  String? signedInAs;
  bool acceptsCredentials;
  int signOutCalls = 0;

  @override
  Future<String?> currentUser() async => signedInAs;

  @override
  Future<String> signIn(String username, String password) async {
    if (!acceptsCredentials) {
      throw const AuthException('Invalid username or password');
    }
    signedInAs = username;
    return username;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    signedInAs = null;
  }
}

/// Gives the board a viewport wide enough for several columns to be on screen.
void useWideSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Pumps the real app with the session check answered by [auth] and the board
/// served by [board].
///
/// Pass `settle: false` to inspect a transient state such as the loading
/// spinner, which `pumpAndSettle` would otherwise run straight past.
Future<void> pumpApp(
  WidgetTester tester, {
  required AuthRepository auth,
  BoardRepository? board,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        boardRepositoryProvider.overrideWithValue(
          board ?? FakeBoardRepository(),
        ),
      ],
      child: const KanbanApp(),
    ),
  );

  if (settle) await tester.pumpAndSettle();
}

/// Pumps the app already signed in, for tests about the board itself.
Future<void> pumpSignedInApp(
  WidgetTester tester, {
  BoardRepository? board,
  bool settle = true,
}) {
  return pumpApp(
    tester,
    auth: FakeAuthRepository(signedInAs: 'user'),
    board: board,
    settle: settle,
  );
}

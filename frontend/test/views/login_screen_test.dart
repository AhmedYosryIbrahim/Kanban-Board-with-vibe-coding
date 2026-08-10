import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

Future<void> _signIn(
  WidgetTester tester, {
  String username = 'user',
  String password = 'password',
}) async {
  await tester.enterText(find.byType(TextFormField).first, username);
  await tester.enterText(find.byType(TextFormField).last, password);
  await tester.tap(find.text('Sign in'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the login screen is shown when there is no session', (
    tester,
  ) async {
    useWideSurface(tester);
    await pumpApp(tester, auth: FakeAuthRepository());

    expect(find.text('Sign in to your board'), findsOneWidget);
    expect(find.text('To Do'), findsNothing);
  });

  testWidgets('the board is shown when a session already exists', (
    tester,
  ) async {
    useWideSurface(tester);
    await pumpApp(tester, auth: FakeAuthRepository(signedInAs: 'user'));

    expect(find.text('To Do'), findsOneWidget);
    expect(find.text('Sign in to your board'), findsNothing);
  });

  testWidgets('rejected credentials show an error and stay on login', (
    tester,
  ) async {
    useWideSurface(tester);
    await pumpApp(
      tester,
      auth: FakeAuthRepository(acceptsCredentials: false),
    );

    await _signIn(tester, password: 'wrong');

    expect(find.text('Invalid username or password'), findsOneWidget);
    expect(find.text('Sign in to your board'), findsOneWidget);
    expect(find.text('To Do'), findsNothing);
  });

  testWidgets('a successful login shows the board', (tester) async {
    useWideSurface(tester);
    await pumpApp(tester, auth: FakeAuthRepository());

    await _signIn(tester);

    expect(find.text('To Do'), findsOneWidget);
    expect(find.text('Design onboarding flow'), findsOneWidget);
    expect(find.text('Sign in to your board'), findsNothing);
  });

  testWidgets('empty fields are rejected before any request is made', (
    tester,
  ) async {
    useWideSurface(tester);
    final auth = FakeAuthRepository();
    await pumpApp(tester, auth: auth);

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Username is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(auth.signedInAs, isNull);
  });

  testWidgets('logging out returns to the login screen', (tester) async {
    useWideSurface(tester);
    final auth = FakeAuthRepository(signedInAs: 'user');
    await pumpApp(tester, auth: auth);

    expect(find.text('To Do'), findsOneWidget);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();

    expect(auth.signOutCalls, 1);
    expect(find.text('Sign in to your board'), findsOneWidget);
    expect(find.text('To Do'), findsNothing);
  });

  testWidgets('the signed in username is shown in the top bar', (tester) async {
    useWideSurface(tester);
    await pumpApp(tester, auth: FakeAuthRepository(signedInAs: 'user'));

    expect(find.widgetWithText(Row, 'user'), findsWidgets);
  });
}

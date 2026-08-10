import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('Board screen shows dummy columns and cards', (tester) async {
    useWideSurface(tester);
    await pumpSignedInApp(tester);

    expect(find.text('To Do'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Blocked'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Design onboarding flow'), findsOneWidget);
  });
}

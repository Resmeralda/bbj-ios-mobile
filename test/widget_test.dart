import 'package:bjj_app/main.dart';
import 'package:bjj_app/router.dart';
import 'package:bjj_app/screens/login_screen.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App redirects on auth changes and navigates to Training', (
    WidgetTester tester,
  ) async {
    final auth = MockFirebaseAuth();
    final router = createAppRouter(auth);
    addTearDown(router.dispose);

    await tester.pumpWidget(BjjFitnessApp(router: router));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await auth.signInWithEmailAndPassword(
      email: 'athlete@example.test',
      password: 'test-password',
    );
    await tester.pumpAndSettle();

    // Home screen is shown first.
    expect(find.text('Hi, Esme!'), findsOneWidget);

    // Tap the Training tab in the bottom bar.
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Training'),
      ),
    );
    await tester.pumpAndSettle();

    // Training screen content is visible.
    expect(find.text('Log a Training Session'), findsOneWidget);

    await auth.signOut();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

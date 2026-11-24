import 'package:bjj_app/main.dart';
import 'package:bjj_app/profile_store.dart';
import 'package:bjj_app/router.dart';
import 'package:bjj_app/screens/edit_profile_screen.dart';
import 'package:bjj_app/screens/history_screen.dart';
import 'package:bjj_app/screens/login_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App redirects on auth changes and navigates to Training', (
    WidgetTester tester,
  ) async {
    final auth = MockFirebaseAuth(mockUser: MockUser(displayName: 'Esme'));
    final profiles = ProfileStore(firestore: FakeFirebaseFirestore());
    addTearDown(profiles.dispose);
    final authSubscription = auth.authStateChanges().listen(
      (user) => profiles.bind(user?.uid, authName: user?.displayName),
    );
    addTearDown(authSubscription.cancel);
    final router = createAppRouter(auth, profiles: profiles);
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

    await tester.tap(find.byTooltip('Profile settings'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(find.text('Change photo'), findsNothing);
    router.pop();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('View All'), 150);
    expect(find.text('Quick Access'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    await tester.tap(find.text('View All'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();

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

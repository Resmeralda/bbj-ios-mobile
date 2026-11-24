import 'package:bjj_app/main.dart';
import 'package:bjj_app/profile_store.dart';
import 'package:bjj_app/router.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Saving a profile returns to Profile and confirms the change', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final original = profileStore.profile;
    addTearDown(() => profileStore.update(original));
    final router = createAppRouter(MockFirebaseAuth(signedIn: true));
    addTearDown(router.dispose);

    await tester.pumpWidget(BjjFitnessApp(router: router));
    router.go('/home/profile');
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.edit),
      ),
    );
    await tester.pumpAndSettle();

    final name = find.widgetWithText(TextFormField, 'Name');
    await tester.enterText(name, '  Casey  ');
    final save = find.widgetWithText(FilledButton, 'Save Changes');
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(profileStore.profile.name, 'Casey');
    expect(find.text('Casey'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Profile updated'), findsOneWidget);
    expect(save, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

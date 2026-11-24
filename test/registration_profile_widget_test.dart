import 'dart:async';

import 'package:bjj_app/main.dart';
import 'package:bjj_app/profile_store.dart';
import 'package:bjj_app/router.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RegistrationAuth extends MockFirebaseAuth {
  _RegistrationAuth() : super(mockUser: MockUser(uid: 'new-athlete'));

  final allowCredential = Completer<void>();

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await allowCredential.future;
    return credential;
  }
}

void main() {
  testWidgets('Registration refreshes Home after the Auth name is available', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _RegistrationAuth();
    final firestore = FakeFirebaseFirestore();
    final profiles = ProfileStore(firestore: firestore);
    addTearDown(profiles.dispose);
    final subscription = auth.authStateChanges().listen(
      (user) => profiles.bind(user?.uid, authName: user?.displayName),
    );
    addTearDown(subscription.cancel);
    final router = createAppRouter(auth, profiles: profiles);
    addTearDown(router.dispose);

    await tester.pumpWidget(BjjFitnessApp(router: router));
    router.go('/register');
    await tester.pumpAndSettle();
    for (final (label, value) in [
      ('Name', '  Taylor  '),
      ('Email', 'taylor@example.test'),
      ('Password', 'test-password'),
      ('Confirm Password', 'test-password'),
    ]) {
      await tester.enterText(find.widgetWithText(TextFormField, label), value);
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('Hi, Athlete!'), findsOneWidget);
    expect(auth.currentUser?.uid, 'new-athlete');
    auth.allowCredential.complete();
    await tester.pumpAndSettle();
    expect(auth.currentUser?.displayName, 'Taylor');
    expect(find.text('Hi, Taylor!'), findsOneWidget);
    expect(
      (await firestore.doc('users/new-athlete/settings/profile').get()).exists,
      isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

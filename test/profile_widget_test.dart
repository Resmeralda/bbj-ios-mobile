import 'dart:async';

import 'package:bjj_app/main.dart';
import 'package:bjj_app/models/user_profile.dart';
import 'package:bjj_app/profile_store.dart';
import 'package:bjj_app/router.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _profilePath = 'users/athlete/settings/profile';

class _PausedProfileStore extends ProfileStore {
  _PausedProfileStore({required super.firestore});

  final pendingSave = Completer<void>();

  @override
  Future<void> save(UserProfile draft, {required Object account}) async {
    await pendingSave.future;
    await super.save(draft, account: account);
  }
}

Future<GoRouter> _openEditor(WidgetTester tester, ProfileStore profiles) async {
  await tester.binding.setSurfaceSize(const Size(800, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(profiles.dispose);
  final auth = MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(uid: 'athlete', displayName: 'Auth athlete'),
  );
  profiles.bind(auth.currentUser!.uid, authName: auth.currentUser!.displayName);
  final router = createAppRouter(auth, profiles: profiles);
  addTearDown(router.dispose);
  await tester.pumpWidget(BjjFitnessApp(router: router));
  router.go('/home/profile');
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.edit)),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('Saving a profile returns to Profile and confirms the change', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.doc(_profilePath).set({
      'name': 'Saved athlete',
      'weeklyGoal': 2,
    });
    final profiles = _PausedProfileStore(firestore: firestore);
    final router = await _openEditor(tester, profiles);

    final name = find.widgetWithText(TextFormField, 'Name');
    expect(find.text('Saved athlete'), findsOneWidget);
    expect(find.text('Weekly training goal: 2 sessions'), findsOneWidget);
    await tester.enterText(name, '  Casey  ');
    final slider = find.byType(Slider);
    tester.widget<Slider>(slider).onChanged!(6);
    final save = find.widgetWithText(FilledButton, 'Save Changes');
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
          .onPressed,
      isNull,
    );
    expect(find.byType(SnackBar), findsNothing);
    expect((await firestore.doc(_profilePath).get()).data()!['weeklyGoal'], 2);
    profiles.pendingSave.complete();
    await tester.pumpAndSettle();

    expect(profiles.profile.name, 'Casey');
    expect((await firestore.doc(_profilePath).get()).data()!['weeklyGoal'], 6);
    expect(find.text('Casey'), findsOneWidget);
    expect(find.text('6 sessions'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Profile updated'), findsOneWidget);
    expect(save, findsNothing);
    router.go('/home');
    await tester.pumpAndSettle();
    expect(find.text('3 of 6 sessions'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('A denied save keeps the editor open with the draft intact', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore(
      securityRules: '''
      service cloud.firestore {
        match /databases/{database}/documents {
          match /users/{uid}/settings/profile {
            allow read: if true;
            allow write: if false;
          }
        }
      }
    ''',
    );
    final profiles = ProfileStore(firestore: firestore);
    await _openEditor(tester, profiles);
    final name = find.widgetWithText(TextFormField, 'Name');
    await tester.enterText(name, 'Unsaved draft');
    tester.widget<Slider>(find.byType(Slider)).onChanged!(7);
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Save Changes');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(
      find.text('Could not save your profile. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Unsaved draft'), findsOneWidget);
    expect(find.text('Weekly training goal: 7 sessions'), findsOneWidget);
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    expect(find.text('Profile updated'), findsNothing);
    expect(profiles.profile.name, 'Auth athlete');
    expect(profiles.profile.weeklyGoal, 4);
    expect((await firestore.doc(_profilePath).get()).exists, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

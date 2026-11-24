import 'dart:async';

import 'package:bjj_app/data/role_store.dart';
import 'package:bjj_app/main.dart';
import 'package:bjj_app/profile_store.dart';
import 'package:bjj_app/router.dart';
import 'package:bjj_app/screens/admin_dashboard_screen.dart';
import 'package:bjj_app/screens/login_screen.dart';
import 'package:bjj_app/screens/profile_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _profile = '/home/profile';
const _admin = '$_profile/admin';

Future<GoRouter> _open(
  WidgetTester tester,
  Stream<RoleDocument> snapshots, {
  bool signedIn = true,
}) async {
  final auth = MockFirebaseAuth(
    signedIn: signedIn,
    mockUser: MockUser(uid: 'athlete', displayName: 'Athlete'),
  );
  final roles = RoleStore.withWatch((_) => snapshots);
  final profiles = ProfileStore(firestore: FakeFirebaseFirestore());
  final subscription = bindAuthStores(
    auth,
    roles: roles,
    bindPersonalData: (user) =>
        profiles.bind(user?.uid, authName: user?.displayName),
  );
  final router = createAppRouter(auth, roles: roles, profiles: profiles);
  addTearDown(roles.dispose);
  addTearDown(profiles.dispose);
  addTearDown(subscription.cancel);
  addTearDown(router.dispose);
  await tester.binding.setSurfaceSize(const Size(800, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(BjjFitnessApp(router: router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('Signed-out direct admin navigation goes to login', (
    tester,
  ) async {
    final router = await _open(tester, const Stream.empty(), signedIn: false);
    router.go(_admin);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AdminDashboardScreen), findsNothing);
  });

  testWidgets('Student features remain available when admin access is denied', (
    tester,
  ) async {
    final snapshots = StreamController<RoleDocument>(sync: true);
    addTearDown(snapshots.close);
    final router = await _open(tester, snapshots.stream);

    Future<void> expectDenied(String label) async {
      router.go(_admin);
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text(label), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Admin Dashboard'), findsNothing);
    }

    await expectDenied('Checking access…');
    snapshots.add((exists: false, role: null, verified: true));
    await expectDenied('Student');
    snapshots.add((exists: true, role: 'trainer', verified: true));
    await expectDenied('Trainer');
    snapshots.addError(StateError('Lookup denied'));
    await expectDenied('Role unavailable');
  });

  testWidgets(
    'Admin access updates live and is removed on cache or revocation',
    (tester) async {
      final snapshots = StreamController<RoleDocument>(sync: true);
      addTearDown(snapshots.close);
      final router = await _open(tester, snapshots.stream);
      router.go(_profile);
      snapshots.add((exists: true, role: 'admin', verified: true));
      await tester.pumpAndSettle();
      expect(find.text('Administrator'), findsOneWidget);
      final dashboard = find.widgetWithText(OutlinedButton, 'Admin Dashboard');
      expect(dashboard, findsOneWidget);
      await tester.tap(dashboard);
      await tester.pumpAndSettle();
      expect(find.byType(AdminDashboardScreen), findsOneWidget);

      snapshots.add((exists: true, role: 'admin', verified: false));
      await tester.pumpAndSettle();
      expect(find.byType(AdminDashboardScreen), findsNothing);
      expect(find.text('Role unavailable'), findsOneWidget);
      expect(dashboard, findsNothing);

      snapshots.add((exists: true, role: 'admin', verified: true));
      router.go(_admin);
      await tester.pumpAndSettle();
      expect(find.byType(AdminDashboardScreen), findsOneWidget);
      snapshots.add((exists: false, role: null, verified: true));
      await tester.pumpAndSettle();
      expect(find.byType(AdminDashboardScreen), findsNothing);
      expect(find.text('Student'), findsOneWidget);
      expect(dashboard, findsNothing);

      snapshots.add((exists: true, role: 'admin', verified: true));
      await tester.pumpAndSettle();
      expect(dashboard, findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Log Out'));
      await tester.pumpAndSettle();
      router.go(_admin);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(AdminDashboardScreen), findsNothing);
    },
  );
}

import 'package:bjj_app/firebase_options.dart';
import 'package:bjj_app/main.dart' as app;
import 'package:bjj_app/router.dart';
import 'package:bjj_app/screens/admin_dashboard_screen.dart';
import 'package:bjj_app/screens/login_screen.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ColdStartHost implements TestFirebaseCoreHostApi {
  final requested = <({String name, String projectId})>[];

  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [];

  @override
  Future<CoreInitializeResponse> initializeApp(
    String name,
    CoreFirebaseOptions options,
  ) async {
    requested.add((name: name, projectId: options.projectId));
    return CoreInitializeResponse(
      name: name,
      options: options,
      pluginConstants: {},
    );
  }

  @override
  Future<CoreFirebaseOptions> optionsFromResource() async =>
      throw StateError('Startup must supply its selected Firebase options.');
}

void main() {
  testWidgets(
    'Cold startup initializes Firebase before applying the auth gate',
    (tester) async {
      final firebaseHost = _ColdStartHost();
      TestFirebaseCoreHostApi.setUp(firebaseHost);
      addTearDown(() => TestFirebaseCoreHostApi.setUp(null));

      await app.main();
      await tester.pumpAndSettle();
      expect(firebaseHost.requested, [
        (
          name: '[DEFAULT]',
          projectId: DefaultFirebaseOptions.currentPlatform.projectId,
        ),
      ]);
      expect(find.byType(LoginScreen), findsOneWidget);

      appRouter.go('/home/profile/admin');
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(AdminDashboardScreen), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      appRouter.dispose();
    },
  );
}

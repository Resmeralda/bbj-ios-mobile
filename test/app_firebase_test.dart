import 'package:bjj_app/app_firebase.dart';
import 'package:bjj_app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingStartup {
  _RecordingStartup({this.reportedProject, this.failAt});

  final String? reportedProject;
  final String? failAt;
  final failure = StateError('Firebase startup failed');
  final selectedOptions = <FirebaseOptions>[];
  final calls = <String>[];

  FirebaseStartupBindings get bindings => (
    initializeProject: (options) async {
      selectedOptions.add(options);
      calls.add('initialize');
      if (failAt == 'initialize') throw failure;
      return reportedProject ?? options.projectId;
    },
    connectAuth: (host, port) async {
      calls.add('auth $host:$port');
      if (failAt == 'auth') throw failure;
    },
    connectFirestore: (host, port) {
      calls.add('firestore $host:$port');
      if (failAt == 'firestore') throw failure;
    },
  );
}

void main() {
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'Startup honors the compiled emulator flag over caller defaults',
    () async {
      final startup = _RecordingStartup();
      await AppFirebase.initialize(
        useEmulators: false,
        bindings: startup.bindings,
      );
      if (const bool.fromEnvironment('BJJ_FIREBASE_EMULATORS')) {
        expect(startup.selectedOptions.single.projectId, 'demo-bjj-110');
        expect(startup.calls, [
          'initialize',
          'auth 10.0.2.2:19099',
          'firestore 10.0.2.2:18080',
        ]);
      } else {
        expect(startup.selectedOptions, [DefaultFirebaseOptions.android]);
        expect(startup.calls, ['initialize']);
      }
    },
  );

  test(
    'Android debug selects the demo project and both loopback services',
    () async {
      final startup = _RecordingStartup();
      await AppFirebase.initialize(
        useEmulators: true,
        bindings: startup.bindings,
      );
      final options = startup.selectedOptions.single;
      expect(options.projectId, 'demo-bjj-110');
      expect(options.apiKey, 'emulator-only');
      expect(startup.calls, [
        'initialize',
        'auth 10.0.2.2:19099',
        'firestore 10.0.2.2:18080',
      ]);
    },
  );

  test(
    'A demo request never initializes Firebase on an unsupported build',
    () async {
      for (final (platform, debug, web) in [
        (TargetPlatform.android, false, false),
        (TargetPlatform.android, true, true),
        (TargetPlatform.iOS, true, false),
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        final startup = _RecordingStartup();
        await expectLater(
          AppFirebase.initialize(
            useEmulators: true,
            isDebug: debug,
            isWeb: web,
            bindings: startup.bindings,
          ),
          throwsStateError,
        );
        expect(startup.calls, isEmpty);
      }
    },
  );

  test(
    'A returned production project is rejected before either service connects',
    () async {
      final startup = _RecordingStartup(
        reportedProject: DefaultFirebaseOptions.android.projectId,
      );
      await expectLater(
        AppFirebase.initialize(useEmulators: true, bindings: startup.bindings),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('not the demo project'),
          ),
        ),
      );
      expect(startup.selectedOptions.single.projectId, 'demo-bjj-110');
      expect(startup.calls, ['initialize']);
    },
  );

  test(
    'Failed demo initialization or service configuration never falls back',
    () async {
      for (final (stage, expectedCalls) in [
        ('initialize', ['initialize']),
        ('auth', ['initialize', 'auth 10.0.2.2:19099']),
        (
          'firestore',
          ['initialize', 'auth 10.0.2.2:19099', 'firestore 10.0.2.2:18080'],
        ),
      ]) {
        final startup = _RecordingStartup(failAt: stage);
        await expectLater(
          AppFirebase.initialize(
            useEmulators: true,
            bindings: startup.bindings,
          ),
          throwsA(same(startup.failure)),
        );
        expect(startup.selectedOptions.single.projectId, 'demo-bjj-110');
        expect(startup.calls, expectedCalls);
      }
    },
  );
}

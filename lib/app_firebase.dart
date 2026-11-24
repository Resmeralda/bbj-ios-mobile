import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

typedef FirebaseStartupBindings = ({
  Future<String> Function(FirebaseOptions options) initializeProject,
  Future<void> Function(String host, int port) connectAuth,
  void Function(String host, int port) connectFirestore,
});

abstract final class AppFirebase {
  static const _useEmulators = bool.fromEnvironment('BJJ_FIREBASE_EMULATORS');
  static const _project = 'demo-bjj-110';
  static const _androidHost = '10.0.2.2';
  static const _authPort = 19099;
  static const _firestorePort = 18080;

  static const FirebaseStartupBindings _nativeBindings = (
    initializeProject: _initializeProject,
    connectAuth: _connectAuth,
    connectFirestore: _connectFirestore,
  );

  static Future<String> _initializeProject(FirebaseOptions options) async =>
      (await Firebase.initializeApp(options: options)).options.projectId;

  static Future<void> _connectAuth(String host, int port) =>
      FirebaseAuth.instance.useAuthEmulator(host, port);

  static void _connectFirestore(String host, int port) =>
      FirebaseFirestore.instance.useFirestoreEmulator(host, port);

  static Future<void> initialize({
    bool useEmulators = false,
    bool isDebug = true,
    bool isWeb = false,
    FirebaseStartupBindings bindings = _nativeBindings,
  }) async {
    // Callers can request demo mode or add restrictions. The compile-time
    // flag and the actual build environment always take precedence.
    if (!_useEmulators && !useEmulators) {
      await bindings.initializeProject(DefaultFirebaseOptions.currentPlatform);
      return;
    }
    if (!kDebugMode ||
        kIsWeb ||
        !isDebug ||
        isWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      throw StateError(
        'BJJ_FIREBASE_EMULATORS requires an Android debug build.',
      );
    }

    // Firestore's platform delegate expects a default app. Android debug
    // disables native auto-initialization so Dart can select the demo project.
    final projectId = await bindings.initializeProject(
      const FirebaseOptions(
        apiKey: 'emulator-only',
        appId: '1:1:android:1',
        messagingSenderId: '1',
        projectId: _project,
      ),
    );
    if (projectId != _project) {
      throw StateError('The default Firebase app is not the demo project.');
    }
    await bindings.connectAuth(_androidHost, _authPort);
    bindings.connectFirestore(_androidHost, _firestorePort);
    debugPrint(
      'Firebase Emulator Suite: $_project at $_androidHost '
      '(Auth $_authPort, Firestore $_firestorePort)',
    );
  }
}

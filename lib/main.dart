import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import 'app_firebase.dart';
import 'data/role_store.dart';
import 'data/stores.dart';
import 'profile_store.dart';
import 'router.dart';
import 'session_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppFirebase.initialize();

  bindAuthStores(
    FirebaseAuth.instance,
    roles: roleStore,
    bindPersonalData: (user) {
      sessionStore.bind(user?.uid);
      bindUserData(user?.uid);
      profileStore.bind(user?.uid, authName: user?.displayName);
    },
  );

  runApp(const BjjFitnessApp());
}

/// Binds the stores on startup and whenever the authenticated account changes.
StreamSubscription<User?> bindAuthStores(
  FirebaseAuth auth, {
  required RoleStore roles,
  required void Function(User? user) bindPersonalData,
}) {
  String? lastUid;
  void syncStores(User? user) {
    if (user?.uid == lastUid) return;

    lastUid = user?.uid;
    roles.bind(user?.uid);
    bindPersonalData(user);
  }

  syncStores(auth.currentUser);
  return auth.authStateChanges().listen(syncStores);
}

class BjjFitnessApp extends StatelessWidget {
  const BjjFitnessApp({super.key, this.router});

  final GoRouter? router;

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'BJJ Fitness',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    routerConfig: router ?? appRouter,
  );
}

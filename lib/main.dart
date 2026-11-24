import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';

import 'firebase_options.dart';
import 'data/stores.dart';
import 'profile_store.dart';
import 'router.dart';
import 'session_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Bind each store to the signed-in user.
  String? lastUid;
  void syncStores(User? user) {
    if (user?.uid == lastUid) return;

    lastUid = user?.uid;
    sessionStore.bind(user?.uid);
    bindUserData(user?.uid);
    profileStore.bind(user?.uid, authName: user?.displayName);
  }

  syncStores(FirebaseAuth.instance.currentUser);
  FirebaseAuth.instance.authStateChanges().listen(syncStores);

  runApp(const BjjFitnessApp());
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

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'profile_store.dart';
import 'router.dart';
import 'session_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Reset in-memory stores whenever the signed-in user changes, and seed
  // the profile name from the Firebase display name.
  String? lastUid;
  void syncStores(User? user) {
    if (user?.uid == lastUid) return;
    lastUid = user?.uid;
    sessionStore.bind(user?.uid);
    profileStore.reset(name: user?.displayName);
  }

  syncStores(FirebaseAuth.instance.currentUser);
  FirebaseAuth.instance.authStateChanges().listen(syncStores);

  runApp(const BjjFitnessApp());
}

class BjjFitnessApp extends StatelessWidget {
  const BjjFitnessApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'BJJ Fitness',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    routerConfig: appRouter,
  );
}

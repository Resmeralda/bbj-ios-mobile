import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'router.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
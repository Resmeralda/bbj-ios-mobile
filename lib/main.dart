import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

// TODO: when Firebase is added:
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
void main() => runApp(const BjjFitnessApp());

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

import 'package:flutter/material.dart';

class AppColors {
  static const home = Color(0xFF1F4E8C);
  static const training = Color(0xFF2A5698);
  static const techniques = Color(0xFF8B3A3A);
  static const nutrition = Color(0xFF57855F);
  static const recovery = Color(0xFF5E5A94);
  static const background = Color(0xFFF6F8FC);
  static const ink = Color(0xFF0F1B33);
  static const muted = Color(0xFF6B778C);
  static const tint = Color(0xFFE6F0FD);
}

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: AppColors.home),
  scaffoldBackgroundColor: AppColors.background,
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: Colors.transparent,
  ),
);

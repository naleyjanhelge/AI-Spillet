import 'package:flutter/material.dart';

abstract final class AppColors {
  static const voidBlack = Color(0xFF070611);
  static const deepSpace = Color(0xFF0F0C20);
  static const surface = Color(0xFF17132A);
  static const surfaceHigh = Color(0xFF211B39);
  static const ultraviolet = Color(0xFF9B6CFF);
  static const cyan = Color(0xFF4DDCFF);
  static const text = Color(0xFFF5F1FF);
  static const textMuted = Color(0xFFA69DBD);
  static const success = Color(0xFF46E6B0);
  static const danger = Color(0xFFFF5D91);
}

ThemeData buildPromptHeistTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.voidBlack,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.ultraviolet,
      secondary: AppColors.cyan,
      surface: AppColors.surface,
      error: AppColors.danger,
    ),
    textTheme: base.textTheme
        .apply(
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
          fontFamily: 'Avenir Next',
        )
        .copyWith(
          displayLarge: const TextStyle(
            fontSize: 48,
            height: .9,
            fontWeight: FontWeight.w900,
            letterSpacing: -2.2,
          ),
          headlineLarge: const TextStyle(
            fontSize: 30,
            height: 1.05,
            fontWeight: FontWeight.w800,
            letterSpacing: -.9,
          ),
          headlineMedium: const TextStyle(
            fontSize: 22,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -.4,
          ),
          titleMedium: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: const TextStyle(fontSize: 16, height: 1.45),
          bodyMedium: const TextStyle(fontSize: 14, height: 1.45),
          labelLarge: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: const TextStyle(color: AppColors.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceHigh.withValues(alpha: .92),
      hintStyle: const TextStyle(color: AppColors.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: .08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.cyan, width: 1.5),
      ),
    ),
  );
}

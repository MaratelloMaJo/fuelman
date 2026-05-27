import 'package:flutter/material.dart';

/// Цветовая схема приложения FuelMan.
///
/// Используется Material 3 с seed-цветом teal для
/// профессионального, чистого вида.
abstract final class AppTheme {
  // Seed-цвет палитры — насыщенный тёмно-бирюзовый.
  static const Color _seed = Color(0xFF00838F);

  // Дополнительные цвета для визуализации эффективности.
  static const Color efficiencyGood = Color(0xFF43A047);   // зелёный
  static const Color efficiencyMid = Color(0xFFFB8C00);    // янтарный
  static const Color efficiencyBad = Color(0xFFE53935);    // красный

  // Цвет для графиков
  static const Color chartPrimary = Color(0xFF26C6DA);
  static const Color chartSecondary = Color(0xFF80DEEA);

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.light,
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          filled: true,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          filled: true,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );
}

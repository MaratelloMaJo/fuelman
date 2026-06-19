import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Цветовая схема приложения FuelMan.
///
/// Тёмная тема — насыщенная тёмно-бирюзовая (как раньше).
/// Светлая тема — тёплые профессиональные цвета нефтяной/топливной индустрии.
abstract final class AppTheme {
  // ── Тёмная тема — seed ──
  static const Color _darkSeed = Color(0xFF00838F);

  // ── Светлая тема — тёплый янтарно-медный seed ──
  static const Color _lightSeed = Color(0xFFE65C00); // глубокий оранжевый

  // Дополнительные цвета для визуализации эффективности.
  static const Color efficiencyGood = Color(0xFF2E7D32); // тёмно-зелёный
  static const Color efficiencyMid = Color(0xFFF57C00);  // янтарный
  static const Color efficiencyBad = Color(0xFFC62828);  // тёмно-красный

  // Цвет для графиков
  static const Color chartPrimary = Color(0xFF26C6DA);
  static const Color chartSecondary = Color(0xFF80DEEA);

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _lightSeed,
          brightness: Brightness.light,
          // Тёплые оттенки для светлой темы — профессиональный топливный стиль
          primary: const Color(0xFFBF360C),       // глубокий оранжево-красный
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFFFCCBC),
          onPrimaryContainer: const Color(0xFF7B1A00),
          secondary: const Color(0xFF795548),     // коричневый
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFD7CCC8),
          onSecondaryContainer: const Color(0xFF3E2723),
          tertiary: const Color(0xFF00695C),      // изумрудный акцент
          onTertiary: Colors.white,
          tertiaryContainer: const Color(0xFFB2DFDB),
          onTertiaryContainer: const Color(0xFF00352C),
          surface: const Color(0xFFFAF8F5),       // тёплый белый
          onSurface: const Color(0xFF1C1A17),
          surfaceContainerHighest: const Color(0xFFEDE9E3),
          surfaceContainerHigh: const Color(0xFFF3EFE9),
          surfaceContainer: const Color(0xFFF7F4EF),
          outline: const Color(0xFF9E8F84),
          outlineVariant: const Color(0xFFD6CFC8),
          error: const Color(0xFFBA1A1A),
          onError: Colors.white,
          errorContainer: const Color(0xFFFFDAD6),
          onErrorContainer: const Color(0xFF410002),
          shadow: const Color(0xFF000000),
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarBrightness: Brightness.light,
            statusBarIconBrightness: Brightness.dark,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          elevation: 0,
          backgroundColor: Colors.transparent,
          indicatorColor: const Color(0xFFBF360C).withAlpha(20),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFFFFFFFF),
          shadowColor: const Color(0xFFBF360C).withAlpha(20),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          filled: true,
          fillColor: const Color(0xFFF7F4EF),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFBF360C),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFEDE9E3),
          selectedColor: const Color(0xFFBF360C).withAlpha(30),
          labelStyle: const TextStyle(color: Color(0xFF1C1A17)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFEDE9E3),
        ),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _darkSeed,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarBrightness: Brightness.dark,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          elevation: 0,
          backgroundColor: Colors.transparent,
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

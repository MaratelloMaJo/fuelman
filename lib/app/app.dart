import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import '../controllers/car_expense_controller.dart';
import '../controllers/fuel_entry_controller.dart';
import '../controllers/theme_controller.dart';
import '../controllers/vehicle_controller.dart';
import '../controllers/settings_controller.dart';
import '../l10n/app_translations.dart';
import '../screens/main_screen.dart';
import '../theme/app_theme.dart';

/// Корень приложения.
///
/// Инициализирует GetX-контроллеры через [Get.put] (lazy=false),
/// настраивает Material 3 тему, переводы и реагирует на переключение темы.
class FuelManApp extends StatelessWidget {
  const FuelManApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Регистрируем контроллеры в дереве зависимостей.
    // VehicleController регистрируется первым, т.к. FuelEntryController зависит от него.
    Get.put(ThemeController(), permanent: true);
    Get.put(SettingsController(), permanent: true);
    Get.put(VehicleController(), permanent: true);
    Get.put(FuelEntryController(), permanent: true);
    Get.put(CarExpenseController(), permanent: true);

    final themeCtrl = Get.find<ThemeController>();
    final settingsCtrl = Get.find<SettingsController>();

    return Obx(() {
      final langCode = settingsCtrl.language.value;
      // Map to full locale to match translation keys (ru_RU, en_US, kk_KZ)
      final localeMap = <String, Locale>{
        'ru': const Locale('ru', 'RU'),
        'en': const Locale('en', 'US'),
        'kk': const Locale('kk', 'KZ'),
      };
      final locale = localeMap[langCode] ?? Locale(langCode);

      return GetMaterialApp(
          title: 'FuelMan',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeCtrl.themeMode,

          // Локализация
          translations: AppTranslations(),
          locale: locale,
          fallbackLocale: const Locale('ru', 'RU'),
          supportedLocales: const [
            Locale('ru', 'RU'),
            Locale('en', 'US'),
            Locale('kk', 'KZ'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          home: const MainScreen(),
        );
    });
  }
}

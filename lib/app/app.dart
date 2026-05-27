import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/fuel_entry_controller.dart';
import '../controllers/theme_controller.dart';
import '../controllers/vehicle_controller.dart';
import '../screens/main_screen.dart';
import '../theme/app_theme.dart';

/// Корень приложения.
///
/// Инициализирует GetX-контроллеры через [Get.put] (lazy=false),
/// настраивает Material 3 тему и реагирует на переключение темы.
class FuelManApp extends StatelessWidget {
  const FuelManApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Регистрируем контроллеры в дереве зависимостей.
    // VehicleController регистрируется первым, т.к. FuelEntryController зависит от него.
    Get.put(ThemeController(), permanent: true);
    Get.put(VehicleController(), permanent: true);
    Get.put(FuelEntryController(), permanent: true);

    final themeCtrl = Get.find<ThemeController>();

    return Obx(() => GetMaterialApp(
          title: 'FuelMan',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeCtrl.themeMode,
          locale: const Locale('ru', 'RU'),
          home: const MainScreen(),
        ));
  }
}

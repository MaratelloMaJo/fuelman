import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'database/fuel_database.dart';
import 'services/notification_service.dart';

/// Точка входа в FuelMan.
///
/// Выполняет асинхронную инициализацию:
///   1. Flutter binding (необходимо для асинхронного запуска)
///   2. Локализацию дат (intl)
///   3. Базу данных SQLite (для прогрева соединения)
///   4. Сервис уведомлений (необязательный, для напоминаний)
///   5. Ориентацию экрана (только портретная)
///   6. Прозрачный статус-бар и навигационная панель
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация локализации intl (DateFormat для 'ru').
  await initializeDateFormatting('ru', null);

  // Прогрев базы данных (инициализация соединения).
  await FuelDatabase.instance.database;

  // Сервис уведомлений.
  await NotificationService.instance.init();

  // Блокировка ориентации экрана.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Настройка прозрачности статус-бара и навигационной панели.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  runApp(const FuelManApp());
}

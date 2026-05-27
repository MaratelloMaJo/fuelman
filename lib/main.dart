import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'database/fuel_database.dart';
import 'services/notification_service.dart';
import 'services/currency_service.dart';

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

  // Безопасно инициализируем все службы
  await _initServices();

  runApp(const FuelManApp());
}

/// Выполняет асинхронную инициализацию служб приложения.
/// Все ошибки перехватываются, чтобы гарантировать успешную загрузку UI.
Future<void> _initServices() async {
  try {
    // 1. Инициализация локализации дат (intl)
    await initializeDateFormatting('ru', null);
    await initializeDateFormatting('en', null);
    await initializeDateFormatting('kk', null);
  } catch (e, stack) {
    debugPrint('Ошибка инициализации локализации: $e\n$stack');
  }

  try {
    // 2. Прогрев базы данных SQLite
    await FuelDatabase.instance.database;
  } catch (e, stack) {
    debugPrint('Ошибка инициализации базы данных: $e\n$stack');
  }

  try {
    // 3. Сервис напоминаний о заправках
    await NotificationService.instance.init();
  } catch (e, stack) {
    debugPrint('Ошибка инициализации сервиса уведомлений: $e\n$stack');
  }

  try {
    // 4. Сервис валютных курсов
    await CurrencyService.instance.init();
  } catch (e, stack) {
    debugPrint('Ошибка инициализации валютного сервиса: $e\n$stack');
  }

  try {
    // 5. Фиксация портретной ориентации
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (e, stack) {
    debugPrint('Ошибка настройки ориентации: $e\n$stack');
  }

  try {
    // 6. Настройка статус-бара и панели навигации
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );
  } catch (e, stack) {
    debugPrint('Ошибка настройки стилей системы: $e\n$stack');
  }
}

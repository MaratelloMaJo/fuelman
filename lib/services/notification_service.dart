import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Сервис необязательных уведомлений-напоминаний о заправке.
///
/// Уведомления показываются только если:
///   1. Пользователь явно включил напоминание для автомобиля (reminderDays != null).
///   2. Количество дней с последней записи >= reminderDays.
///
/// Уведомления НЕ планируются заранее — проверка происходит при каждом
/// открытии приложения, что корректно работает для непостоянного режима езды.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Инициализация плагина. Вызывается один раз в main().
  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      // Запрашиваем разрешения явно через [requestPermission()],
      // а не при инициализации, чтобы не спрашивать сразу после установки.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
    _initialized = true;
  }

  /// Запрашивает разрешение у пользователя (только при первом включении напоминаний).
  /// Возвращает true если разрешение получено.
  Future<bool> requestPermission() async {
    // Android 13+
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      return await androidImpl.requestNotificationsPermission() ?? false;
    }

    // iOS
    final iosImpl = _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      return await iosImpl.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return true; // На других платформах разрешение не нужно
  }

  /// Показывает уведомление-напоминание для конкретного автомобиля.
  ///
  /// [notificationId] — уникальный ID (используем vehicleId).
  /// [vehicleName] — имя автомобиля для отображения.
  /// [daysSinceLastEntry] — сколько дней прошло с последней записи.
  Future<void> showFuelReminder({
    required int notificationId,
    required String vehicleName,
    required int daysSinceLastEntry,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'fuel_reminders',
      'Напоминания о заправке',
      channelDescription: 'Напоминает записать данные о заправке топлива',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false, // без звука — не навязчиво
    );

    await _plugin.show(
      id: notificationId,
      title: '⛽ Пора записать заправку?',
      body: '$vehicleName — последняя запись $daysSinceLastEntry дн. назад',
      notificationDetails:
          const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  /// Отменяет уведомление для конкретного автомобиля.
  Future<void> cancel(int notificationId) async {
    await _plugin.cancel(id: notificationId);
  }

  /// Отменяет все уведомления.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}

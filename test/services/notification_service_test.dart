import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fuelman/services/notification_service.dart';

class MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

class MockAndroidFlutterLocalNotificationsPlugin extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

class MockIOSFlutterLocalNotificationsPlugin extends Mock
    implements IOSFlutterLocalNotificationsPlugin {}

void main() {
  late NotificationService notificationService;
  late MockFlutterLocalNotificationsPlugin mockPlugin;

  setUpAll(() {
    registerFallbackValue(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    registerFallbackValue(
      const NotificationDetails(),
    );
  });

  setUp(() {
    mockPlugin = MockFlutterLocalNotificationsPlugin();
    notificationService = NotificationService(plugin: mockPlugin);
    NotificationService.setMockInstance(notificationService);
  });

  tearDown(() {
    NotificationService.setMockInstance(null);
  });

  group('NotificationService', () {
    test('init calls initialize on plugin', () async {
      when(() => mockPlugin.initialize(
            settings: any(named: 'settings'),
            onDidReceiveNotificationResponse:
                any(named: 'onDidReceiveNotificationResponse'),
            onDidReceiveBackgroundNotificationResponse:
                any(named: 'onDidReceiveBackgroundNotificationResponse'),
          )).thenAnswer((_) async => true);

      await notificationService.init();

      verify(() => mockPlugin.initialize(
            settings: any(named: 'settings'),
            onDidReceiveNotificationResponse:
                any(named: 'onDidReceiveNotificationResponse'),
            onDidReceiveBackgroundNotificationResponse:
                any(named: 'onDidReceiveBackgroundNotificationResponse'),
          )).called(1);
    });

    test('init does not call initialize twice', () async {
      when(() => mockPlugin.initialize(
            settings: any(named: 'settings'),
            onDidReceiveNotificationResponse:
                any(named: 'onDidReceiveNotificationResponse'),
            onDidReceiveBackgroundNotificationResponse:
                any(named: 'onDidReceiveBackgroundNotificationResponse'),
          )).thenAnswer((_) async => true);

      await notificationService.init();
      await notificationService.init();

      verify(() => mockPlugin.initialize(
            settings: any(named: 'settings'),
            onDidReceiveNotificationResponse:
                any(named: 'onDidReceiveNotificationResponse'),
            onDidReceiveBackgroundNotificationResponse:
                any(named: 'onDidReceiveBackgroundNotificationResponse'),
          )).called(1);
    });

    test('requestPermission on Android calls requestNotificationsPermission', () async {
      final androidMock = MockAndroidFlutterLocalNotificationsPlugin();
      when(() => mockPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>())
          .thenReturn(androidMock);
      when(() => androidMock.requestNotificationsPermission())
          .thenAnswer((_) async => true);

      final result = await notificationService.requestPermission();

      expect(result, isTrue);
      verify(() => mockPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()).called(1);
      verify(() => androidMock.requestNotificationsPermission()).called(1);
    });

    test('requestPermission on iOS calls requestPermissions', () async {
      when(() => mockPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>())
          .thenReturn(null);

      final iosMock = MockIOSFlutterLocalNotificationsPlugin();
      when(() => mockPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>())
          .thenReturn(iosMock);
      when(() => iosMock.requestPermissions(
            alert: any(named: 'alert'),
            badge: any(named: 'badge'),
            sound: any(named: 'sound'),
          )).thenAnswer((_) async => true);

      final result = await notificationService.requestPermission();

      expect(result, isTrue);
      verify(() => mockPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()).called(1);
      verify(() => mockPlugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()).called(1);
      verify(() => iosMock.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          )).called(1);
    });

    test('requestPermission on other platforms returns true', () async {
      when(() => mockPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>())
          .thenReturn(null);
      when(() => mockPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>())
          .thenReturn(null);

      final result = await notificationService.requestPermission();

      expect(result, isTrue);
      verify(() => mockPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()).called(1);
      verify(() => mockPlugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()).called(1);
    });

    test('showFuelReminder calls show on plugin', () async {
      when(() => mockPlugin.show(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            notificationDetails: any(named: 'notificationDetails'),
            payload: any(named: 'payload'),
          )).thenAnswer((_) async {});

      await notificationService.showFuelReminder(
        notificationId: 1,
        vehicleName: 'Test Vehicle',
        daysSinceLastEntry: 5,
      );

      verify(() => mockPlugin.show(
            id: 1,
            title: '⛽ Пора записать заправку?',
            body: 'Test Vehicle — последняя запись 5 дн. назад',
            notificationDetails: any(named: 'notificationDetails'),
            payload: any(named: 'payload'),
          )).called(1);
    });

    test('cancel calls cancel on plugin', () async {
      when(() => mockPlugin.cancel(id: any(named: 'id'))).thenAnswer((_) async {});

      await notificationService.cancel(1);

      verify(() => mockPlugin.cancel(id: 1)).called(1);
    });

    test('cancelAll calls cancelAll on plugin', () async {
      when(() => mockPlugin.cancelAll()).thenAnswer((_) async {});

      await notificationService.cancelAll();

      verify(() => mockPlugin.cancelAll()).called(1);
    });
  });
}

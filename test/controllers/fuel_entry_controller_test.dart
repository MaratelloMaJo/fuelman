import 'package:flutter_test/flutter_test.dart';
import 'package:fuelman/controllers/fuel_entry_controller.dart';
import 'package:fuelman/controllers/settings_controller.dart';
import 'package:fuelman/controllers/vehicle_controller.dart';
import 'package:fuelman/database/fuel_database.dart';
import 'package:fuelman/models/fuel_entry.dart';
import 'package:fuelman/models/vehicle.dart';
import 'package:fuelman/services/notification_service.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class MockDatabase extends Mock implements Database {}
class MockNotificationService extends Mock implements NotificationService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDatabase mockDb;
  late MockNotificationService mockNotifications;
  late VehicleController vehicleController;
  late SettingsController settingsController;

  const vehicleWithReminder = Vehicle(
    id: 1,
    name: 'Skoda Octavia',
    model: 'Octavia',
    bodyType: 'sedan',
    engineType: 'gas',
    reminderDays: 7,
  );

  const vehicleWithoutReminder = Vehicle(
    id: 2,
    name: 'Nissan Leaf',
    model: 'Leaf',
    bodyType: 'hatchback',
    engineType: 'electric',
    reminderDays: null,
  );

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({
      'currency': 'RUB',
      'volume_unit': 'L',
    });

    mockDb = MockDatabase();
    FuelDatabase.setMockDatabase(mockDb);

    mockNotifications = MockNotificationService();
    NotificationService.setMockInstance(mockNotifications);

    when(() => mockDb.query('vehicles', orderBy: any(named: 'orderBy')))
        .thenAnswer((_) async => [
              vehicleWithReminder.toMap(),
              vehicleWithoutReminder.toMap(),
            ]);

    settingsController = SettingsController();
    Get.put<SettingsController>(settingsController);

    vehicleController = VehicleController();
    Get.put<VehicleController>(vehicleController);
    await Future.delayed(const Duration(milliseconds: 50));

    when(() => mockDb.query(
          'fuel_entries',
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
          orderBy: any(named: 'orderBy'),
        )).thenAnswer((_) async => []);

    when(() => mockDb.query(
          'charging_entries',
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
          orderBy: any(named: 'orderBy'),
        )).thenAnswer((_) async => []);

    when(() => mockDb.rawQuery(any(), any()))
        .thenAnswer((_) async => []);
  });

  tearDown(() {
    Get.reset();
    FuelDatabase.setMockDatabase(null);
    NotificationService.setMockInstance(null);
  });

  group('FuelEntryController Core Tests', () {
    test('Loads entries and detects anomalous consumption on vehicle selection', () async {
      final mockData = [
        {
          'id': 101,
          'vehicle_id': 1,
          'date': '2025-01-01T10:00:00.000',
          'odometer': 50000.0,
          'volume': 45.0,
          'price_per_liter': 55.0,
          'total_cost': 2475.0,
          'is_full_tank': 1,
          'entry_type': 'fuel',
          'volume_unit': 'L',
          'currency': 'RUB',
          'consumption': 8.5,
        },
        {
          'id': 102,
          'vehicle_id': 1,
          'date': '2025-01-10T10:00:00.000',
          'odometer': 50100.0,
          'volume': 40.0,
          'price_per_liter': 55.0,
          'total_cost': 2200.0,
          'is_full_tank': 1,
          'entry_type': 'fuel',
          'volume_unit': 'L',
          'currency': 'RUB',
          'consumption': 60.0, // Anomalous (> 50 L/100km)
        }
      ];

      when(() => mockDb.query(
            'fuel_entries',
            where: any(named: 'where'),
            whereArgs: [1],
            orderBy: 'date ASC',
          )).thenAnswer((_) async => mockData);

      final controller = FuelEntryController();
      Get.put<FuelEntryController>(controller);

      await controller.loadEntries(1);

      expect(controller.entries.length, 2);
      expect(controller.entries.first.id, 101);
      expect(controller.isEntryAnomalous(101), isFalse);
      expect(controller.isEntryAnomalous(102), isTrue);
    });

    test('isAnomalousConsumption verifies bounds for fuel and electric entries', () {
      final controller = FuelEntryController();
      Get.put<FuelEntryController>(controller);

      // Fuel: reasonable is between 1.0 and 50.0
      expect(controller.isAnomalousConsumption(7.5, 'fuel'), isFalse);
      expect(controller.isAnomalousConsumption(0.5, 'fuel'), isTrue);
      expect(controller.isAnomalousConsumption(55.0, 'fuel'), isTrue);

      // EV: reasonable is between 4.0 and 80.0
      expect(controller.isAnomalousConsumption(18.0, 'charge'), isFalse);
      expect(controller.isAnomalousConsumption(2.0, 'charge'), isTrue);
      expect(controller.isAnomalousConsumption(90.0, 'charge'), isTrue);
    });

    test('checkAnomaly identifies volume limits for vehicles', () {
      // Normal volume
      final normal = FuelEntryController.checkAnomalyWarning(
        entryType: 'fuel',
        volume: 40.0,
        odometer: 1000.0,
        prevOdometer: null,
        vehicle: vehicleWithReminder,
      );
      expect(normal, isNull);

      // Volume exceeds maximum reasonable tank limit (> 250L)
      final tooLarge = FuelEntryController.checkAnomalyWarning(
        entryType: 'fuel',
        volume: 300.0,
        odometer: 1000.0,
        prevOdometer: null,
        vehicle: vehicleWithReminder,
      );
      expect(tooLarge, equals(AnomalyWarning.volumeTooLarge));
    });
  });

  group('FuelEntryController checkAllReminders (Issue 11)', () {
    test('schedules reminder notification when days >= reminderDays', () async {
      vehicleController.vehicles.assignAll([vehicleWithReminder]);
      final controller = FuelEntryController();
      Get.put<FuelEntryController>(controller);

      // Last entry was 10 days ago (reminder threshold is 7 days)
      final tenDaysAgo = DateTime.now().subtract(const Duration(days: 10));

      when(() => mockDb.rawQuery(any(), [1])).thenAnswer((_) async => [
            {'last_date': tenDaysAgo.toIso8601String()}
          ]);

      when(() => mockNotifications.showFuelReminder(
            notificationId: any(named: 'notificationId'),
            vehicleName: any(named: 'vehicleName'),
            daysSinceLastEntry: any(named: 'daysSinceLastEntry'),
          )).thenAnswer((_) async {});

      await controller.checkAllReminders();

      verify(() => mockNotifications.showFuelReminder(
            notificationId: 1,
            vehicleName: 'Skoda Octavia',
            daysSinceLastEntry: any(that: greaterThanOrEqualTo(9), named: 'daysSinceLastEntry'),
          )).called(1);

      verifyNever(() => mockNotifications.cancel(1));
    });

    test('cancels reminder notification when days < reminderDays', () async {
      vehicleController.vehicles.assignAll([vehicleWithReminder]);
      final controller = FuelEntryController();
      Get.put<FuelEntryController>(controller);

      // Last entry was 2 days ago (reminder threshold is 7 days)
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));

      when(() => mockDb.rawQuery(any(), [1])).thenAnswer((_) async => [
            {'last_date': twoDaysAgo.toIso8601String()}
          ]);

      when(() => mockNotifications.cancel(any()))
          .thenAnswer((_) async {});

      await controller.checkAllReminders();

      verify(() => mockNotifications.cancel(1)).called(1);
      verifyNever(() => mockNotifications.showFuelReminder(
            notificationId: any(named: 'notificationId'),
            vehicleName: any(named: 'vehicleName'),
            daysSinceLastEntry: any(named: 'daysSinceLastEntry'),
          ));
    });

    test('does nothing for vehicle without reminderDays set', () async {
      vehicleController.vehicles.assignAll([vehicleWithoutReminder]);
      final controller = FuelEntryController();
      Get.put<FuelEntryController>(controller);

      await controller.checkAllReminders();

      verifyNever(() => mockNotifications.showFuelReminder(
            notificationId: any(named: 'notificationId'),
            vehicleName: any(named: 'vehicleName'),
            daysSinceLastEntry: any(named: 'daysSinceLastEntry'),
          ));
      verifyNever(() => mockNotifications.cancel(any()));
    });
  });

  group('Concurrency / State Race Conditions', () {
    test('addEntry ignores state reload if active vehicle changes during DB insert', () async {
      vehicleController.vehicles.assignAll([vehicleWithReminder, vehicleWithoutReminder]);
      vehicleController.selectedVehicle.value = vehicleWithReminder;

      final controller = FuelEntryController();
      Get.put<FuelEntryController>(controller);

      when(() => mockDb.rawQuery('SELECT COUNT(*) FROM fuel_entries')).thenAnswer((_) async => [{'COUNT(*)': 1}]);
      when(() => mockDb.insert('fuel_entries', any())).thenAnswer((_) async {
        // Simulate user clicking on a different vehicle while insert is in flight
        vehicleController.selectedVehicle.value = vehicleWithoutReminder;
        return 10;
      });

      final entry = FuelEntry(
        vehicleId: 1, // For the first vehicle
        date: DateTime.now(),
        odometer: 1000,
        volume: 40,
        isFullTank: true,
        entryType: 'fuel'
      );

      // Allow internal setup queries to complete before executing addEntry
      await Future.delayed(const Duration(milliseconds: 50));

      // clear mock invocations before the action to avoid false positives from initialization
      clearInteractions(mockDb);

      await controller.addEntry(entry);

      // Because selectedVehicle changed to vehicle 2 during insert, it should NOT reload entries for vehicle 1.
      // Note: the controller's internal _onVehicleChanged will have triggered a loadEntries(2), but
      // the addEntry itself should not call loadEntries(1).
      verifyNever(() => mockDb.query('fuel_entries', where: 'vehicle_id = ?', whereArgs: [1], orderBy: any(named: 'orderBy')));
    });
  });
}

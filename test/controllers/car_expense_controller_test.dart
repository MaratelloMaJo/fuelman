import 'package:flutter_test/flutter_test.dart';
import 'package:fuelman/controllers/car_expense_controller.dart';
import 'package:fuelman/controllers/settings_controller.dart';
import 'package:fuelman/controllers/vehicle_controller.dart';
import 'package:fuelman/database/fuel_database.dart';
import 'package:fuelman/models/car_expense.dart';
import 'package:fuelman/models/vehicle.dart';
import 'package:fuelman/services/currency_service.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class MockDatabase extends Mock implements Database {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDatabase mockDb;
  late VehicleController vehicleController;
  late SettingsController settingsController;

  const testVehicle = Vehicle(
    id: 1,
    name: 'Test Car',
    model: 'Model S',
    bodyType: 'sedan',
    engineType: 'electric',
  );

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({
      'currency': 'USD',
    });

    mockDb = MockDatabase();
    FuelDatabase.setMockDatabase(mockDb);

    when(() => mockDb.query(
          'vehicles',
          orderBy: any(named: 'orderBy'),
        )).thenAnswer((_) async => []);

    settingsController = SettingsController();
    Get.put<SettingsController>(settingsController);

    vehicleController = VehicleController();
    Get.put<VehicleController>(vehicleController);

    // Default mock response for car_expenses query
    when(() => mockDb.query(
          'car_expenses',
          where: any(named: 'where'),
          whereArgs: any(named: 'whereArgs'),
          orderBy: any(named: 'orderBy'),
        )).thenAnswer((_) async => []);

    // Set static rates on CurrencyService
    CurrencyService.instance.rates = {
      'USD': 1.0,
      'EUR': 0.9,
      'RUB': 90.0,
    };
  });

  tearDown(() {
    Get.reset();
    FuelDatabase.setMockDatabase(null);
  });

  group('CarExpenseController Tests', () {
    test('Initializes with empty list when no vehicle is selected', () {
      final controller = Get.put(CarExpenseController());
      expect(controller.expenses, isEmpty);
      expect(controller.expenseStats, isEmpty);
    });

    test('Loads expenses and calculates stats when vehicle is selected',
        () async {
      final expenseMap = {
        'id': 10,
        'vehicle_id': 1,
        'category': 'wash',
        'title': 'Car Wash',
        'amount': 900.0,
        'currency': 'RUB',
        'date': '2025-01-01T12:00:00.000',
        'odometer': 12000.0,
        'note': 'Clean',
      };

      when(() => mockDb.query(
            'car_expenses',
            where: any(named: 'where'),
            whereArgs: [1],
            orderBy: any(named: 'orderBy'),
          )).thenAnswer((_) async => [expenseMap]);

      final controller = Get.put(CarExpenseController());

      // Trigger vehicle change
      vehicleController.selectedVehicle.value = testVehicle;
      await Future.delayed(const Duration(milliseconds: 50));

      expect(controller.expenses.length, 1);
      expect(controller.expenses.first.id, 10);
      expect(controller.expenses.first.title, 'Car Wash');

      // 900 RUB in USD (rate 90) = 10 USD
      expect(controller.expenseStats['wash'], closeTo(10.0, 0.001));
    });

    test('addExpense inserts into db and reloads expenses', () async {
      final controller = Get.put(CarExpenseController());
      vehicleController.selectedVehicle.value = testVehicle;

      when(() => mockDb.insert('car_expenses', any()))
          .thenAnswer((_) async => 101);

      when(() => mockDb.query(
            'car_expenses',
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
            orderBy: any(named: 'orderBy'),
          )).thenAnswer((_) async => [
            {
              'id': 101,
              'vehicle_id': 1,
              'category': 'repair',
              'title': 'Brake replacement',
              'amount': 50.0,
              'currency': 'USD',
              'date': '2025-02-01T10:00:00.000',
            }
          ]);

      final newExpense = CarExpense(
        vehicleId: 1,
        category: 'repair',
        title: 'Brake replacement',
        amount: 50.0,
        currency: 'USD',
        date: DateTime.parse('2025-02-01T10:00:00.000'),
      );

      await controller.addExpense(newExpense);

      verify(() => mockDb.insert('car_expenses', any())).called(1);
      expect(controller.expenses.length, 1);
      expect(controller.expenses.first.id, 101);
    });

    test('updateExpense updates db and reloads expenses', () async {
      final controller = Get.put(CarExpenseController());
      vehicleController.selectedVehicle.value = testVehicle;

      when(() => mockDb.update(
            'car_expenses',
            any(),
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
          )).thenAnswer((_) async => 1);

      final updatedExpense = CarExpense(
        id: 101,
        vehicleId: 1,
        category: 'repair',
        title: 'Brake replacement v2',
        amount: 60.0,
        currency: 'USD',
        date: DateTime.parse('2025-02-01T10:00:00.000'),
      );

      await controller.updateExpense(updatedExpense);

      verify(() => mockDb.update(
            'car_expenses',
            any(),
            where: 'id = ?',
            whereArgs: [101],
          )).called(1);
    });

    test('deleteExpense removes expense from state and db', () async {
      final controller = Get.put(CarExpenseController());
      vehicleController.selectedVehicle.value = testVehicle;

      final expense = CarExpense(
        id: 200,
        vehicleId: 1,
        category: 'parking',
        title: 'Parking',
        amount: 15.0,
        currency: 'USD',
        date: DateTime.parse('2025-02-05T10:00:00.000'),
      );
      controller.expenses.add(expense);

      when(() => mockDb.delete(
            'car_expenses',
            where: any(named: 'where'),
            whereArgs: [200],
          )).thenAnswer((_) async => 1);

      when(() => mockDb.query(
            'car_expenses',
            where: any(named: 'where'),
            whereArgs: [1],
            orderBy: any(named: 'orderBy'),
          )).thenAnswer((_) async => []);

      await controller.deleteExpense(200);

      expect(controller.expenses.where((e) => e.id == 200), isEmpty);
      verify(() => mockDb.delete(
            'car_expenses',
            where: 'id = ?',
            whereArgs: [200],
          )).called(1);
    });

    test('getMonthlyExpenses delegates to FuelDatabase', () async {
      final controller = Get.put(CarExpenseController());

      final mockMonthly = [
        {'month': '2025-01', 'total_amount': 150.0, 'total_count': 3},
      ];
      when(() => mockDb.rawQuery(any(), [1]))
          .thenAnswer((_) async => mockMonthly);

      final result = await controller.getMonthlyExpenses(1);
      expect(result, equals(mockMonthly));
    });

    test(
        'addExpense ignores state reload if active vehicle changes during DB insert',
        () async {
      final controller = Get.put(CarExpenseController());
      vehicleController.selectedVehicle.value = testVehicle;

      // Allow internal setup query to complete
      await Future.delayed(const Duration(milliseconds: 50));

      when(() => mockDb.insert('car_expenses', any())).thenAnswer((_) async {
        // Simulate user clicking on a different vehicle (nullifying selection) while insert is in flight
        vehicleController.selectedVehicle.value = null;
        return 101;
      });

      final newExpense = CarExpense(
        vehicleId: 1,
        category: 'repair',
        title: 'Brake replacement',
        amount: 50.0,
        currency: 'USD',
        date: DateTime.parse('2025-02-01T10:00:00.000'),
      );

      clearInteractions(mockDb);

      await controller.addExpense(newExpense);

      verifyNever(() => mockDb.query('car_expenses',
          where: 'vehicle_id = ?',
          whereArgs: [1],
          orderBy: any(named: 'orderBy')));
    });
  });
}

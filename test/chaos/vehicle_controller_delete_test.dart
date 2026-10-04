import 'package:flutter_test/flutter_test.dart';
import 'package:fuelman/controllers/vehicle_controller.dart';
import 'package:fuelman/controllers/fuel_entry_controller.dart';
import 'package:fuelman/controllers/charging_entry_controller.dart';
import 'package:fuelman/controllers/car_expense_controller.dart';
import 'package:fuelman/controllers/settings_controller.dart';
import 'package:fuelman/database/fuel_database.dart';
import 'package:fuelman/models/vehicle.dart';
import 'package:fuelman/models/fuel_entry.dart';
import 'package:fuelman/models/charging_entry.dart';
import 'package:fuelman/models/car_expense.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockDatabase extends Mock implements Database {}

void main() {
  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    Get.reset();
  });

  test('vehicleController.delete clears related state explicitly', () async {
    final mockDb = MockDatabase();
    FuelDatabase.setMockDatabase(mockDb);

    when(() => mockDb.query('vehicles', orderBy: any(named: 'orderBy')))
        .thenAnswer((_) async => [
              const Vehicle(id: 1, name: 'V1', model: 'M1', bodyType: 'sedan', engineType: 'gas').toMap()
            ]);
    when(() => mockDb.query('fuel_entries', where: any(named: 'where'), whereArgs: any(named: 'whereArgs'), orderBy: any(named: 'orderBy'))).thenAnswer((_) async => []);
    when(() => mockDb.rawQuery(any(), any())).thenAnswer((_) async => []);
    when(() => mockDb.query('charging_entries', where: any(named: 'where'), whereArgs: any(named: 'whereArgs'), orderBy: any(named: 'orderBy'))).thenAnswer((_) async => []);
    when(() => mockDb.query('car_expenses', where: any(named: 'where'), whereArgs: any(named: 'whereArgs'), orderBy: any(named: 'orderBy'))).thenAnswer((_) async => []);

    when(() => mockDb.delete(
            'vehicles',
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
          )).thenAnswer((_) async => 1);

    Get.put(SettingsController());

    final vehicleCtrl = VehicleController();
    Get.put(vehicleCtrl);

    final fuelCtrl = FuelEntryController();
    Get.put(fuelCtrl);
    fuelCtrl.entries.add(FuelEntry(vehicleId: 1, date: DateTime.now(), odometer: 0, volume: 0, isFullTank: true, entryType: 'fuel'));

    final chargeCtrl = ChargingEntryController();
    Get.put(chargeCtrl);
    chargeCtrl.entries.add(ChargingEntry(vehicleId: 1, date: DateTime.now(), odometer: 0, kwhAdded: 0, totalCost: 0));

    final expenseCtrl = CarExpenseController();
    Get.put(expenseCtrl);
    expenseCtrl.expenses.add(CarExpense(vehicleId: 1, date: DateTime.now(), category: 'c', title: 't', amount: 0, currency: 'c'));

    await Future.delayed(const Duration(milliseconds: 50));

    await vehicleCtrl.deleteVehicle(1);

    expect(vehicleCtrl.vehicles.isEmpty, isTrue);
    expect(fuelCtrl.entries.isEmpty, isTrue);
    expect(chargeCtrl.entries.isEmpty, isTrue);
    expect(expenseCtrl.expenses.isEmpty, isTrue);
  });
}

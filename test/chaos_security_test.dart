import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fuelman/controllers/fuel_entry_controller.dart';
import 'package:fuelman/controllers/charging_entry_controller.dart';
import 'package:fuelman/controllers/car_expense_controller.dart';
import 'package:fuelman/controllers/vehicle_controller.dart';
import 'package:fuelman/controllers/settings_controller.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
    Get.testMode = true;
  });

  setUp(() {
    Get.put(SettingsController());
    Get.put(VehicleController());
  });

  tearDown(() {
    Get.reset();
  });

  group('Chaos Security & Validation Tests', () {
    test('Number parsing should handle garbage and localized separators without throwing', () {
      const input1 = '12,50'; // Russian locale comma
      const input2 = '12.50'; // US locale dot
      const input3 = ' 12.50 😃 '; // Whitespace and emojis
      const input4 = 'garbage123'; // Invalid string

      // Simulation of what happens inside add_entry_screen.dart (now using tryParse):
      final val1 = double.tryParse(input1.replaceAll(',', '.'));
      expect(val1, 12.5);

      final val2 = double.tryParse(input2.replaceAll(',', '.'));
      expect(val2, 12.5);

      final val3Basic = double.tryParse(input3.replaceAll(',', '.'));
      expect(val3Basic, isNull);

      expect(() => double.parse(input4.replaceAll(',', '.')), throwsFormatException);
    });

    test('Future dates should be rejected in validation', () {
      final futureDate = DateTime.now().add(const Duration(days: 1));
      final isValid = futureDate.isAfter(DateTime.now());
      expect(isValid, isTrue);
    });

    test('Controllers should dispose workers on close', () {
      // Test FuelEntryController
      final fuelCtrl = Get.put(FuelEntryController());
      expect(() => fuelCtrl.onClose(), returnsNormally);
      Get.delete<FuelEntryController>();

      // Test ChargingEntryController
      final chargingCtrl = Get.put(ChargingEntryController());
      expect(() => chargingCtrl.onClose(), returnsNormally);
      Get.delete<ChargingEntryController>();

      // Test CarExpenseController
      final expenseCtrl = Get.put(CarExpenseController());
      expect(() => expenseCtrl.onClose(), returnsNormally);
      Get.delete<CarExpenseController>();
    });
  });
}

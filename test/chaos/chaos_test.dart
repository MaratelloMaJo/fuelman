import 'package:flutter_test/flutter_test.dart';
import 'package:fuelman/controllers/fuel_entry_controller.dart';
import 'package:fuelman/models/fuel_entry.dart';

void main() {
  group('Chaos Engineering & Fuzzing Suite', () {
    test('Extreme Math: Overflows and Negative Values in FuelEntryController', () {
      final entries = [
        FuelEntry(vehicleId: 1, date: DateTime(2025, 1, 1), odometer: -1000.0, volume: -40.0, isFullTank: true, entryType: 'fuel'),
        FuelEntry(vehicleId: 1, date: DateTime(2025, 1, 2), odometer: double.maxFinite, volume: double.maxFinite, isFullTank: true, entryType: 'fuel'),
        FuelEntry(vehicleId: 1, date: DateTime(2025, 1, 3), odometer: 1000000.0, volume: 1000000.0, isFullTank: true, entryType: 'fuel'),
        FuelEntry(vehicleId: 1, date: DateTime(2025, 1, 4), odometer: 0.00001, volume: 0.00001, isFullTank: true, entryType: 'fuel'),
      ];
      final result = FuelEntryController.computeEntriesWithConsumption(entries);
      expect(result.length, 4);
      // Double check that stats calculation does not crash with Infinity or NaN
      final stats = FuelEntryController.calculateOverallStats(result);
      expect(stats.costPerKm?.isNaN ?? false, isFalse);
    });

    test('Extreme Math: Zero Division and Micro distances', () {
      final entries = [
        FuelEntry(vehicleId: 1, date: DateTime(2025, 1, 1), odometer: 1000.0, volume: 40.0, isFullTank: true, entryType: 'fuel'),
        FuelEntry(vehicleId: 1, date: DateTime(2025, 1, 2), odometer: 1000.0001, volume: 40.0, isFullTank: true, entryType: 'fuel'),
      ];
      final result = FuelEntryController.computeEntriesWithConsumption(entries);
      expect(result.length, 2);
      expect(result[1].consumption, isNull, reason: 'Micro distance should prevent calculation');
    });

    test('Odometer Reset / Wrap Around: 999,999 to 0', () {
      final entries = [
        FuelEntry(vehicleId: 1, date: DateTime(2025, 1, 1), odometer: 999990.0, volume: 40.0, isFullTank: true, entryType: 'fuel'),
        FuelEntry(vehicleId: 1, date: DateTime(2025, 1, 2), odometer: 10.0, volume: 40.0, isFullTank: true, entryType: 'fuel'),
      ];
      final result = FuelEntryController.computeEntriesWithConsumption(entries);
      expect(result.length, 2);
      expect(result[1].consumption, isNull, reason: 'Negative delta distance should prevent calculation');
    });

    test('calculateOverallStats: Div by zero protection with all zero distances', () {
        final entries = [
            FuelEntry(vehicleId: 1, date: DateTime(2025, 1, 1), odometer: 1000.0, volume: 40.0, isFullTank: true, entryType: 'fuel', storedTotalCost: 100),
            FuelEntry(vehicleId: 1, date: DateTime(2025, 1, 2), odometer: 1000.0, volume: 40.0, isFullTank: true, entryType: 'fuel', storedTotalCost: 100),
        ];
        final calculated = FuelEntryController.computeEntriesWithConsumption(entries);
        final stats = FuelEntryController.calculateOverallStats(calculated);
        expect(stats.costPerKm, isNull, reason: "Max and Min odometer are the same, should not crash or return Infinity");
    });
  });
}

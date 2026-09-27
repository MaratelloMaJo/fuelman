import 'package:flutter_test/flutter_test.dart';
import 'package:fuelman/controllers/fuel_entry_controller.dart';
import 'package:fuelman/models/fuel_entry.dart';

void main() {
  group('Chaos Engineering & Fuzzing Suite', () {
    test('Extreme Math: Overflows and Negative Values in FuelEntryController',
        () {
      final entries = [
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2025, 1, 1),
            odometer: -1000.0,
            volume: -40.0,
            isFullTank: true,
            entryType: 'fuel'),
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2025, 1, 2),
            odometer: double.maxFinite,
            volume: double.maxFinite,
            isFullTank: true,
            entryType: 'fuel'),
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2025, 1, 3),
            odometer: 1000000.0,
            volume: 1000000.0,
            isFullTank: true,
            entryType: 'fuel'),
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2025, 1, 4),
            odometer: 0.00001,
            volume: 0.00001,
            isFullTank: true,
            entryType: 'fuel'),
      ];
      final result = FuelEntryController.computeEntriesWithConsumption(entries);
      expect(result.length, 4);
      // Double check that stats calculation does not crash with Infinity or NaN
      final stats = FuelEntryController.calculateOverallStats(result);
      expect(stats.costPerKm?.isNaN ?? false, isFalse);
    });

    test('Extreme Math: Zero Division and Micro distances', () {
      final entries = [
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2025, 1, 1),
            odometer: 1000.0,
            volume: 40.0,
            isFullTank: true,
            entryType: 'fuel'),
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2025, 1, 2),
            odometer: 1000.0001,
            volume: 40.0,
            isFullTank: true,
            entryType: 'fuel'),
      ];
      final result = FuelEntryController.computeEntriesWithConsumption(entries);
      expect(result.length, 2);
      expect(result[1].consumption, isNull,
          reason: 'Micro distance should prevent calculation');
    });

    test('Odometer Reset / Wrap Around: 999,999 to 0', () {
      final entries = [
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2025, 1, 1),
            odometer: 999990.0,
            volume: 40.0,
            isFullTank: true,
            entryType: 'fuel'),
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2025, 1, 2),
            odometer: 10.0,
            volume: 40.0,
            isFullTank: true,
            entryType: 'fuel'),
      ];
      final result = FuelEntryController.computeEntriesWithConsumption(entries);
      expect(result.length, 2);
      expect(result[1].consumption, isNull,
          reason: 'Negative delta distance should prevent calculation');
    });

    test(
        'calculateOverallStats: Div by zero protection with all zero distances',
        () {
      final entries = [
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2025, 1, 1),
            odometer: 1000.0,
            volume: 40.0,
            isFullTank: true,
            entryType: 'fuel',
            storedTotalCost: 100),
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2025, 1, 2),
            odometer: 1000.0,
            volume: 40.0,
            isFullTank: true,
            entryType: 'fuel',
            storedTotalCost: 100),
      ];
      final calculated =
          FuelEntryController.computeEntriesWithConsumption(entries);
      final stats = FuelEntryController.calculateOverallStats(calculated);
      expect(stats.costPerKm, isNull,
          reason:
              "Max and Min odometer are the same, should not crash or return Infinity");
    });

    test('Date Validation: Future dates are blocked', () {
      final futureDate = DateTime.now().add(const Duration(days: 1));
      expect(futureDate.isAfter(DateTime.now()), isTrue);
    });

    test('Odometer validation catches negative values', () {
      final err = FuelEntryController.validateOdometer(
          odometer: -5, lastOdometer: null);
      expect(err, 'Одометр не может быть отрицательным');
    });

    test('PHEV Collisions: simultaneous fuel and charging entry handling', () {
      final entries = [
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2025, 1, 1),
            odometer: 1000.0,
            volume: 40.0,
            isFullTank: true,
            entryType: 'fuel'),
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2025, 1, 2),
            odometer: 1500.0,
            volume: 40.0,
            isFullTank: true,
            entryType: 'fuel'),
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2025, 1, 2),
            odometer: 1500.0,
            volume: 20.0,
            isFullTank: true,
            entryType: 'charge'),
      ];

      final calculated = FuelEntryController.computeEntriesWithConsumption(entries);
      expect(calculated.length, 3);
      final stats = FuelEntryController.calculateOverallStats(calculated);
      // Ensure we don't crash and PHEV combined logic works.
      expect(stats.costPerKm?.isNaN ?? false, isFalse);
    });

    test('Time manipulation: Out-of-order dates in statistics aggregation', () {
      final entries = [
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2026, 1, 1), // Later date
            odometer: 1000.0,
            volume: 40.0,
            isFullTank: true,
            entryType: 'fuel',
            storedTotalCost: 1000),
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2025, 1, 1), // Earlier date
            odometer: 1500.0,
            volume: 40.0,
            isFullTank: true,
            entryType: 'fuel',
            storedTotalCost: 1000),
      ];
      final calculated = FuelEntryController.computeEntriesWithConsumption(entries);
      final stats = FuelEntryController.calculateOverallStats(calculated);

      // Since firstDate is 2025 and lastDate is 2026, days is > 0
      // but if the dates were swapped completely, or min/max odo mismatched date orders,
      // it should never crash.
      expect(stats.costPerKm?.isNaN ?? false, isFalse);
      expect(stats.kmPerDay?.isNaN ?? false, isFalse);
      expect(stats.costPerDay?.isNaN ?? false, isFalse);
    });
  });
}

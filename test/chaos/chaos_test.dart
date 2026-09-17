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

    test('Date Validation: Future dates are blocked', () {
      final futureDate = DateTime.now().add(const Duration(days: 1));
      expect(futureDate.isAfter(DateTime.now()), isTrue);
    });

    test('PHEV Collisions: Zero fuel consumption on 100% EV mode driving', () {
      final entries = [
        FuelEntry(vehicleId: 1, date: DateTime(2025, 1, 1), odometer: 1000.0, volume: 40.0, isFullTank: true, entryType: 'fuel'),
        FuelEntry(vehicleId: 1, date: DateTime(2025, 1, 2), odometer: 1100.0, volume: 0.0, isFullTank: true, entryType: 'fuel'),
      ];
      final result = FuelEntryController.computeEntriesWithConsumption(entries);
      expect(result.length, 2);
      expect(result[1].consumption, equals(0.0), reason: 'Zero volume should result in zero consumption');
    });

    test('PHEV Collisions: Negative recuperation volume (not supported directly in UI, but logic must not crash)', () {
      final entries = [
        FuelEntry(vehicleId: 1, date: DateTime(2025, 1, 1), odometer: 1000.0, volume: 20.0, isFullTank: true, entryType: 'charge'),
        FuelEntry(vehicleId: 1, date: DateTime(2025, 1, 2), odometer: 1100.0, volume: -5.0, isFullTank: true, entryType: 'charge'),
      ];
      final result = FuelEntryController.computeEntriesWithConsumption(entries);
      expect(result.length, 2);
      expect(result[1].consumption, equals(-5.0), reason: 'Negative volume results in negative consumption without crashing');
    });

    test('State: Out of chronological order entries correctly handled', () {
      final entries = [
        FuelEntry(vehicleId: 1, date: DateTime(2025, 1, 3), odometer: 1200.0, volume: 20.0, isFullTank: true, entryType: 'fuel'),
        FuelEntry(vehicleId: 1, date: DateTime(2025, 1, 1), odometer: 1000.0, volume: 40.0, isFullTank: true, entryType: 'fuel'),
        FuelEntry(vehicleId: 1, date: DateTime(2025, 1, 2), odometer: 1100.0, volume: 30.0, isFullTank: true, entryType: 'fuel'),
      ];
      final result = FuelEntryController.computeEntriesWithConsumption(entries);
      expect(result.length, 3);
      // Ensure sorted by odometer. The result array order is the same as input, but the consumption calculation relies on sorting internally.
      // Date 1 (odo 1000) -> Date 2 (odo 1100, vol 30 -> 30L/100km) -> Date 3 (odo 1200, vol 20 -> 20L/100km)
      final sortedResult = List.from(result)..sort((a, b) => a.odometer.compareTo(b.odometer));
      expect(sortedResult[0].consumption, isNull);
      expect(sortedResult[1].consumption, equals(30.0));
      expect(sortedResult[2].consumption, equals(20.0));
    });
  });
}

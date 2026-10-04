import 'package:flutter_test/flutter_test.dart';
import 'package:fuelman/controllers/fuel_entry_controller.dart';
import 'package:fuelman/models/fuel_entry.dart';

void main() {
  group('Additional Hard Chaos Tests', () {
    test('PHEV edge cases: Zero fuel consumption when running 100% on electric', () {
      final entries = [
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2025, 1, 1),
            odometer: 1000.0,
            volume: 40.0,
            isFullTank: true,
            entryType: 'fuel'),
        // No fuel used, filled 0.0 liters at next full tank, distance is 500km
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2025, 1, 15),
            odometer: 1500.0,
            volume: 0.0,
            isFullTank: true,
            entryType: 'fuel'),
      ];
      final calculated = FuelEntryController.computeEntriesWithConsumption(entries);
      expect(calculated[1].consumption, 0.0, reason: 'Zero fuel consumption should result in 0.0 L/100km, not NaN or error');
    });

    test('Math edge case: extremely large delta distance', () {
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
            odometer: 1000000000.0, // 1 billion km
            volume: 40.0,
            isFullTank: true,
            entryType: 'fuel'),
      ];
      final result = FuelEntryController.computeEntriesWithConsumption(entries);
      expect(result.length, 2);
      expect(result[1].consumption, isNotNull);
      expect(result[1].consumption!.isFinite, isTrue);

      final stats = FuelEntryController.calculateOverallStats(result);
      expect(stats.costPerKm?.isNaN ?? false, isFalse);
    });

    test('Negative consumption due to recuperation (entryType = charge)', () {
      final entries = [
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2025, 1, 1),
            odometer: 1000.0,
            volume: 20.0, // initial full charge
            isFullTank: true,
            entryType: 'charge'),
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2025, 1, 2),
            odometer: 1100.0,
            volume: -5.0, // recuperated 5 kWh (simulated)
            isFullTank: true,
            entryType: 'charge'),
      ];
      final result = FuelEntryController.computeEntriesWithConsumption(entries);
      expect(result.length, 2);
      // While we limit input in UI, compute engine should handle negative volumes gracefully
      expect(result[1].consumption, -5.0); // -5.0 / 100 * 100 = -5.0
    });
  });
}

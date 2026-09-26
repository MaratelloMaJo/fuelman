import 'package:flutter_test/flutter_test.dart';
import 'package:fuelman/controllers/fuel_entry_controller.dart';
import 'package:fuelman/models/fuel_entry.dart';

void main() {
  group('Fuzzing & Chaos Engineering Tests', () {
    test('calculateOverallStats handles NaN and Infinity', () {
      final entries = [
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2023, 1, 1),
            odometer: double.nan,
            volume: double.nan,
            entryType: 'fuel'),
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2023, 1, 2),
            odometer: double.infinity,
            volume: 40,
            entryType: 'fuel'),
      ];
      final calculated = FuelEntryController.computeEntriesWithConsumption(entries);
      final stats = FuelEntryController.calculateOverallStats(calculated);

      expect(stats.avgFuelConsumption?.isNaN ?? false, isFalse);
      expect(stats.avgEvConsumption?.isNaN ?? false, isFalse);
      expect(stats.costPerKm?.isNaN ?? false, isFalse);
      expect(stats.costPerKm?.isInfinite ?? false, isFalse);
    });

    test('calculateOverallStats handles total zero distance with costs', () {
      final entries = [
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2023, 1, 1),
            odometer: 100,
            volume: 40,
            storedTotalCost: 100,
            entryType: 'fuel'),
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2023, 1, 2),
            odometer: 100,
            volume: 40,
            storedTotalCost: 100,
            entryType: 'fuel'),
      ];
      final calculated = FuelEntryController.computeEntriesWithConsumption(entries);
      final stats = FuelEntryController.calculateOverallStats(calculated);

      expect(stats.costPerKm, isNull);
    });
  });
}

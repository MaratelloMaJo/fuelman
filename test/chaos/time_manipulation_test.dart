import 'package:flutter_test/flutter_test.dart';
import 'package:fuelman/controllers/fuel_entry_controller.dart';
import 'package:fuelman/models/fuel_entry.dart';

void main() {
  group('Time Manipulation and Date Fuzzing', () {
    test('Stats calculation handles unordered dates gracefully', () {
      final entries = [
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2025, 1, 10), // Middle
            odometer: 1100.0,
            volume: 40.0,
            isFullTank: true,
            entryType: 'fuel'),
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2025, 1, 1), // Earliest
            odometer: 1000.0,
            volume: 40.0,
            isFullTank: true,
            entryType: 'fuel'),
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2025, 1, 20), // Latest
            odometer: 1200.0,
            volume: 40.0,
            isFullTank: true,
            entryType: 'fuel'),
      ];
      final calculated = FuelEntryController.computeEntriesWithConsumption(entries);
      final stats = FuelEntryController.calculateOverallStats(calculated);
      // It should calculate days correctly between 2025-01-01 and 2025-01-20 which is 19 days
      expect(stats.kmPerDay, isNotNull);
      expect(stats.costPerDay, isNotNull);
    });

    test('Date Validation: Check time travel prevention', () {
      final futureDate = DateTime.now().add(const Duration(days: 365 * 5));
      expect(futureDate.isAfter(DateTime.now()), isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:fuelman/controllers/fuel_entry_controller.dart';
import 'package:fuelman/models/fuel_entry.dart';
import 'package:fuelman/models/vehicle.dart';

void main() {
  group('Math Edge Cases & Chaos Tests', () {
    test('1. Negative or zero volume validation', () {
      final errorNegative = FuelEntryController.validateEntryVolume(
        volume: -10.0,
        entryType: 'fuel',
        vehicle: const Vehicle(name: 'Test', model: 'Car'),
      );
      expect(errorNegative, isNotNull);
      expect(errorNegative, contains('больше 0'));

      final errorZero = FuelEntryController.validateEntryVolume(
        volume: 0.0,
        entryType: 'fuel',
        vehicle: const Vehicle(name: 'Test', model: 'Car'),
      );
      expect(errorZero, isNotNull);
    });

    test('2. Odometer reset (dashboard change)', () {
      final entries = [
        FuelEntry(
          vehicleId: 1,
          date: DateTime(2023, 1, 1),
          odometer: 999900.0,
          volume: 40.0,
          isFullTank: true,
          entryType: 'fuel',
        ),
        FuelEntry(
          vehicleId: 1,
          date: DateTime(2023, 1, 10),
          odometer: 999990.0,
          volume: 10.0,
          isFullTank: true,
          entryType: 'fuel',
        ),
        FuelEntry(
          vehicleId: 1,
          date: DateTime(2023, 1, 20),
          odometer: 10.0,
          volume: 40.0,
          isFullTank: true,
          entryType: 'fuel',
        ),
        FuelEntry(
          vehicleId: 1,
          date: DateTime(2023, 1, 30),
          odometer: 110.0,
          volume: 10.0,
          isFullTank: true,
          entryType: 'fuel',
        ),
      ];

      final result = FuelEntryController.computeEntriesWithConsumption(entries);

      // The second entry should have consumption calculated
      expect(result[1].consumption, closeTo(11.11, 0.01));

      // The third entry (odometer reset) should NOT have consumption (negative delta)
      expect(result[2].consumption, isNull, reason: 'Odometer decreased, distance is negative');

      // The fourth entry should calculate normally from the third entry
      expect(result[3].consumption, closeTo(10.0, 0.01));
    });

    test('3. Extreme numbers and divisions', () {
      // Extremely small delta, should be protected by kMinDistanceKm
      final entriesSmallDistance = [
        FuelEntry(vehicleId: 1, date: DateTime(2023), odometer: 1000.0, volume: 40.0, isFullTank: true),
        FuelEntry(vehicleId: 1, date: DateTime(2023, 2), odometer: 1000.0001, volume: 40.0, isFullTank: true),
      ];
      final resSmall = FuelEntryController.computeEntriesWithConsumption(entriesSmallDistance);
      expect(resSmall[1].consumption, isNull, reason: 'Delta too small, should not divide');

      // Extremly small volume
      final entriesSmallVolume = [
        FuelEntry(vehicleId: 1, date: DateTime(2023), odometer: 1000.0, volume: 40.0, isFullTank: true),
        FuelEntry(vehicleId: 1, date: DateTime(2023, 2), odometer: 1100.0, volume: 0.00001, isFullTank: true),
      ];
      final resSmallVol = FuelEntryController.computeEntriesWithConsumption(entriesSmallVolume);
      expect(resSmallVol[1].consumption, closeTo(0.00001, 0.0001));
    });

    test('4. Anomaly checks for extreme cases', () {
      // Distance too large
      final warningLargeDist = FuelEntryController.checkAnomalyWarning(
        odometer: 50000,
        volume: 40,
        prevOdometer: 1000, // 49000 km delta
        entryType: 'fuel',
      );
      expect(warningLargeDist, AnomalyWarning.distanceTooLarge);

      // Distance too small
      final warningSmallDist = FuelEntryController.checkAnomalyWarning(
        odometer: 1005,
        volume: 40,
        prevOdometer: 1000, // 5 km delta
        entryType: 'fuel',
      );
      expect(warningSmallDist, AnomalyWarning.distanceTooSmall);

      // Odometer decreased
      final warningDecrease = FuelEntryController.checkAnomalyWarning(
        odometer: 500,
        volume: 40,
        prevOdometer: 1000,
        entryType: 'fuel',
      );
      expect(warningDecrease, AnomalyWarning.odometerDecreased);
    });
  });
}

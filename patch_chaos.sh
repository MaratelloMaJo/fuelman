sed -i 's/^}$//' test/chaos/chaos_test.dart
sed -i 's/^  });$//' test/chaos/chaos_test.dart
cat << 'INNER_EOF' >> test/chaos/chaos_test.dart

    test('NaN distances are caught and handled', () {
      final entries = [
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2025, 1, 1),
            odometer: double.nan,
            volume: 40.0,
            isFullTank: true,
            entryType: 'fuel'),
        FuelEntry(
            vehicleId: 1,
            date: DateTime(2025, 1, 2),
            odometer: 100.0,
            volume: 40.0,
            isFullTank: true,
            entryType: 'fuel'),
      ];
      final result = FuelEntryController.computeEntriesWithConsumption(entries);
      expect(result.length, 2);
      final stats = FuelEntryController.calculateOverallStats(result);
      expect(stats.costPerKm == null || stats.costPerKm!.isNaN == false, isTrue);
    });
  });
}
INNER_EOF

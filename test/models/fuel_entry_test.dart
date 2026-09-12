import 'package:flutter_test/flutter_test.dart';
import 'package:fuelman/models/fuel_entry.dart';

void main() {
  group('FuelEntry', () {
    final DateTime testDate = DateTime(2023, 1, 1, 12, 0);

    test('constructor sets properties correctly', () {
      final entry = FuelEntry(
        id: 1,
        vehicleId: 2,
        date: testDate,
        odometer: 1000.5,
        volume: 50.0,
        isFullTank: true,
        pricePerLiter: 1.5,
        storedTotalCost: 75.0,
        consumption: 8.5,
        entryType: 'fuel',
        volumeUnit: 'L',
        currency: 'USD',
        latitude: 12.34,
        longitude: 56.78,
        stationName: 'Test Station',
      );

      expect(entry.id, 1);
      expect(entry.vehicleId, 2);
      expect(entry.date, testDate);
      expect(entry.odometer, 1000.5);
      expect(entry.volume, 50.0);
      expect(entry.isFullTank, true);
      expect(entry.pricePerLiter, 1.5);
      expect(entry.storedTotalCost, 75.0);
      expect(entry.consumption, 8.5);
      expect(entry.entryType, 'fuel');
      expect(entry.volumeUnit, 'L');
      expect(entry.currency, 'USD');
      expect(entry.latitude, 12.34);
      expect(entry.longitude, 56.78);
      expect(entry.stationName, 'Test Station');
    });

    test('constructor sets default values correctly', () {
      final entry = FuelEntry(
        vehicleId: 1,
        date: testDate,
        odometer: 1000.0,
        volume: 50.0,
      );

      expect(entry.id, isNull);
      expect(entry.isFullTank, true);
      expect(entry.entryType, 'fuel');
      expect(entry.volumeUnit, 'L');
      expect(entry.currency, 'RUB');
      expect(entry.pricePerLiter, isNull);
      expect(entry.storedTotalCost, isNull);
      expect(entry.consumption, isNull);
      expect(entry.latitude, isNull);
      expect(entry.longitude, isNull);
      expect(entry.stationName, isNull);
    });

    group('getters', () {
      test('hasLocation returns true when both latitude and longitude are present', () {
        final entry = FuelEntry(
          vehicleId: 1,
          date: testDate,
          odometer: 1000.0,
          volume: 50.0,
          latitude: 10.0,
          longitude: 20.0,
        );
        expect(entry.hasLocation, isTrue);
      });

      test('hasLocation returns false when latitude is null', () {
        final entry = FuelEntry(
          vehicleId: 1,
          date: testDate,
          odometer: 1000.0,
          volume: 50.0,
          longitude: 20.0,
        );
        expect(entry.hasLocation, isFalse);
      });

      test('hasLocation returns false when longitude is null', () {
        final entry = FuelEntry(
          vehicleId: 1,
          date: testDate,
          odometer: 1000.0,
          volume: 50.0,
          latitude: 10.0,
        );
        expect(entry.hasLocation, isFalse);
      });

      test('hasLocation returns false when both are null', () {
        final entry = FuelEntry(
          vehicleId: 1,
          date: testDate,
          odometer: 1000.0,
          volume: 50.0,
        );
        expect(entry.hasLocation, isFalse);
      });

      test('totalCost returns storedTotalCost if present', () {
        final entry = FuelEntry(
          vehicleId: 1,
          date: testDate,
          odometer: 1000.0,
          volume: 50.0,
          storedTotalCost: 100.0,
          pricePerLiter: 1.5,
        );
        expect(entry.totalCost, 100.0);
      });

      test('totalCost calculates cost if storedTotalCost is null and pricePerLiter is present', () {
        final entry = FuelEntry(
          vehicleId: 1,
          date: testDate,
          odometer: 1000.0,
          volume: 50.0,
          pricePerLiter: 2.0,
        );
        expect(entry.totalCost, 100.0);
      });

      test('totalCost returns null if both storedTotalCost and pricePerLiter are null', () {
        final entry = FuelEntry(
          vehicleId: 1,
          date: testDate,
          odometer: 1000.0,
          volume: 50.0,
        );
        expect(entry.totalCost, isNull);
      });

      test('costPer100km calculates correctly when consumption and pricePerLiter are present', () {
        final entry = FuelEntry(
          vehicleId: 1,
          date: testDate,
          odometer: 1000.0,
          volume: 50.0,
          consumption: 10.0,
          pricePerLiter: 1.5,
        );
        expect(entry.costPer100km, 15.0);
      });

      test('costPer100km returns null if consumption is null', () {
        final entry = FuelEntry(
          vehicleId: 1,
          date: testDate,
          odometer: 1000.0,
          volume: 50.0,
          pricePerLiter: 1.5,
        );
        expect(entry.costPer100km, isNull);
      });

      test('costPer100km returns null if pricePerLiter is null', () {
        final entry = FuelEntry(
          vehicleId: 1,
          date: testDate,
          odometer: 1000.0,
          volume: 50.0,
          consumption: 10.0,
        );
        expect(entry.costPer100km, isNull);
      });
    });

    group('serialization', () {
      final Map<String, dynamic> sampleMap = {
        'id': 1,
        'vehicle_id': 2,
        'date': testDate.toIso8601String(),
        'odometer': 1000.5,
        'volume': 50.0,
        'is_full_tank': 1,
        'price_per_liter': 1.5,
        'total_cost': 75.0,
        'consumption': 8.5,
        'entry_type': 'charge',
        'volume_unit': 'kWh',
        'currency': 'EUR',
        'latitude': 12.34,
        'longitude': 56.78,
        'station_name': 'Test Station',
      };

      test('toMap converts entry to map correctly', () {
        final entry = FuelEntry(
          id: 1,
          vehicleId: 2,
          date: testDate,
          odometer: 1000.5,
          volume: 50.0,
          isFullTank: true,
          pricePerLiter: 1.5,
          storedTotalCost: 75.0,
          consumption: 8.5,
          entryType: 'charge',
          volumeUnit: 'kWh',
          currency: 'EUR',
          latitude: 12.34,
          longitude: 56.78,
          stationName: 'Test Station',
        );

        expect(entry.toMap(), sampleMap);
      });

      test('fromMap converts map to entry correctly', () {
        final entry = FuelEntry.fromMap(sampleMap);

        expect(entry.id, 1);
        expect(entry.vehicleId, 2);
        expect(entry.date, testDate);
        expect(entry.odometer, 1000.5);
        expect(entry.volume, 50.0);
        expect(entry.isFullTank, true);
        expect(entry.pricePerLiter, 1.5);
        expect(entry.storedTotalCost, 75.0);
        expect(entry.consumption, 8.5);
        expect(entry.entryType, 'charge');
        expect(entry.volumeUnit, 'kWh');
        expect(entry.currency, 'EUR');
        expect(entry.latitude, 12.34);
        expect(entry.longitude, 56.78);
        expect(entry.stationName, 'Test Station');
      });

      test('fromMap handles null and default values correctly', () {
        final mapWithDefaults = {
          'id': null,
          'vehicle_id': 2,
          'date': testDate.toIso8601String(),
          'odometer': 1000, // as int
          'volume': 50, // as int
          'is_full_tank': 0,
          'price_per_liter': null,
          'total_cost': null,
          'consumption': null,
          // 'entry_type' missing
          // 'volume_unit' missing
          // 'currency' missing
          'latitude': null,
          'longitude': null,
          'station_name': null,
        };

        final entry = FuelEntry.fromMap(mapWithDefaults);

        expect(entry.id, isNull);
        expect(entry.vehicleId, 2);
        expect(entry.odometer, 1000.0);
        expect(entry.volume, 50.0);
        expect(entry.isFullTank, false);
        expect(entry.pricePerLiter, isNull);
        expect(entry.storedTotalCost, isNull);
        expect(entry.consumption, isNull);
        expect(entry.entryType, 'fuel'); // default
        expect(entry.volumeUnit, 'L'); // default
        expect(entry.currency, 'RUB'); // default
        expect(entry.latitude, isNull);
        expect(entry.longitude, isNull);
        expect(entry.stationName, isNull);
      });
    });

    group('copyWith', () {
      final baseEntry = FuelEntry(
        id: 1,
        vehicleId: 2,
        date: testDate,
        odometer: 1000.0,
        volume: 50.0,
        isFullTank: true,
        pricePerLiter: 1.5,
        storedTotalCost: 75.0,
        consumption: 8.5,
        entryType: 'fuel',
        volumeUnit: 'L',
        currency: 'USD',
        latitude: 12.34,
        longitude: 56.78,
        stationName: 'Station',
      );

      test('updates fields correctly when provided', () {
        final newDate = DateTime(2023, 2, 2);
        final updated = baseEntry.copyWith(
          id: 2,
          vehicleId: 3,
          date: newDate,
          odometer: 1100.0,
          volume: 60.0,
          isFullTank: false,
          pricePerLiter: 2.0,
          storedTotalCost: 120.0,
          consumption: 10.0,
          entryType: 'charge',
          volumeUnit: 'kWh',
          currency: 'EUR',
          latitude: 43.21,
          longitude: 87.65,
          stationName: 'New Station',
        );

        expect(updated.id, 2);
        expect(updated.vehicleId, 3);
        expect(updated.date, newDate);
        expect(updated.odometer, 1100.0);
        expect(updated.volume, 60.0);
        expect(updated.isFullTank, false);
        expect(updated.pricePerLiter, 2.0);
        expect(updated.storedTotalCost, 120.0);
        expect(updated.consumption, 10.0);
        expect(updated.entryType, 'charge');
        expect(updated.volumeUnit, 'kWh');
        expect(updated.currency, 'EUR');
        expect(updated.latitude, 43.21);
        expect(updated.longitude, 87.65);
        expect(updated.stationName, 'New Station');
      });

      test('keeps old fields when new ones are not provided', () {
        final updated = baseEntry.copyWith(
          id: 2, // Only update id
        );

        expect(updated.id, 2);
        expect(updated.vehicleId, 2);
        expect(updated.date, testDate);
        expect(updated.odometer, 1000.0);
        expect(updated.volume, 50.0);
        expect(updated.isFullTank, true);
        expect(updated.pricePerLiter, 1.5);
        expect(updated.storedTotalCost, 75.0);
        expect(updated.consumption, 8.5);
        expect(updated.entryType, 'fuel');
        expect(updated.volumeUnit, 'L');
        expect(updated.currency, 'USD');
        expect(updated.latitude, 12.34);
        expect(updated.longitude, 56.78);
        expect(updated.stationName, 'Station');
      });

      test('clears fields correctly when clear flags are true', () {
        final updated = baseEntry.copyWith(
          clearPricePerLiter: true,
          clearStoredTotalCost: true,
          clearConsumption: true,
          clearLatitude: true,
          clearLongitude: true,
          clearStationName: true,
        );

        expect(updated.pricePerLiter, isNull);
        expect(updated.storedTotalCost, isNull);
        expect(updated.consumption, isNull);
        expect(updated.latitude, isNull);
        expect(updated.longitude, isNull);
        expect(updated.stationName, isNull);

        // Ensure other fields are kept intact
        expect(updated.id, 1);
        expect(updated.vehicleId, 2);
      });

      test('updates fields correctly even if clear flags are true', () {
        final updated = baseEntry.copyWith(
          pricePerLiter: 5.0,
          clearPricePerLiter: true, // clear flag should take precedence
        );
        expect(updated.pricePerLiter, isNull);
      });
    });
  });
}

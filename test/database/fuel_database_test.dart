import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fuelman/database/fuel_database.dart';

class MockDatabase extends Mock implements Database {}

void main() {
  group('FuelDatabase getEntries', () {
    late FuelDatabase fuelDatabase;
    late MockDatabase mockDb;

    setUp(() {
      fuelDatabase = FuelDatabase.instance;
      mockDb = MockDatabase();
      FuelDatabase.setMockDatabase(mockDb);
    });

    tearDown(() {
      FuelDatabase.setMockDatabase(null);
    });

    test('should return empty list when no entries exist', () async {
      when(() => mockDb.query(
            'fuel_entries',
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
            orderBy: any(named: 'orderBy'),
          )).thenAnswer((_) async => []);

      final entries = await fuelDatabase.getEntries(1);

      expect(entries, isEmpty);
      verify(() => mockDb.query(
            'fuel_entries',
            where: 'vehicle_id = ?',
            whereArgs: [1],
            orderBy: 'date ASC',
          )).called(1);
    });

    test('should return mapped entries when entries exist', () async {
      final mockData = [
        {
          'id': 1,
          'vehicle_id': 1,
          'date': '2024-01-01T10:00:00.000',
          'odometer': 1000.0,
          'volume': 40.0,
          'is_full_tank': 1,
          'price_per_liter': 50.0,
          'total_cost': 2000.0,
          'entry_type': 'fuel',
          'volume_unit': 'L',
          'currency': 'RUB',
        },
        {
          'id': 2,
          'vehicle_id': 1,
          'date': '2024-01-10T10:00:00.000',
          'odometer': 1400.0,
          'volume': 35.0,
          'is_full_tank': 0,
          'price_per_liter': 51.0,
          'total_cost': 1785.0,
          'entry_type': 'fuel',
          'volume_unit': 'L',
          'currency': 'RUB',
        },
      ];

      when(() => mockDb.query(
            'fuel_entries',
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
            orderBy: any(named: 'orderBy'),
          )).thenAnswer((_) async => mockData);

      final entries = await fuelDatabase.getEntries(1);

      expect(entries, isNotEmpty);
      expect(entries.length, 2);
      expect(entries.first.id, 1);
      expect(entries.first.odometer, 1000.0);
      expect(entries.last.id, 2);
      expect(entries.last.odometer, 1400.0);

      verify(() => mockDb.query(
            'fuel_entries',
            where: 'vehicle_id = ?',
            whereArgs: [1],
            orderBy: 'date ASC',
          )).called(1);
    });
  });
}

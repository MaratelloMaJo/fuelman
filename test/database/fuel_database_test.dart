import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fuelman/database/fuel_database.dart';
import 'package:fuelman/models/vehicle.dart';
import 'package:fuelman/models/fuel_entry.dart';
import 'package:fuelman/models/car_expense.dart';
import 'package:fuelman/models/charging_entry.dart';

class MockDatabase extends Mock implements Database {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('FuelDatabase getEntries', () {
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

  group('FuelDatabase Vehicles CRUD', () {
    test('getVehicles returns vehicles list', () async {
      when(() => mockDb.query('vehicles', orderBy: any(named: 'orderBy')))
          .thenAnswer((_) async => [
                {
                  'id': 1,
                  'name': 'Camry',
                  'model': 'Toyota',
                  'icon_type': 'sedan',
                  'engine_type': 'gas',
                }
              ]);

      final vehicles = await fuelDatabase.getVehicles();
      expect(vehicles.length, 1);
      expect(vehicles.first.name, 'Camry');
    });

    test('insertVehicle calls db.insert and returns vehicle with id', () async {
      when(() => mockDb.insert('vehicles', any())).thenAnswer((_) async => 42);

      const vehicle = Vehicle(
        name: 'Prius',
        model: 'Toyota',
        bodyType: 'sedan',
        engineType: 'hybrid',
      );

      final result = await fuelDatabase.insertVehicle(vehicle);
      expect(result.id, 42);
      expect(result.name, 'Prius');
    });

    test('updateVehicle calls db.update', () async {
      when(() => mockDb.update(
            'vehicles',
            any(),
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
          )).thenAnswer((_) async => 1);

      const vehicle = Vehicle(
        id: 42,
        name: 'Prius Prime',
        model: 'Toyota',
        bodyType: 'sedan',
        engineType: 'hybrid',
      );

      await fuelDatabase.updateVehicle(vehicle);

      verify(() => mockDb.update(
            'vehicles',
            any(),
            where: 'id = ?',
            whereArgs: [42],
          )).called(1);
    });

    test('deleteVehicle calls db.delete', () async {
      when(() => mockDb.delete(
            'vehicles',
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
          )).thenAnswer((_) async => 1);

      await fuelDatabase.deleteVehicle(42);

      verify(() => mockDb.delete(
            'vehicles',
            where: 'id = ?',
            whereArgs: [42],
          )).called(1);
    });
  });

  group('FuelDatabase Fuel Entries CRUD & Helpers', () {
    test('insertEntry calls db.insert', () async {
      when(() => mockDb.insert('fuel_entries', any()))
          .thenAnswer((_) async => 99);

      final entry = FuelEntry(
        vehicleId: 1,
        date: DateTime.parse('2025-01-01T00:00:00.000'),
        odometer: 10000.0,
        volume: 45.0,
        isFullTank: true,
      );

      final saved = await fuelDatabase.insertEntry(entry);
      expect(saved.id, 99);
      expect(saved.volume, 45.0);
    });

    test('updateEntry and deleteEntry call db correctly', () async {
      when(() => mockDb.update(
            'fuel_entries',
            any(),
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
          )).thenAnswer((_) async => 1);

      when(() => mockDb.delete(
            'fuel_entries',
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
          )).thenAnswer((_) async => 1);

      final entry = FuelEntry(
        id: 99,
        vehicleId: 1,
        date: DateTime.parse('2025-01-01T00:00:00.000'),
        odometer: 10000.0,
        volume: 50.0,
        isFullTank: true,
      );

      await fuelDatabase.updateEntry(entry);
      verify(() => mockDb.update('fuel_entries', any(),
          where: 'id = ?', whereArgs: [99])).called(1);

      await fuelDatabase.deleteEntry(99);
      verify(() => mockDb.delete('fuel_entries',
          where: 'id = ?', whereArgs: [99])).called(1);
    });

    test('getLastEntryDate returns parsed DateTime or null', () async {
      when(() => mockDb.rawQuery(any(), any()))
          .thenAnswer((_) async => [
                {'last_date': '2025-01-15T12:00:00.000'}
              ]);

      final date = await fuelDatabase.getLastEntryDate(1);
      expect(date, isNotNull);
      expect(date!.year, 2025);
      expect(date.month, 1);
      expect(date.day, 15);
    });
  });

  group('FuelDatabase CarExpense & ChargingEntry CRUD', () {
    test('CarExpense insert and delete', () async {
      when(() => mockDb.insert('car_expenses', any()))
          .thenAnswer((_) async => 7);
      when(() => mockDb.delete(
            'car_expenses',
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
          )).thenAnswer((_) async => 1);

      final expense = CarExpense(
        vehicleId: 1,
        category: 'wash',
        title: 'Car Wash',
        amount: 500.0,
        date: DateTime.now(),
      );

      final saved = await fuelDatabase.insertExpense(expense);
      expect(saved.id, 7);

      await fuelDatabase.deleteExpense(7);
      verify(() => mockDb.delete('car_expenses',
          where: 'id = ?', whereArgs: [7])).called(1);
    });

    test('ChargingEntry get, insert and delete', () async {
      when(() => mockDb.query(
            'charging_entries',
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
            orderBy: any(named: 'orderBy'),
          )).thenAnswer((_) async => []);

      final list = await fuelDatabase.getChargingEntriesByVehicleId(1);
      expect(list, isEmpty);

      when(() => mockDb.insert('charging_entries', any()))
          .thenAnswer((_) async => 15);
      when(() => mockDb.delete(
            'charging_entries',
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
          )).thenAnswer((_) async => 1);

      final entry = ChargingEntry(
        vehicleId: 1,
        date: DateTime.now(),
        odometer: 20000.0,
        kwhAdded: 25.0,
        totalCost: 150.0,
      );

      final saved = await fuelDatabase.insertChargingEntry(entry);
      expect(saved.id, 15);

      await fuelDatabase.deleteChargingEntry(15);
      verify(() => mockDb.delete('charging_entries',
          where: 'id = ?', whereArgs: [15])).called(1);
    });
  });

  group('FuelDatabase SQLite Header & Backup Validation', () {
    test('isValidSqliteFile returns false for non-existent file', () async {
      final nonExistent = File('path/to/random_non_existent_file.db');
      final isValid = await FuelDatabase.isValidSqliteFile(nonExistent);
      expect(isValid, isFalse);
    });

    test('isValidSqliteFile returns false for empty or small file (< 16 bytes)', () async {
      final tempDir = await Directory.systemTemp.createTemp('fuelman_test_');
      final smallFile = File('${tempDir.path}/small.db');
      await smallFile.writeAsBytes([1, 2, 3, 4, 5]);

      final isValid = await FuelDatabase.isValidSqliteFile(smallFile);
      expect(isValid, isFalse);

      await tempDir.delete(recursive: true);
    });

    test('isValidSqliteFile returns false for arbitrary text/binary file', () async {
      final tempDir = await Directory.systemTemp.createTemp('fuelman_test_');
      final textFile = File('${tempDir.path}/fake.db');
      await textFile.writeAsString('This is just a text file pretending to be sqlite!');

      final isValid = await FuelDatabase.isValidSqliteFile(textFile);
      expect(isValid, isFalse);

      await tempDir.delete(recursive: true);
    });

    test('isValidSqliteFile returns true for file with SQLite magic header', () async {
      final tempDir = await Directory.systemTemp.createTemp('fuelman_test_');
      final validFile = File('${tempDir.path}/valid.db');

      // SQLite 3 header: "SQLite format 3\x00" followed by 100 zero bytes
      final headerBytes = List<int>.from(FuelDatabase.sqliteHeaderBytes)
        ..addAll(List.filled(100, 0));
      await validFile.writeAsBytes(headerBytes);

      final isValid = await FuelDatabase.isValidSqliteFile(validFile);
      expect(isValid, isTrue);

      await tempDir.delete(recursive: true);
    });

    test('importBackup rejects invalid file and returns false', () async {
      final tempDir = await Directory.systemTemp.createTemp('fuelman_test_');
      final maliciousFile = File('${tempDir.path}/malicious.txt');
      await maliciousFile.writeAsString('malicious payload');

      final imported = await fuelDatabase.importBackup(pickedFilePath: maliciousFile.path);
      expect(imported, isFalse);

      await tempDir.delete(recursive: true);
    });

    test('exportBackup catch block handles errors gracefully', () async {
      // Calling exportBackup should not throw an unhandled exception even if database path or file sharing fails
      expect(fuelDatabase.exportBackup(), completes);
    });
  });
}

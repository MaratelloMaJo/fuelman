import 'package:flutter_test/flutter_test.dart';
import 'package:fuelman/controllers/vehicle_controller.dart';
import 'package:fuelman/database/fuel_database.dart';
import 'package:fuelman/models/vehicle.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';

class MockDatabase extends Mock implements Database {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDatabase mockDb;

  const vehicle1 = Vehicle(
    id: 1,
    name: 'BMW 330e',
    model: '330e',
    bodyType: 'sedan',
    engineType: 'phev',
  );

  const vehicle2 = Vehicle(
    id: 2,
    name: 'Audi e-tron',
    model: 'e-tron',
    bodyType: 'suv',
    engineType: 'electric',
  );

  setUp(() {
    Get.testMode = true;
    mockDb = MockDatabase();
    FuelDatabase.setMockDatabase(mockDb);

    when(() => mockDb.query('vehicles', orderBy: any(named: 'orderBy')))
        .thenAnswer((_) async => [
              vehicle1.toMap(),
              vehicle2.toMap(),
            ]);
  });

  tearDown(() {
    Get.reset();
    FuelDatabase.setMockDatabase(null);
  });

  group('VehicleController Tests', () {
    test('loadVehicles initializes vehicles list and selects the first vehicle', () async {
      final controller = VehicleController();
      Get.put(controller);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(controller.vehicles.length, 2);
      expect(controller.selectedVehicle.value, isNotNull);
      expect(controller.selectedVehicle.value!.id, 1);
      expect(controller.selectedVehicle.value!.name, 'BMW 330e');
    });

    test('selectVehicle updates selectedVehicle reactive property', () async {
      final controller = VehicleController();
      Get.put(controller);
      await Future.delayed(const Duration(milliseconds: 50));

      controller.selectVehicle(controller.vehicles[1]);
      expect(controller.selectedVehicle.value!.id, 2);
      expect(controller.selectedVehicle.value!.name, 'Audi e-tron');
    });

    test('addVehicle inserts to db, sorts list by name and selects the new vehicle', () async {
      final controller = VehicleController();
      Get.put(controller);
      await Future.delayed(const Duration(milliseconds: 50));

      when(() => mockDb.insert('vehicles', any()))
          .thenAnswer((_) async => 3);

      const newVehicle = Vehicle(
        name: 'Alfa Romeo Giulia',
        model: 'Giulia',
        bodyType: 'sedan',
        engineType: 'gas',
      );

      final saved = await controller.addVehicle(newVehicle);

      expect(saved.id, 3);
      expect(controller.vehicles.length, 3);
      // Alphabetical order: Alfa Romeo Giulia should be first
      expect(controller.vehicles.first.name, 'Alfa Romeo Giulia');
      expect(controller.selectedVehicle.value!.id, 3);
    });

    test('updateVehicle updates database, list, and selectedVehicle if matched', () async {
      final controller = VehicleController();
      Get.put(controller);
      await Future.delayed(const Duration(milliseconds: 50));

      when(() => mockDb.update(
            'vehicles',
            any(),
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
          )).thenAnswer((_) async => 1);

      final updated = vehicle1.copyWith(name: 'BMW 330e M-Sport');
      await controller.updateVehicle(updated);

      expect(controller.vehicles.firstWhere((v) => v.id == 1).name, 'BMW 330e M-Sport');
      expect(controller.selectedVehicle.value!.name, 'BMW 330e M-Sport');
    });

    test('deleteVehicle removes from list and updates selectedVehicle fallback', () async {
      final controller = VehicleController();
      Get.put(controller);
      await Future.delayed(const Duration(milliseconds: 50));

      when(() => mockDb.delete(
            'vehicles',
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
          )).thenAnswer((_) async => 1);

      // Current selected is vehicle 1. Delete vehicle 1.
      await controller.deleteVehicle(1);

      expect(controller.vehicles.length, 1);
      expect(controller.vehicles.first.id, 2);
      expect(controller.selectedVehicle.value!.id, 2);
    });

    test('deleteVehicle calls _clearRelatedControllersState and resets states', () async {
      when(() => mockDb.query('vehicles', orderBy: any(named: 'orderBy')))
          .thenAnswer((_) async => [vehicle1.toMap()]);

      final controller = VehicleController();
      Get.put(controller);
      await Future.delayed(const Duration(milliseconds: 50));

      when(() => mockDb.delete(
            'vehicles',
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
          )).thenAnswer((_) async => 1);

      await controller.deleteVehicle(1);
      // Even without controllers registered, the code should not crash
      expect(controller.vehicles.isEmpty, isTrue);
      expect(controller.selectedVehicle.value, isNull);
    });

    test('deleteVehicle when all vehicles removed sets selectedVehicle to null', () async {
      when(() => mockDb.query('vehicles', orderBy: any(named: 'orderBy')))
          .thenAnswer((_) async => [vehicle1.toMap()]);

      final controller = VehicleController();
      Get.put(controller);
      await Future.delayed(const Duration(milliseconds: 50));

      when(() => mockDb.delete(
            'vehicles',
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
          )).thenAnswer((_) async => 1);

      await controller.deleteVehicle(1);

      expect(controller.vehicles, isEmpty);
      expect(controller.selectedVehicle.value, isNull);
    });
  });
}

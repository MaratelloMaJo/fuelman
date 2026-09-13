import 'package:flutter_test/flutter_test.dart';
import 'package:fuelman/models/vehicle.dart';

void main() {
  group('Vehicle Model', () {
    group('Serialization', () {
      test('toMap and fromMap should correctly serialize and deserialize all fields', () {
        const vehicle = Vehicle(
          id: 1,
          name: 'My Car',
          model: 'Model S',
          bodyType: 'hatchback',
          engineType: 'hybrid',
          hybridType: 'PHEV',
          fuelSubtype: '95',
          fuelGoal: 5.5,
          evGoal: 15.0,
          reminderDays: 30,
          licensePlate: 'ABC-123',
          engineVolume: 2.0,
          horsePower: 150,
          year: 2022,
          batteryCapacityKwh: 15.0,
          usableCapacityKwh: 13.5,
          tankCapacity: 45.0,
        );

        final map = vehicle.toMap();
        expect(map['id'], 1);
        expect(map['name'], 'My Car');
        expect(map['icon_type'], 'hatchback');
        expect(map['battery_capacity_kwh'], 15.0);

        final deserialized = Vehicle.fromMap(map);
        expect(deserialized.id, vehicle.id);
        expect(deserialized.name, vehicle.name);
        expect(deserialized.model, vehicle.model);
        expect(deserialized.bodyType, vehicle.bodyType);
        expect(deserialized.engineType, vehicle.engineType);
        expect(deserialized.hybridType, vehicle.hybridType);
        expect(deserialized.fuelSubtype, vehicle.fuelSubtype);
        expect(deserialized.fuelGoal, vehicle.fuelGoal);
        expect(deserialized.evGoal, vehicle.evGoal);
        expect(deserialized.reminderDays, vehicle.reminderDays);
        expect(deserialized.licensePlate, vehicle.licensePlate);
        expect(deserialized.engineVolume, vehicle.engineVolume);
        expect(deserialized.horsePower, vehicle.horsePower);
        expect(deserialized.year, vehicle.year);
        expect(deserialized.batteryCapacityKwh, vehicle.batteryCapacityKwh);
        expect(deserialized.usableCapacityKwh, vehicle.usableCapacityKwh);
        expect(deserialized.tankCapacity, vehicle.tankCapacity);
      });

      test('fromMap should handle missing optional fields gracefully', () {
        final map = {
          'id': 2,
          'name': 'Basic Car',
          'model': 'Basic',
        };

        final vehicle = Vehicle.fromMap(map);
        expect(vehicle.id, 2);
        expect(vehicle.name, 'Basic Car');
        expect(vehicle.model, 'Basic');
        expect(vehicle.bodyType, 'sedan');
        expect(vehicle.engineType, 'gas');
        expect(vehicle.hybridType, isNull);
        expect(vehicle.fuelSubtype, isNull);
        expect(vehicle.batteryCapacityKwh, isNull);
        expect(vehicle.tankCapacity, isNull);
      });
    });

    group('Static Methods: isTankRequiredFor', () {
      test('requires tank for gas, diesel, hybrid', () {
        expect(Vehicle.isTankRequiredFor(engineType: 'gas'), isTrue);
        expect(Vehicle.isTankRequiredFor(engineType: 'diesel'), isTrue);
        expect(Vehicle.isTankRequiredFor(engineType: 'hybrid'), isTrue);
      });

      test('requires tank for lpg or cng fuelSubtype regardless of engineType', () {
        expect(Vehicle.isTankRequiredFor(engineType: 'other', fuelSubtype: 'lpg'), isTrue);
        expect(Vehicle.isTankRequiredFor(engineType: 'other', fuelSubtype: 'cng'), isTrue);
      });

      test('does not require tank for electric', () {
        expect(Vehicle.isTankRequiredFor(engineType: 'electric'), isFalse);
        expect(Vehicle.isTankRequiredFor(engineType: 'other'), isFalse);
      });
    });

    group('Static Methods: isBatteryRequiredFor', () {
      test('requires battery for electric', () {
        expect(Vehicle.isBatteryRequiredFor(engineType: 'electric'), isTrue);
      });

      test('requires battery for specific hybrid types (PHEV, BEV_REX)', () {
        expect(Vehicle.isBatteryRequiredFor(engineType: 'hybrid', hybridType: 'PHEV'), isTrue);
        expect(Vehicle.isBatteryRequiredFor(engineType: 'hybrid', hybridType: 'BEV_REX'), isTrue);
      });

      test('does not require battery for other hybrid types or gas/diesel', () {
        expect(Vehicle.isBatteryRequiredFor(engineType: 'hybrid', hybridType: 'HEV'), isFalse);
        expect(Vehicle.isBatteryRequiredFor(engineType: 'hybrid', hybridType: 'MHEV'), isFalse);
        expect(Vehicle.isBatteryRequiredFor(engineType: 'gas'), isFalse);
      });
    });

    group('Computed Getters (canCharge, canRefuel, isFullyElectric, isPhev, isSelfChargingHybrid)', () {
      test('electric vehicle capabilities', () {
        const ev = Vehicle(name: 'EV', model: 'Model 3', engineType: 'electric');
        expect(ev.canCharge, isTrue);
        expect(ev.canRefuel, isFalse);
        expect(ev.isFullyElectric, isTrue);
        expect(ev.isPhev, isFalse);
        expect(ev.isSelfChargingHybrid, isFalse);
      });

      test('PHEV vehicle capabilities', () {
        const phev = Vehicle(name: 'PHEV', model: 'Outlander', engineType: 'hybrid', hybridType: 'PHEV');
        expect(phev.canCharge, isTrue);
        expect(phev.canRefuel, isTrue);
        expect(phev.isFullyElectric, isFalse);
        expect(phev.isPhev, isTrue);
        expect(phev.isSelfChargingHybrid, isFalse);
      });

      test('HEV (Self-charging hybrid) vehicle capabilities', () {
        const hev = Vehicle(name: 'HEV', model: 'Prius', engineType: 'hybrid', hybridType: 'HEV');
        expect(hev.canCharge, isFalse);
        expect(hev.canRefuel, isTrue);
        expect(hev.isFullyElectric, isFalse);
        expect(hev.isPhev, isFalse);
        expect(hev.isSelfChargingHybrid, isTrue);
      });

      test('BEV_REX vehicle capabilities', () {
        const bevRex = Vehicle(name: 'BEV REX', model: 'i3 REX', engineType: 'hybrid', hybridType: 'BEV_REX');
        expect(bevRex.canCharge, isTrue);
        expect(bevRex.canRefuel, isTrue);
        expect(bevRex.isFullyElectric, isFalse);
      });

      test('FCEV vehicle capabilities', () {
        const fcev = Vehicle(name: 'FCEV', model: 'Mirai', engineType: 'hybrid', hybridType: 'FCEV');
        expect(fcev.canCharge, isTrue);
        expect(fcev.canRefuel, isTrue);
        expect(fcev.isFullyElectric, isFalse);
      });

      test('Gas vehicle capabilities', () {
        const gas = Vehicle(name: 'Gas', model: 'Corolla', engineType: 'gas');
        expect(gas.canCharge, isFalse);
        expect(gas.canRefuel, isTrue);
        expect(gas.isFullyElectric, isFalse);
        expect(gas.isPhev, isFalse);
        expect(gas.isSelfChargingHybrid, isFalse);
      });
    });

    group('Data Capacity Helpers (hasBatteryData, hasTankData, effectiveCapacityKwh)', () {
      test('hasBatteryData checks', () {
        expect(const Vehicle(name: 'Test', model: 'Test').hasBatteryData, isFalse);
        expect(const Vehicle(name: 'Test', model: 'Test', batteryCapacityKwh: 10.0).hasBatteryData, isTrue);
        expect(const Vehicle(name: 'Test', model: 'Test', usableCapacityKwh: 8.0).hasBatteryData, isTrue);
        expect(const Vehicle(name: 'Test', model: 'Test', batteryCapacityKwh: 0.0).hasBatteryData, isFalse);
      });

      test('hasTankData checks', () {
        expect(const Vehicle(name: 'Test', model: 'Test').hasTankData, isFalse);
        expect(const Vehicle(name: 'Test', model: 'Test', tankCapacity: 45.0).hasTankData, isTrue);
        expect(const Vehicle(name: 'Test', model: 'Test', tankCapacity: 0.0).hasTankData, isFalse);
      });

      test('effectiveCapacityKwh prefers usableCapacityKwh', () {
        const v1 = Vehicle(name: 'Test', model: 'Test', batteryCapacityKwh: 20.0, usableCapacityKwh: 18.0);
        expect(v1.effectiveCapacityKwh, 18.0);

        const v2 = Vehicle(name: 'Test', model: 'Test', batteryCapacityKwh: 20.0);
        expect(v2.effectiveCapacityKwh, 20.0);

        const v3 = Vehicle(name: 'Test', model: 'Test');
        expect(v3.effectiveCapacityKwh, isNull);
      });
    });

    group('validateCapacities', () {
      test('returns error if tank required but missing', () {
        const v = Vehicle(name: 'Test', model: 'Test', engineType: 'gas', tankCapacity: null);
        expect(v.validateCapacities(), contains('Объем топливного бака обязателен'));

        const vZero = Vehicle(name: 'Test', model: 'Test', engineType: 'gas', tankCapacity: 0.0);
        expect(vZero.validateCapacities(), contains('Объем топливного бака обязателен'));
      });

      test('returns error if battery required but missing', () {
        const v = Vehicle(name: 'Test', model: 'Test', engineType: 'electric', batteryCapacityKwh: null);
        expect(v.validateCapacities(), contains('Емкость аккумулятора обязательна'));

        const vZero = Vehicle(name: 'Test', model: 'Test', engineType: 'electric', batteryCapacityKwh: 0.0, usableCapacityKwh: 0.0);
        expect(vZero.validateCapacities(), contains('Емкость аккумулятора обязательна'));
      });

      test('returns null if valid', () {
        const gas = Vehicle(name: 'Test', model: 'Test', engineType: 'gas', tankCapacity: 50.0);
        expect(gas.validateCapacities(), isNull);

        const ev = Vehicle(name: 'Test', model: 'Test', engineType: 'electric', batteryCapacityKwh: 60.0);
        expect(ev.validateCapacities(), isNull);

        const phev = Vehicle(name: 'Test', model: 'Test', engineType: 'hybrid', hybridType: 'PHEV', tankCapacity: 40.0, batteryCapacityKwh: 15.0);
        expect(phev.validateCapacities(), isNull);
      });
    });

    group('copyWith', () {
      test('updates fields correctly', () {
        const v1 = Vehicle(name: 'V1', model: 'M1', tankCapacity: 40.0);
        final v2 = v1.copyWith(name: 'V2', tankCapacity: 50.0, engineType: 'diesel');

        expect(v2.name, 'V2');
        expect(v2.model, 'M1');
        expect(v2.tankCapacity, 50.0);
        expect(v2.engineType, 'diesel');
      });

      test('clears fields correctly', () {
        const v1 = Vehicle(name: 'V1', model: 'M1', hybridType: 'PHEV', tankCapacity: 40.0);
        final v2 = v1.copyWith(clearHybridType: true, clearTankCapacity: true);

        expect(v2.hybridType, isNull);
        expect(v2.tankCapacity, isNull);
        expect(v2.name, 'V1'); // unchanged
      });
    });
  });
}

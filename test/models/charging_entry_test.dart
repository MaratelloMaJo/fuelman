import 'package:flutter_test/flutter_test.dart';
import 'package:fuelman/models/charging_entry.dart';

void main() {
  group('ChargingEntry', () {
    test('costPerKwh calculates correctly', () {
      final entry = ChargingEntry(
        vehicleId: 1,
        date: DateTime.now(),
        odometer: 1000,
        kwhAdded: 50,
        totalCost: 1000,
      );
      expect(entry.costPerKwh, 20.0);
    });

    test('costPerKwh handles zero kwhAdded gracefully', () {
      final entry = ChargingEntry(
        vehicleId: 1,
        date: DateTime.now(),
        odometer: 1000,
        kwhAdded: 0,
        totalCost: 1000,
      );
      expect(entry.costPerKwh, 0.0);
    });

    group('deltaEnergyStored', () {
      test('calculates correct energy stored', () {
        final entry = ChargingEntry(
          vehicleId: 1,
          date: DateTime.now(),
          odometer: 1000,
          kwhAdded: 50,
          totalCost: 1000,
          startSocPercent: 20,
          endSocPercent: 80,
        );
        expect(entry.deltaEnergyStored(100), 60.0); // (80-20)/100 * 100 = 60
      });

      test('returns null if capacity is missing or zero', () {
        final entry = ChargingEntry(
          vehicleId: 1,
          date: DateTime.now(),
          odometer: 1000,
          kwhAdded: 50,
          totalCost: 1000,
          startSocPercent: 20,
          endSocPercent: 80,
        );
        expect(entry.deltaEnergyStored(null), isNull);
        expect(entry.deltaEnergyStored(0), isNull);
      });

      test('returns null if SOC data is missing', () {
        final entryNoStart = ChargingEntry(
          vehicleId: 1,
          date: DateTime.now(),
          odometer: 1000,
          kwhAdded: 50,
          totalCost: 1000,
          endSocPercent: 80,
        );
        expect(entryNoStart.deltaEnergyStored(100), isNull);

        final entryNoEnd = ChargingEntry(
          vehicleId: 1,
          date: DateTime.now(),
          odometer: 1000,
          kwhAdded: 50,
          totalCost: 1000,
          startSocPercent: 20,
        );
        expect(entryNoEnd.deltaEnergyStored(100), isNull);
      });

      test('returns null if delta is zero or negative', () {
        final entryZero = ChargingEntry(
          vehicleId: 1,
          date: DateTime.now(),
          odometer: 1000,
          kwhAdded: 50,
          totalCost: 1000,
          startSocPercent: 80,
          endSocPercent: 80,
        );
        expect(entryZero.deltaEnergyStored(100), isNull);

        final entryNeg = ChargingEntry(
          vehicleId: 1,
          date: DateTime.now(),
          odometer: 1000,
          kwhAdded: 50,
          totalCost: 1000,
          startSocPercent: 80,
          endSocPercent: 20,
        );
        expect(entryNeg.deltaEnergyStored(100), isNull);
      });
    });

    group('efficiencyRatio', () {
      test('calculates correct efficiency', () {
        final entry = ChargingEntry(
          vehicleId: 1,
          date: DateTime.now(),
          odometer: 1000,
          kwhAdded: 50,
          totalCost: 1000,
          startSocPercent: 20,
          endSocPercent: 70, // 50% delta on 90kwh = 45kwh stored
        );
        // 45 / 50 * 100 = 90%
        expect(entry.efficiencyRatio(90), 90.0);
      });

      test('returns null if kwhAdded is zero', () {
        final entry = ChargingEntry(
          vehicleId: 1,
          date: DateTime.now(),
          odometer: 1000,
          kwhAdded: 0,
          totalCost: 1000,
          startSocPercent: 20,
          endSocPercent: 70,
        );
        expect(entry.efficiencyRatio(90), isNull);
      });

      test('returns null if deltaEnergyStored is null', () {
        final entry = ChargingEntry(
          vehicleId: 1,
          date: DateTime.now(),
          odometer: 1000,
          kwhAdded: 50,
          totalCost: 1000,
          // Missing SOC data
        );
        expect(entry.efficiencyRatio(90), isNull);
      });
    });

    group('isEfficiencyAnomalous', () {
      test('returns false for normal efficiency', () {
        final entry = ChargingEntry(
          vehicleId: 1,
          date: DateTime.now(),
          odometer: 1000,
          kwhAdded: 50,
          totalCost: 1000,
          startSocPercent: 20,
          endSocPercent: 70, // 45kwh stored / 50kwh added = 90%
        );
        expect(entry.isEfficiencyAnomalous(90), isFalse);
      });

      test('returns true for low efficiency (< 50%)', () {
        final entry = ChargingEntry(
          vehicleId: 1,
          date: DateTime.now(),
          odometer: 1000,
          kwhAdded: 100, // 100 added
          totalCost: 1000,
          startSocPercent: 20,
          endSocPercent: 60, // 40kwh stored / 100kwh added = 40%
        );
        expect(entry.isEfficiencyAnomalous(100), isTrue);
      });

      test('returns true for high efficiency (> 100%)', () {
        final entry = ChargingEntry(
          vehicleId: 1,
          date: DateTime.now(),
          odometer: 1000,
          kwhAdded: 30, // 30 added
          totalCost: 1000,
          startSocPercent: 20,
          endSocPercent: 70, // 50kwh stored / 30kwh added = 166%
        );
        expect(entry.isEfficiencyAnomalous(100), isTrue);
      });

      test('returns false if efficiency data is missing', () {
        final entry = ChargingEntry(
          vehicleId: 1,
          date: DateTime.now(),
          odometer: 1000,
          kwhAdded: 50,
          totalCost: 1000,
        );
        expect(entry.isEfficiencyAnomalous(100), isFalse);
      });
    });

    group('estimatedDurationHours', () {
      test('calculates duration correctly', () {
        final entry = ChargingEntry(
          vehicleId: 1,
          date: DateTime.now(),
          odometer: 1000,
          kwhAdded: 50,
          totalCost: 1000,
          powerKw: 10,
        );
        expect(entry.estimatedDurationHours, 5.0);
      });

      test('returns null if powerKw is missing or zero', () {
        final entryMissing = ChargingEntry(
          vehicleId: 1,
          date: DateTime.now(),
          odometer: 1000,
          kwhAdded: 50,
          totalCost: 1000,
        );
        expect(entryMissing.estimatedDurationHours, isNull);

        final entryZero = ChargingEntry(
          vehicleId: 1,
          date: DateTime.now(),
          odometer: 1000,
          kwhAdded: 50,
          totalCost: 1000,
          powerKw: 0,
        );
        expect(entryZero.estimatedDurationHours, isNull);
      });
    });

    group('Enums serialization', () {
      test('ChargerType to/from db string', () {
        expect(ChargerType.acSlow.toDbString(), 'acSlow');
        expect(ChargerType.dcFast.toDbString(), 'dcFast');

        expect(ChargerType.fromDbString('acSlow'), ChargerType.acSlow);
        expect(ChargerType.fromDbString('dcFast'), ChargerType.dcFast);
        expect(ChargerType.fromDbString('unknown'), ChargerType.acSlow);
        expect(ChargerType.fromDbString(null), ChargerType.acSlow);
      });

      test('ChargerStandard to/from db string', () {
        expect(ChargerStandard.homeSocket.toDbString(), 'homeSocket');
        expect(ChargerStandard.type2.toDbString(), 'type2');
        expect(ChargerStandard.ccs2.toDbString(), 'ccs2');
        expect(ChargerStandard.gbtAc.toDbString(), 'gbtAc');
        expect(ChargerStandard.gbtDc.toDbString(), 'gbtDc');

        expect(ChargerStandard.fromDbString('homeSocket'), ChargerStandard.homeSocket);
        expect(ChargerStandard.fromDbString('type2'), ChargerStandard.type2);
        expect(ChargerStandard.fromDbString('ccs2'), ChargerStandard.ccs2);
        expect(ChargerStandard.fromDbString('gbtAc'), ChargerStandard.gbtAc);
        expect(ChargerStandard.fromDbString('gbtDc'), ChargerStandard.gbtDc);
        expect(ChargerStandard.fromDbString('unknown'), ChargerStandard.homeSocket);
        expect(ChargerStandard.fromDbString(null), ChargerStandard.homeSocket);
      });
    });

    group('Serialization', () {
      test('toMap and fromMap work with full data', () {
        final date = DateTime.parse('2023-10-27T10:00:00.000Z');
        final entry = ChargingEntry(
          id: 1,
          vehicleId: 2,
          date: date,
          odometer: 15000.5,
          evOdometer: 5000.2,
          kwhAdded: 45.5,
          startSocPercent: 20.0,
          endSocPercent: 80.0,
          totalCost: 450.0,
          chargerType: ChargerType.dcFast,
          chargerStandard: ChargerStandard.ccs2,
          powerKw: 50.0,
          temperatureCelsius: 15.0,
          stationName: 'Supercharger',
        );

        final map = entry.toMap();
        expect(map['id'], 1);
        expect(map['vehicle_id'], 2);
        expect(map['date'], '2023-10-27T10:00:00.000Z');
        expect(map['odometer'], 15000.5);
        expect(map['ev_odometer'], 5000.2);
        expect(map['kwh_added'], 45.5);
        expect(map['start_soc_percent'], 20.0);
        expect(map['end_soc_percent'], 80.0);
        expect(map['total_cost'], 450.0);
        expect(map['charger_type'], 'dcFast');
        expect(map['charger_standard'], 'ccs2');
        expect(map['power_kw'], 50.0);
        expect(map['temperature_celsius'], 15.0);
        expect(map['station_name'], 'Supercharger');

        final reconstructed = ChargingEntry.fromMap(map);
        expect(reconstructed.id, 1);
        expect(reconstructed.vehicleId, 2);
        expect(reconstructed.date, date);
        expect(reconstructed.odometer, 15000.5);
        expect(reconstructed.evOdometer, 5000.2);
        expect(reconstructed.kwhAdded, 45.5);
        expect(reconstructed.startSocPercent, 20.0);
        expect(reconstructed.endSocPercent, 80.0);
        expect(reconstructed.totalCost, 450.0);
        expect(reconstructed.chargerType, ChargerType.dcFast);
        expect(reconstructed.chargerStandard, ChargerStandard.ccs2);
        expect(reconstructed.powerKw, 50.0);
        expect(reconstructed.temperatureCelsius, 15.0);
        expect(reconstructed.stationName, 'Supercharger');
      });

      test('toMap and fromMap work with missing optional data', () {
        final date = DateTime.parse('2023-10-27T10:00:00.000Z');
        final entry = ChargingEntry(
          vehicleId: 2,
          date: date,
          odometer: 15000.5,
          kwhAdded: 45.5,
          totalCost: 450.0,
        );

        final map = entry.toMap();
        expect(map['id'], isNull);
        expect(map['ev_odometer'], isNull);
        expect(map['start_soc_percent'], isNull);
        expect(map['end_soc_percent'], isNull);
        expect(map['power_kw'], isNull);
        expect(map['temperature_celsius'], isNull);
        expect(map['station_name'], isNull);

        final reconstructed = ChargingEntry.fromMap(map);
        expect(reconstructed.id, isNull);
        expect(reconstructed.evOdometer, isNull);
        expect(reconstructed.startSocPercent, isNull);
        expect(reconstructed.endSocPercent, isNull);
        expect(reconstructed.powerKw, isNull);
        expect(reconstructed.temperatureCelsius, isNull);
        expect(reconstructed.stationName, isNull);
      });
    });

    group('copyWith', () {
      test('updates specified fields', () {
        final date1 = DateTime.parse('2023-10-27T10:00:00.000Z');
        final date2 = DateTime.parse('2023-10-28T10:00:00.000Z');
        final entry = ChargingEntry(
          id: 1,
          vehicleId: 1,
          date: date1,
          odometer: 1000,
          kwhAdded: 50,
          totalCost: 1000,
        );

        final updated = entry.copyWith(
          id: 2,
          vehicleId: 3,
          date: date2,
          odometer: 2000,
          kwhAdded: 60,
          totalCost: 1200,
          evOdometer: 500,
          startSocPercent: 10,
          endSocPercent: 90,
          chargerType: ChargerType.dcFast,
          chargerStandard: ChargerStandard.ccs2,
          powerKw: 50,
          temperatureCelsius: 20,
          stationName: 'Station',
        );

        expect(updated.id, 2);
        expect(updated.vehicleId, 3);
        expect(updated.date, date2);
        expect(updated.odometer, 2000);
        expect(updated.kwhAdded, 60);
        expect(updated.totalCost, 1200);
        expect(updated.evOdometer, 500);
        expect(updated.startSocPercent, 10);
        expect(updated.endSocPercent, 90);
        expect(updated.chargerType, ChargerType.dcFast);
        expect(updated.chargerStandard, ChargerStandard.ccs2);
        expect(updated.powerKw, 50);
        expect(updated.temperatureCelsius, 20);
        expect(updated.stationName, 'Station');
      });

      test('clears nullable fields', () {
        final entry = ChargingEntry(
          vehicleId: 1,
          date: DateTime.now(),
          odometer: 1000,
          kwhAdded: 50,
          totalCost: 1000,
          evOdometer: 500,
          startSocPercent: 10,
          endSocPercent: 90,
          powerKw: 50,
          temperatureCelsius: 20,
          stationName: 'Station',
        );

        final cleared = entry.copyWith(
          clearEvOdometer: true,
          clearStartSoc: true,
          clearEndSoc: true,
          clearPowerKw: true,
          clearTemperature: true,
          clearStationName: true,
        );

        expect(cleared.evOdometer, isNull);
        expect(cleared.startSocPercent, isNull);
        expect(cleared.endSocPercent, isNull);
        expect(cleared.powerKw, isNull);
        expect(cleared.temperatureCelsius, isNull);
        expect(cleared.stationName, isNull);
      });
    });
  });
}

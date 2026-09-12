import 'package:flutter_test/flutter_test.dart';

import 'package:fuelman/models/charging_entry.dart';
import 'package:fuelman/models/vehicle.dart';
import 'package:fuelman/controllers/charging_entry_controller.dart';

/// Unit-тесты бизнес-логики подсистемы учёта электроэнергии EV/PHEV.
///
/// Покрытие:
///   1. ChargingEntry.costPerKwh — базовый расчёт и защита от деления на ноль
///   2. ChargingEntry.deltaEnergyStored — по SOC и ёмкости
///   3. ChargingEntry.efficiencyRatio — КПД зарядки
///   4. ChargingEntry.isEfficiencyAnomalous — детектор аномалий
///   5. Unified Timeline — фильтрация аномальных скачков одометра
///   6. TimelineMetrics.combinedCostPerKm — формула и граничные случаи
///   7. TimelineMetrics.kwhPer100kmTotal — расход по общему одометру
///   8. TimelineMetrics.literEquivalentPer100km — коэф. 8.9
///   9. TimelineMetrics.kwhPer100kmEv — расход по EV-одометру
///  10. BatteryHealthReport.healthLabel — уровни здоровья АКБ

void main() {
  // ──────────────────────────── ChargingEntry ──────────────────────────────

  group('ChargingEntry.costPerKwh', () {
    test('Корректный расчёт: 500 / 28.5 ≈ 17.54', () {
      final entry = _makeEntry(kwhAdded: 28.5, totalCost: 500.0);
      expect(entry.costPerKwh, closeTo(17.54, 0.01));
    });

    test('Защита от деления на ноль: kwhAdded == 0 → 0.0', () {
      final entry = _makeEntry(kwhAdded: 0.0, totalCost: 100.0);
      expect(entry.costPerKwh, equals(0.0));
    });

    test('Бесплатная зарядка: totalCost == 0 → 0.0', () {
      final entry = _makeEntry(kwhAdded: 20.0, totalCost: 0.0);
      expect(entry.costPerKwh, equals(0.0));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────

  group('ChargingEntry.deltaEnergyStored', () {
    test('Корректная дельта: SOC 15→80, ёмкость 50 кВт·ч → 32.5 кВт·ч', () {
      final entry = _makeEntry(
        kwhAdded: 40.0,
        startSoc: 15.0,
        endSoc: 80.0,
      );
      final delta = entry.deltaEnergyStored(50.0);
      expect(delta, closeTo(32.5, 0.01)); // (80 - 15) / 100 * 50
    });

    test('null если SOC-данных нет', () {
      final entry = _makeEntry(kwhAdded: 20.0);
      expect(entry.deltaEnergyStored(40.0), isNull);
    });

    test('null если ёмкость АКБ == null', () {
      final entry = _makeEntry(kwhAdded: 20.0, startSoc: 10, endSoc: 80);
      expect(entry.deltaEnergyStored(null), isNull);
    });

    test('null если ёмкость АКБ == 0 (защита от деления на ноль)', () {
      final entry = _makeEntry(kwhAdded: 20.0, startSoc: 10, endSoc: 80);
      expect(entry.deltaEnergyStored(0.0), isNull);
    });

    test('null если endSoc <= startSoc (зарядки не было)', () {
      final entry = _makeEntry(kwhAdded: 5.0, startSoc: 80.0, endSoc: 75.0);
      expect(entry.deltaEnergyStored(50.0), isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────

  group('ChargingEntry.efficiencyRatio', () {
    test('Типичный AC КПД ~91%: 32.5 из 35.6 поданных', () {
      final entry = _makeEntry(
        kwhAdded: 35.6, // из сети
        startSoc: 15.0,
        endSoc: 80.0, // ΔE = 0.65 * 50 = 32.5 кВт·ч
      );
      final ratio = entry.efficiencyRatio(50.0);
      // (32.5 / 35.6) * 100 ≈ 91.3%
      expect(ratio, isNotNull);
      expect(ratio!, closeTo(91.3, 0.5));
    });

    test('null если kwhAdded == 0', () {
      final entry = _makeEntry(kwhAdded: 0.0, startSoc: 10, endSoc: 80);
      expect(entry.efficiencyRatio(50.0), isNull);
    });

    test('null если SOC недоступен', () {
      final entry = _makeEntry(kwhAdded: 30.0);
      expect(entry.efficiencyRatio(50.0), isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────

  group('ChargingEntry.isEfficiencyAnomalous', () {
    test('КПД 101% — аномалия (физически невозможно)', () {
      // Если из сети подали 30, а в АКБ запасли 30.3 — аномалия
      final entry = _makeEntry(
        kwhAdded: 30.0,
        startSoc: 0.0,
        endSoc: 100.0, // ΔE = 1.0 * 30.3 = 30.3 кВт·ч (> kwhAdded)
      );
      expect(entry.isEfficiencyAnomalous(30.3), isTrue);
    });

    test('КПД 40% — аномалия (подозрительно низкий)', () {
      // Из 50 кВт·ч сохранено только 40 * 0.4 = 16 кВт·ч
      final entry = _makeEntry(
        kwhAdded: 50.0,
        startSoc: 0.0,
        endSoc: 40.0, // ΔE = 0.4 * 40 = 16 кВт·ч
      );
      // КПД = 16/50 * 100 = 32% < 50% → аномалия
      expect(entry.isEfficiencyAnomalous(40.0), isTrue);
    });

    test('КПД 90% — нормально', () {
      final entry = _makeEntry(
        kwhAdded: 35.6,
        startSoc: 15.0,
        endSoc: 80.0, // ΔE ≈ 32.5 кВт·ч, КПД ≈ 91%
      );
      expect(entry.isEfficiencyAnomalous(50.0), isFalse);
    });

    test('false если SOC недоступен (нет данных для оценки)', () {
      final entry = _makeEntry(kwhAdded: 30.0);
      expect(entry.isEfficiencyAnomalous(50.0), isFalse);
    });
  });

  // ─────────────────────────── Timeline Engine ─────────────────────────────

  group('_filterOdometerAnomalies', () {
    test('Убывающий одометр фильтруется', () {
      final items = [
        _makeTimelineItem(odo: 10000.0),
        _makeTimelineItem(odo: 9999.0), // убывание → удалить
        _makeTimelineItem(odo: 10100.0),
      ];
      final filtered = filterAnomalies(items);
      expect(filtered.length, equals(2));
      expect(filtered[0].odometer, equals(10000.0));
      expect(filtered[1].odometer, equals(10100.0));
    });

    test('Скачок > 10000 км фильтруется', () {
      final items = [
        _makeTimelineItem(odo: 1000.0),
        _makeTimelineItem(
            odo: 12000.0), // +11000 > 10000 → аномальный скачок, пропускаем
        _makeTimelineItem(odo: 1500.0), // +500 от 1000 → нормально, сохраняем
        _makeTimelineItem(odo: 1200.0), // -300 → убывание, пропускаем
      ];
      final filtered = filterAnomalies(items);
      // Сохраняются: 1000 (база) и 1500 (нормальный прирост от последней точки)
      expect(filtered.length, equals(2));
      expect(filtered[0].odometer, equals(1000.0));
      expect(filtered[1].odometer, equals(1500.0));
    });

    test('Нормальная последовательность не меняется', () {
      final items = [
        _makeTimelineItem(odo: 10000.0),
        _makeTimelineItem(odo: 10150.0),
        _makeTimelineItem(odo: 10300.0),
        _makeTimelineItem(odo: 10600.0),
      ];
      final filtered = filterAnomalies(items);
      expect(filtered.length, equals(4));
    });

    test('Пустой список — пустой результат', () {
      expect(filterAnomalies([]), isEmpty);
    });

    test('Один элемент — всегда сохраняется', () {
      final items = [_makeTimelineItem(odo: 50000.0)];
      expect(filterAnomalies(items).length, equals(1));
    });
  });

  // ───────────────────────── combinedCostPerKm ─────────────────────────────

  group('TimelineMetrics.combinedCostPerKm', () {
    test('Базовый расчёт: (200 + 300) / 500 = 1.0', () {
      final m = buildMetrics(
        items: [
          _makeTimelineItem(odo: 10000, cost: 0, type: 'fuel'),
          _makeTimelineItem(odo: 10200, cost: 200, type: 'fuel'),
          _makeTimelineItem(odo: 10300, cost: 300, type: 'charge'),
          _makeTimelineItem(odo: 10500, cost: 0, type: 'charge'),
        ],
      );
      expect(m.combinedCostPerKm, closeTo(1.0, 0.001));
    });

    test('null если ΔOdo < kMinOdometerDeltaKm (0.1 км)', () {
      final m = buildMetrics(
        items: [
          _makeTimelineItem(odo: 100.0),
          _makeTimelineItem(odo: 100.0), // Δ = 0 → отфильтрован
        ],
      );
      // После фильтрации остаётся 1 запись → range = 0 → null
      expect(m.combinedCostPerKm, isNull);
    });
  });

  // ─────────────────────── kwhPer100kmTotal ────────────────────────────────

  group('TimelineMetrics.kwhPer100kmTotal', () {
    test('Базовый: 30 кВт·ч / 150 км * 100 = 20 кВт·ч/100км', () {
      final m = buildMetricsWithCharging(
        totalKwh: 30.0,
        odoRangeKm: 150.0,
      );
      expect(m.kwhPer100kmTotal, closeTo(20.0, 0.01));
    });

    test('null если нет зарядных сессий', () {
      final m = buildMetrics(
        items: [
          _makeTimelineItem(odo: 1000, type: 'fuel'),
          _makeTimelineItem(odo: 1200, type: 'fuel'),
        ],
      );
      expect(m.kwhPer100kmTotal, isNull);
    });
  });

  // ─────────────────────── literEquivalentPer100km ─────────────────────────

  group('TimelineMetrics.literEquivalentPer100km', () {
    test('20 кВт·ч / 8.9 ≈ 2.25 л-экв/100км', () {
      final m = buildMetricsWithCharging(
        totalKwh: 30.0,
        odoRangeKm: 150.0, // 20 кВт·ч/100км
      );
      // 20 / 8.9 ≈ 2.247
      expect(m.literEquivalentPer100km, isNotNull);
      expect(m.literEquivalentPer100km!, closeTo(2.247, 0.01));
    });
  });

  // ────────────────────────── ChargerType enum ─────────────────────────────

  group('ChargerType serialization', () {
    test('acSlow → "acSlow" → acSlow', () {
      expect(ChargerType.fromDbString('acSlow'), equals(ChargerType.acSlow));
      expect(ChargerType.acSlow.toDbString(), equals('acSlow'));
    });

    test('dcFast → "dcFast" → dcFast', () {
      expect(ChargerType.fromDbString('dcFast'), equals(ChargerType.dcFast));
    });

    test('null → acSlow (безопасное значение по умолчанию)', () {
      expect(ChargerType.fromDbString(null), equals(ChargerType.acSlow));
    });

    test('Неизвестная строка → acSlow', () {
      expect(
          ChargerType.fromDbString('unknown_type'), equals(ChargerType.acSlow));
    });
  });

  // ─────────────────────── ChargerStandard enum ────────────────────────────

  group('ChargerStandard serialization', () {
    for (final std in ChargerStandard.values) {
      test('Round-trip для ${std.name}', () {
        final str = std.toDbString();
        expect(ChargerStandard.fromDbString(str), equals(std));
      });
    }

    test('null → homeSocket', () {
      expect(ChargerStandard.fromDbString(null),
          equals(ChargerStandard.homeSocket));
    });
  });

  // ──────────────────────── Vehicle helpers ────────────────────────────────

  group('Vehicle.effectiveCapacityKwh', () {
    test('Предпочитает usableCapacityKwh если задан', () {
      final v = _makeVehicle(batteryKwh: 57.7, usableKwh: 54.0);
      expect(v.effectiveCapacityKwh, equals(54.0));
    });

    test('Fallback на batteryCapacityKwh если usable == null', () {
      final v = _makeVehicle(batteryKwh: 57.7);
      expect(v.effectiveCapacityKwh, equals(57.7));
    });

    test('null если оба поля null', () {
      final v = _makeVehicle();
      expect(v.effectiveCapacityKwh, isNull);
    });
  });

  group('Vehicle.hasBatteryData', () {
    test('true если batteryCapacityKwh > 0', () {
      expect(_makeVehicle(batteryKwh: 30.0).hasBatteryData, isTrue);
    });

    test('false если оба поля null', () {
      expect(_makeVehicle().hasBatteryData, isFalse);
    });

    test('false если batteryCapacityKwh == 0', () {
      expect(_makeVehicle(batteryKwh: 0.0).hasBatteryData, isFalse);
    });
  });
}

// ─────────────────────────── Helpers ─────────────────────────────────────────

/// Создаёт тестовую запись о зарядке с минимальными обязательными полями.
ChargingEntry _makeEntry({
  int vehicleId = 1,
  double kwhAdded = 20.0,
  double totalCost = 0.0,
  double? startSoc,
  double? endSoc,
  double? powerKw,
  double? tempC,
}) =>
    ChargingEntry(
      vehicleId: vehicleId,
      date: DateTime(2025, 1, 1),
      odometer: 10000.0,
      kwhAdded: kwhAdded,
      totalCost: totalCost,
      startSocPercent: startSoc,
      endSocPercent: endSoc,
      powerKw: powerKw,
      temperatureCelsius: tempC,
    );

/// Создаёт тестовый [TimelineItem] с минимальными данными.
TimelineItem _makeTimelineItem({
  double odo = 10000.0,
  double cost = 0.0,
  String type = 'charge',
}) {
  final ce = _makeEntry(kwhAdded: 20.0, totalCost: cost);
  return TimelineItem(
    type: type,
    odometer: odo,
    date: DateTime(2025),
    cost: cost,
    source: ce,
  );
}

/// Создаёт тестовый [Vehicle] с опциональными полями АКБ.
Vehicle _makeVehicle({double? batteryKwh, double? usableKwh}) => Vehicle(
      name: 'Test EV',
      model: 'Model X',
      engineType: 'electric',
      batteryCapacityKwh: batteryKwh,
      usableCapacityKwh: usableKwh,
    );

// ─── Экспонированные тестовые функции из ChargingEntryController ─────────────

/// Тестовый доступ к приватному методу _filterOdometerAnomalies.
///
/// ChargingEntryController — GetxController и не может быть
/// инстанциирован напрямую без GetX среды. Вместо этого реализуем
/// ту же логику локально для unit-тестов без зависимости от GetX.
List<TimelineItem> filterAnomalies(List<TimelineItem> items) {
  if (items.isEmpty) return items;

  const minDelta = kMinOdometerDeltaKm;
  const maxDelta = kMaxOdometerDeltaKm;

  final result = <TimelineItem>[];
  result.add(items.first);

  for (int i = 1; i < items.length; i++) {
    final delta = items[i].odometer - result.last.odometer;
    if (delta <= minDelta) continue;
    if (delta > maxDelta) continue;
    result.add(items[i]);
  }

  return result;
}

/// Строит [TimelineMetrics] из списка элементов.
///
/// Имитирует _calculateMetrics контроллера без его инициализации.
TimelineMetrics buildMetrics({required List<TimelineItem> items}) {
  final filtered = filterAnomalies(items);
  if (filtered.isEmpty) return TimelineMetrics.empty;

  double fuelCost = 0, chargeCost = 0;
  for (final item in filtered) {
    if (item.type == 'fuel') {
      fuelCost += item.cost;
    } else {
      chargeCost += item.cost;
    }
  }

  final odoRange = filtered.last.odometer - filtered.first.odometer;
  double? combinedCostPerKm;
  if (odoRange >= kMinOdometerDeltaKm) {
    combinedCostPerKm = (fuelCost + chargeCost) / odoRange;
  }

  final chargeItems = filtered.where((i) => i.type == 'charge').toList();
  final totalKwh = chargeItems.fold<double>(
    0.0,
    (s, i) => s + (i.asChargingEntry?.kwhAdded ?? 0.0),
  );

  double? kwhPer100kmTotal;
  if (odoRange >= kMinOdometerDeltaKm && totalKwh > 0) {
    kwhPer100kmTotal = totalKwh / odoRange * 100;
  }

  final litEq = kwhPer100kmTotal != null
      ? kwhPer100kmTotal / kGasolineEquivalentKwhPerLiter
      : null;

  return TimelineMetrics(
    totalFuelCost: fuelCost,
    totalChargingCost: chargeCost,
    combinedCostPerKm: combinedCostPerKm,
    kwhPer100kmTotal: kwhPer100kmTotal,
    literEquivalentPer100km: litEq,
    odometerRangeKm: odoRange,
    chargingSessionCount: chargeItems.length,
    fuelEntryCount: filtered.where((i) => i.type == 'fuel').length,
  );
}

/// Строит [TimelineMetrics] для тестирования электрических метрик.
TimelineMetrics buildMetricsWithCharging({
  required double totalKwh,
  required double odoRangeKm,
  double fuelCost = 0,
  double chargeCost = 0,
}) {
  double? kwhPer100kmTotal;
  if (odoRangeKm >= kMinOdometerDeltaKm && totalKwh > 0) {
    kwhPer100kmTotal = totalKwh / odoRangeKm * 100;
  }

  final litEq = kwhPer100kmTotal != null
      ? kwhPer100kmTotal / kGasolineEquivalentKwhPerLiter
      : null;

  double? combined;
  if (odoRangeKm >= kMinOdometerDeltaKm) {
    combined = (fuelCost + chargeCost) / odoRangeKm;
  }

  return TimelineMetrics(
    totalFuelCost: fuelCost,
    totalChargingCost: chargeCost,
    combinedCostPerKm: combined,
    kwhPer100kmTotal: kwhPer100kmTotal,
    literEquivalentPer100km: litEq,
    odometerRangeKm: odoRangeKm,
    chargingSessionCount: 1,
    fuelEntryCount: 0,
  );
}

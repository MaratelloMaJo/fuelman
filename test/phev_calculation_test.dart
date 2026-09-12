import 'package:flutter_test/flutter_test.dart';

import 'package:fuelman/controllers/fuel_entry_controller.dart';
import 'package:fuelman/models/fuel_entry.dart';
import 'package:fuelman/models/vehicle.dart';

/// Моковые вспомогательные функции для генерации записей
FuelEntry _makeFuelEntry({
  int? id,
  int vehicleId = 1,
  required double odometer,
  required double volume,
  bool isFullTank = true,
  double? pricePerLiter,
  double? storedTotalCost,
  DateTime? date,
}) {
  return FuelEntry(
    id: id,
    vehicleId: vehicleId,
    date: date ?? DateTime(2026, 1, 1),
    odometer: odometer,
    volume: volume,
    isFullTank: isFullTank,
    pricePerLiter: pricePerLiter,
    storedTotalCost: storedTotalCost,
    entryType: 'fuel',
    volumeUnit: 'L',
    currency: 'RUB',
  );
}

FuelEntry _makeChargeEntry({
  int? id,
  int vehicleId = 1,
  required double odometer,
  required double volume,
  bool isFullTank = true,
  double? pricePerLiter,
  double? storedTotalCost,
  DateTime? date,
}) {
  return FuelEntry(
    id: id,
    vehicleId: vehicleId,
    date: date ?? DateTime(2026, 1, 1),
    odometer: odometer,
    volume: volume,
    isFullTank: isFullTank,
    pricePerLiter: pricePerLiter,
    storedTotalCost: storedTotalCost,
    entryType: 'charge',
    volumeUnit: 'kWh',
    currency: 'RUB',
  );
}

void main() {
  group('PHEV Calculation Core — Стресс-тестирование и бизнес-логика', () {
    // ── Сценарий 1 ────────────────────────────────────────────────────────────
    test(
        'test_first_entry_no_consumption: Первая заправка фиксирует базу, расход == null',
        () {
      final entries = [
        _makeFuelEntry(id: 1, odometer: 1000.0, volume: 45.0, isFullTank: true),
      ];

      final results =
          FuelEntryController.computeEntriesWithConsumption(entries);

      expect(results.length, equals(1));
      expect(results[0].consumption, isNull,
          reason:
              'Первая заправка не имеет предыдущей точки отсчета, расход обязан быть null');
    });

    // ── Сценарий 2 ────────────────────────────────────────────────────────────
    test(
        'test_ev_charging_isolation: 3 подряд зарядки батареи между заправками бензина',
        () {
      // Имитируем реальный цикл владельца BYD Chazor:
      // Заправил полный бак -> 3 раза зарядился от розетки -> заправил полный бак
      final entries = [
        _makeFuelEntry(id: 1, odometer: 1000.0, volume: 40.0, isFullTank: true),
        _makeChargeEntry(
            id: 2, odometer: 1100.0, volume: 15.0, isFullTank: true),
        _makeChargeEntry(
            id: 3, odometer: 1200.0, volume: 14.0, isFullTank: true),
        _makeChargeEntry(
            id: 4, odometer: 1300.0, volume: 15.0, isFullTank: true),
        _makeFuelEntry(id: 5, odometer: 1500.0, volume: 35.0, isFullTank: true),
      ];

      final results =
          FuelEntryController.computeEntriesWithConsumption(entries);

      // Проверяем бензиновую цепочку
      final fuel1 = results.firstWhere((e) => e.id == 1);
      final fuel2 = results.firstWhere((e) => e.id == 5);

      expect(fuel1.consumption, isNull,
          reason: 'Первая заправка бензина — база');

      // Для fuel2: дельта одометра строго 1500 - 1000 = 500 км (а не 1500 - 1300 от зарядки!)
      // Расход: (35.0 / 500.0) * 100 = 7.0 L/100 km
      expect(fuel2.consumption, isNotNull);
      expect(fuel2.consumption, closeTo(7.0, 0.001),
          reason:
              'Бензиновая цепочка не должна учитывать одометры электрозарядок');

      // Проверяем электрическую цепочку
      final ev1 = results.firstWhere((e) => e.id == 2);
      final ev2 = results.firstWhere((e) => e.id == 3);
      final ev3 = results.firstWhere((e) => e.id == 4);

      expect(ev1.consumption, isNull, reason: 'Первая зарядка EV — база');
      // ev2: (1200 - 1100 = 100 км), 14.0 kWh -> 14.0 kWh/100km
      expect(ev2.consumption, closeTo(14.0, 0.001));
      // ev3: (1300 - 1200 = 100 км), 15.0 kWh -> 15.0 kWh/100km
      expect(ev3.consumption, closeTo(15.0, 0.001));
    });

    // ── Сценарий 3 ────────────────────────────────────────────────────────────
    test(
        'test_partial_fillup_accumulation: Классический алгоритм полного бака с буферизацией',
        () {
      // Шаг 1: Полный бак (1000 км, 45 л)
      // Шаг 2: Дозаправка (1200 км, 15 л, неполный бак) -> null
      // Шаг 3: Дозаправка (1350 км, 10 л, неполный бак) -> null
      // Шаг 4: Полный бак (1500 км, 20 л, полный бак) -> 9.0 L/100 km
      final entries = [
        _makeFuelEntry(id: 1, odometer: 1000.0, volume: 45.0, isFullTank: true),
        _makeFuelEntry(
            id: 2, odometer: 1200.0, volume: 15.0, isFullTank: false),
        _makeFuelEntry(
            id: 3, odometer: 1350.0, volume: 10.0, isFullTank: false),
        _makeFuelEntry(id: 4, odometer: 1500.0, volume: 20.0, isFullTank: true),
      ];

      final results =
          FuelEntryController.computeEntriesWithConsumption(entries);

      expect(results[0].consumption, isNull,
          reason: 'Шаг 1: базовый полный бак');
      expect(results[1].consumption, isNull,
          reason: 'Шаг 2: дозаправка — расход null');
      expect(results[2].consumption, isNull,
          reason: 'Шаг 3: дозаправка — расход null');

      // Шаг 4: Дельта = 1500 - 1000 = 500 км. Всего топлива = 20 + (15 + 10) = 45 л.
      // Итоговый расход = (45 / 500) * 100 = 9.0 L/100 km.
      expect(results[3].consumption, isNotNull);
      expect(results[3].consumption, closeTo(9.0, 0.001),
          reason:
              'Расход на шаге 4 обязан аккумулировать все промежуточные дозаправки');
    });

    // ── Сценарий 4 ────────────────────────────────────────────────────────────
    test(
        'test_zero_distance_fuel_burn: Заправка при дельте 0 км (стоянка с генератором)',
        () {
      final entries = [
        _makeFuelEntry(id: 1, odometer: 1000.0, volume: 45.0, isFullTank: true),
        _makeFuelEntry(id: 2, odometer: 1000.0, volume: 10.0, isFullTank: true),
      ];

      final results =
          FuelEntryController.computeEntriesWithConsumption(entries);

      expect(results[1].consumption, isNull,
          reason:
              'Дельта 0 км не должна приводить к делению на 0, Infinity или NaN');
      expect(results[1].consumption?.isNaN ?? false, isFalse);
      expect(results[1].consumption?.isInfinite ?? false, isFalse);
    });

    // ── Сценарий 5 ────────────────────────────────────────────────────────────
    test(
        'test_cost_per_km_integrity: Проверка совокупной стоимости 1 км пути при смешанном цикле',
        () {
      // 1000 км -> 1800 км = 800 км дельта
      // Бензин 1: 1000 км, 40 л * 50 руб = 2000 руб
      // Зарядка 1: 1200 км, 15 кВт·ч * 10 руб = 150 руб
      // Бензин 2: 1500 км, 30 л * 50 руб = 1500 руб
      // Зарядка 2: 1800 км, 15 кВт·ч * 10 руб = 150 руб
      // Сумма денег = 2000 + 150 + 1500 + 150 = 3800 руб
      // TCO = 3800 / 800 = 4.75 руб/км
      final entries = [
        _makeFuelEntry(
          id: 1,
          odometer: 1000.0,
          volume: 40.0,
          pricePerLiter: 50.0,
          storedTotalCost: 2000.0,
        ),
        _makeChargeEntry(
          id: 2,
          odometer: 1200.0,
          volume: 15.0,
          pricePerLiter: 10.0,
          storedTotalCost: 150.0,
        ),
        _makeFuelEntry(
          id: 3,
          odometer: 1500.0,
          volume: 30.0,
          pricePerLiter: 50.0,
          storedTotalCost: 1500.0,
        ),
        _makeChargeEntry(
          id: 4,
          odometer: 1800.0,
          volume: 15.0,
          pricePerLiter: 10.0,
          storedTotalCost: 150.0,
        ),
      ];

      final costPerKm = FuelEntryController.calculateCostPerKm(entries);
      expect(costPerKm, isNotNull);
      expect(costPerKm, closeTo(4.75, 0.001));

      final stats = FuelEntryController.calculateOverallStats(entries);
      expect(stats.costPerKm, closeTo(4.75, 0.001));
      expect(stats.totalDistance, equals(800.0));
      expect(stats.totalCost, equals(3800.0));
    });

    // ── Сценарий 6: Micro-delta guard (< 15 км) ───────────────────────────────
    test(
        'test_micro_distance_guard: Пробег < 15 км блокирует расчет удельного расхода',
        () {
      final entries = [
        _makeFuelEntry(id: 1, odometer: 1000.0, volume: 45.0, isFullTank: true),
        // Проехали всего 10 км (прогрев / стоянка в пробке), залили 5 л
        _makeFuelEntry(id: 2, odometer: 1010.0, volume: 5.0, isFullTank: true),
      ];

      final results =
          FuelEntryController.computeEntriesWithConsumption(entries);

      expect(results[1].consumption, isNull,
          reason:
              'Дельта 10 км < 15 км должна блокировать расчёт аномального расхода (50 л/100 км)');
    });

    // ── Сценарий 7: Защита физических лимитов BYD Chazor ─────────────────────
    test(
        'test_chazor_volume_limits_validation: Лимиты 53 л для бака и 22 кВт·ч для батареи Chazor',
        () {
      const chazor = Vehicle(
        name: 'BYD',
        model: 'Chazor DM-i',
        engineType: 'hybrid',
        hybridType: 'PHEV',
        batteryCapacityKwh: 18.3,
      );

      final maxFuel =
          FuelEntryController.getMaxAllowedVolume('fuel', vehicle: chazor);
      final maxEv =
          FuelEntryController.getMaxAllowedVolume('charge', vehicle: chazor);

      expect(maxFuel, equals(53.0),
          reason: 'Номинал 48 л + 10% горловина = 53 л');
      expect(maxEv, equals(22.0),
          reason: 'Номинал 18.3 кВт·ч + потери = 22 кВт·ч');

      // Проверка предупреждений
      final normalWarning = FuelEntryController.checkAnomalyWarning(
        odometer: 1500,
        volume: 45.0,
        prevOdometer: 1000,
        entryType: 'fuel',
        vehicle: chazor,
      );
      expect(normalWarning, isNull, reason: '45 л < 53 л — норма');

      final overFuelWarning = FuelEntryController.checkAnomalyWarning(
        odometer: 1500,
        volume: 55.0,
        prevOdometer: 1000,
        entryType: 'fuel',
        vehicle: chazor,
      );
      expect(overFuelWarning, equals(AnomalyWarning.volumeTooLarge),
          reason: '55 л > 53 л — предупреждение о физической аномалии');

      final overEvWarning = FuelEntryController.checkAnomalyWarning(
        odometer: 1500,
        volume: 25.0,
        prevOdometer: 1000,
        entryType: 'charge',
        vehicle: chazor,
      );
      expect(overEvWarning, equals(AnomalyWarning.volumeTooLarge),
          reason:
              '25 кВт·ч > 22 кВт·ч — превышение емкости батареи с потерями');
    });

    // ── Сценарий 8: Несколько дозаправок до первой полной ─────────────────────
    test(
        'test_partials_before_first_full: Дозаправки до первого полного бака не крашат расчет',
        () {
      final entries = [
        _makeFuelEntry(id: 1, odometer: 100.0, volume: 10.0, isFullTank: false),
        _makeFuelEntry(id: 2, odometer: 200.0, volume: 15.0, isFullTank: false),
        _makeFuelEntry(id: 3, odometer: 400.0, volume: 45.0, isFullTank: true),
        _makeFuelEntry(id: 4, odometer: 900.0, volume: 35.0, isFullTank: true),
      ];

      final results =
          FuelEntryController.computeEntriesWithConsumption(entries);

      expect(results[0].consumption, isNull);
      expect(results[1].consumption, isNull);
      expect(results[2].consumption, isNull,
          reason: 'Первый полный бак — это anchor/базовая точка');
      // Четвертый: дельта 900 - 400 = 500 км, объем 35 л -> 7.0 L/100km
      expect(results[3].consumption, closeTo(7.0, 0.001));
    });

    // ── Сценарий 9: Хвостовые дозаправки после последней полной ────────────────
    test(
        'test_tail_partials_after_last_full: Хвостовые дозаправки всегда имеют consumption == null',
        () {
      final entries = [
        _makeFuelEntry(id: 1, odometer: 1000.0, volume: 45.0, isFullTank: true),
        _makeFuelEntry(id: 2, odometer: 1500.0, volume: 40.0, isFullTank: true),
        _makeFuelEntry(
            id: 3, odometer: 1700.0, volume: 15.0, isFullTank: false),
        _makeFuelEntry(
            id: 4, odometer: 1850.0, volume: 10.0, isFullTank: false),
      ];

      final results =
          FuelEntryController.computeEntriesWithConsumption(entries);

      expect(results[1].consumption, closeTo(8.0, 0.001));
      expect(results[2].consumption, isNull,
          reason: 'Хвостовая дозаправка — null');
      expect(results[3].consumption, isNull,
          reason: 'Хвостовая дозаправка — null');
    });

    // ── Сценарий 10: Раздельная сводная статистика для гибрида ────────────────
    test(
        'test_overall_stats_separation: Раздельный средний расход бензина и электричества',
        () {
      final entries = [
        _makeFuelEntry(id: 1, odometer: 1000.0, volume: 40.0, isFullTank: true),
        _makeChargeEntry(
            id: 2, odometer: 1000.0, volume: 15.0, isFullTank: true),
        _makeFuelEntry(
            id: 3,
            odometer: 1500.0,
            volume: 30.0,
            isFullTank: true), // 6.0 L/100km
        _makeChargeEntry(
            id: 4,
            odometer: 1100.0,
            volume: 15.0,
            isFullTank: true), // 15.0 kWh/100km
      ];

      final computed =
          FuelEntryController.computeEntriesWithConsumption(entries);
      final stats = FuelEntryController.calculateOverallStats(computed);

      expect(stats.avgFuelConsumption, closeTo(6.0, 0.001));
      expect(stats.avgEvConsumption, closeTo(15.0, 0.001));
    });

    // ── Сценарий 11: Пользовательский объем бака (tankCapacity) ────────────────
    test(
        'test_user_defined_tank_capacity: Пользовательский объем бака управляет валидацией',
        () {
      const customCar = Vehicle(
        name: 'Toyota',
        model: 'Camry',
        engineType: 'petrol',
        tankCapacity: 50.0,
      );

      final nominal =
          FuelEntryController.getNominalCapacity('fuel', vehicle: customCar);
      final maxFuel =
          FuelEntryController.getMaxAllowedVolume('fuel', vehicle: customCar);

      expect(nominal, equals(50.0));
      expect(maxFuel, equals(55.0), reason: '50.0 л + 10% горловина = 55.0 л');

      // 52 л укладывается в 55 л (горловина)
      final okWarn = FuelEntryController.checkAnomalyWarning(
        odometer: 1500,
        volume: 52.0,
        prevOdometer: 1000,
        entryType: 'fuel',
        vehicle: customCar,
      );
      expect(okWarn, isNull);

      // 56 л превышает 55 л -> AnomalyWarning.volumeTooLarge
      final overWarn = FuelEntryController.checkAnomalyWarning(
        odometer: 1500,
        volume: 56.0,
        prevOdometer: 1000,
        entryType: 'fuel',
        vehicle: customCar,
      );
      expect(overWarn, equals(AnomalyWarning.volumeTooLarge));
    });

    // ── Сценарий 12: Пресеты брендов (Lixiang, Geely, Tank, Chery, Haval) ──────
    test(
        'test_multi_brand_presets: Проверка авто-определения емкостей для Lixiang, Geely, Tank, etc.',
        () {
      // 1. Lixiang L7/L9 (Li Auto)
      const lixiang = Vehicle(
        name: 'Li Auto',
        model: 'L9 Max',
        engineType: 'hybrid',
        hybridType: 'PHEV',
      );
      expect(FuelEntryController.getNominalCapacity('fuel', vehicle: lixiang),
          equals(65.0));
      expect(FuelEntryController.getMaxAllowedVolume('fuel', vehicle: lixiang),
          equals(72.0)); // ceil(65 * 1.1) = 72

      // 2. Geely Monjaro
      const geelyMonjaro = Vehicle(
        name: 'Geely',
        model: 'Monjaro 2.0T',
        engineType: 'petrol',
      );
      expect(
          FuelEntryController.getNominalCapacity('fuel', vehicle: geelyMonjaro),
          equals(62.0));
      expect(
          FuelEntryController.getMaxAllowedVolume('fuel',
              vehicle: geelyMonjaro),
          equals(69.0)); // ceil(62 * 1.1) = 69

      // 3. Geely Coolray
      const geelyCoolray = Vehicle(
        name: 'Geely',
        model: 'Coolray',
        engineType: 'petrol',
      );
      expect(
          FuelEntryController.getNominalCapacity('fuel', vehicle: geelyCoolray),
          equals(45.0));
      expect(
          FuelEntryController.getMaxAllowedVolume('fuel',
              vehicle: geelyCoolray),
          equals(50.0)); // ceil(45 * 1.1) = 50

      // 4. Geely Galaxy L7 (PHEV)
      const geelyGalaxy = Vehicle(
        name: 'Geely',
        model: 'Galaxy L7',
        engineType: 'hybrid',
        hybridType: 'PHEV',
      );
      expect(
          FuelEntryController.getNominalCapacity('fuel', vehicle: geelyGalaxy),
          equals(60.0));
      expect(
          FuelEntryController.getNominalCapacity('charge',
              vehicle: geelyGalaxy),
          equals(18.7));

      // 5. Tank 300 / 500
      const tank500 = Vehicle(
        name: 'Great Wall Tank',
        model: 'Tank 500',
        engineType: 'petrol',
      );
      expect(FuelEntryController.getNominalCapacity('fuel', vehicle: tank500),
          equals(80.0));
      expect(FuelEntryController.getMaxAllowedVolume('fuel', vehicle: tank500),
          equals(88.0)); // ceil(80 * 1.1) = 88

      // 6. Chery Tiggo 8 Pro
      const chery = Vehicle(
        name: 'Chery',
        model: 'Tiggo 8 Pro Max',
        engineType: 'petrol',
      );
      expect(FuelEntryController.getNominalCapacity('fuel', vehicle: chery),
          equals(57.0));

      // 7. Haval Jolion
      const haval = Vehicle(
        name: 'Haval',
        model: 'Jolion',
        engineType: 'petrol',
      );
      expect(FuelEntryController.getNominalCapacity('fuel', vehicle: haval),
          equals(60.0));
    });

    // ── Сценарий 13: Приоритет пользовательского ввода над пресетами ───────────
    test(
        'test_user_capacity_overrides_preset: Заданный пользователем объем бака имеет наивысший приоритет',
        () {
      // Пользователь вручную указал 70 л на Geely Monjaro (где стандартный пресет 62 л)
      const customMonjaro = Vehicle(
        name: 'Geely',
        model: 'Monjaro',
        engineType: 'petrol',
        tankCapacity: 70.0,
      );

      final nominal = FuelEntryController.getNominalCapacity('fuel',
          vehicle: customMonjaro);
      final maxAllowed = FuelEntryController.getMaxAllowedVolume('fuel',
          vehicle: customMonjaro);

      expect(nominal, equals(70.0),
          reason: 'Пользовательский ввод должен перекрывать пресет');
      expect(maxAllowed, equals(77.0), reason: '70.0 * 1.1 = 77.0');
    });
  });
}

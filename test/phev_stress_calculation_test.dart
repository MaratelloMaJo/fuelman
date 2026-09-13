import 'package:flutter_test/flutter_test.dart';
import 'package:fuelman/controllers/fuel_entry_controller.dart';
import 'package:fuelman/models/fuel_entry.dart';
import 'package:fuelman/models/vehicle.dart';

void main() {
  group('PHEV Stress Calculation Test Suite', () {
    // ── Тест 1: Первая заправка любого типа ──────────────────────────────────
    test(
        'test_first_fillup_no_consumption: Первая заправка любого типа возвращает null для расхода',
        () {
      final entries = [
        FuelEntry(
          vehicleId: 1,
          date: DateTime(2025, 1, 1),
          odometer: 1000.0,
          volume: 45.0,
          isFullTank: true,
          entryType: 'fuel',
        ),
        FuelEntry(
          vehicleId: 1,
          date: DateTime(2025, 1, 2),
          odometer: 1000.0,
          volume: 15.0,
          isFullTank: true,
          entryType: 'charge',
        ),
      ];

      final result = FuelEntryController.computeEntriesWithConsumption(entries);

      expect(result[0].consumption, isNull,
          reason:
              'Первая заправка топлива не имеет базы отсчета, расход должен быть null');
      expect(result[1].consumption, isNull,
          reason:
              'Первая зарядка АКБ не имеет базы отсчета, расход должен быть null');
    });

    // ── Тест 2: Защита от перелива бака ──────────────────────────────────────
    test(
        'test_overflow_tank_validation: Попытка сохранить 65 л при баке 48 л возвращает ошибку валидации',
        () {
      const vehicle = Vehicle(
        name: 'BYD',
        model: 'Chazor',
        engineType: 'hybrid',
        hybridType: 'PHEV',
        tankCapacity: 48.0,
        batteryCapacityKwh: 18.3,
      );

      // Попытка залить 65 л при баке 48 л (лимит с горловиной 10% = 53 л)
      final error = FuelEntryController.validateEntryVolume(
        volume: 65.0,
        entryType: 'fuel',
        vehicle: vehicle,
      );

      expect(error, isNotNull,
          reason: '65 л превышает бак 48 л с учетом горловины');
      expect(error, contains('превышает емкость бака с учетом горловины'));

      // Валидный объем 45 л
      final valid = FuelEntryController.validateEntryVolume(
        volume: 45.0,
        entryType: 'fuel',
        vehicle: vehicle,
      );
      expect(valid, isNull, reason: '45 л укладывается в емкость бака');
    });

    // ── Тест 3: Защита от перезаряда батареи ─────────────────────────────────
    test(
        'test_overflow_battery_validation: Попытка сохранить 45 кВт·ч при батарее 18.3 кВт·ч возвращает ошибку валидации',
        () {
      const vehicle = Vehicle(
        name: 'BYD',
        model: 'Chazor',
        engineType: 'hybrid',
        hybridType: 'PHEV',
        tankCapacity: 48.0,
        batteryCapacityKwh: 18.3,
      );

      // Попытка зарядить 45 кВт·ч при батарее 18.3 кВт·ч (лимит с потерями 20% = 22 кВт·ч)
      final error = FuelEntryController.validateEntryVolume(
        volume: 45.0,
        entryType: 'charge',
        vehicle: vehicle,
      );

      expect(error, isNotNull,
          reason: '45 кВт·ч превышает АКБ 18.3 кВт·ч с потерями');
      expect(error, contains('превышает физическую емкость батареи'));

      // Валидная зарядка 16 кВт·ч
      final valid = FuelEntryController.validateEntryVolume(
        volume: 16.0,
        entryType: 'charge',
        vehicle: vehicle,
      );
      expect(valid, isNull,
          reason: '16 кВт·ч укладывается в физическую емкость батареи');
    });

    // ── Тест 4: Защита от микропробегов ──────────────────────────────────────
    test(
        'test_micro_distance_no_infinite_consumption: Пробег 1 км и заправка 10 л возвращает null вместо 1000 л/100 км',
        () {
      final entries = [
        FuelEntry(
          vehicleId: 1,
          date: DateTime(2025, 1, 1, 10),
          odometer: 1000.0,
          volume: 40.0,
          isFullTank: true,
          entryType: 'fuel',
        ),
        FuelEntry(
          vehicleId: 1,
          date: DateTime(2025, 1, 1, 12),
          odometer: 1001.0, // Дельта 1 км < 15 км
          volume: 10.0,
          isFullTank: true,
          entryType: 'fuel',
        ),
      ];

      final result = FuelEntryController.computeEntriesWithConsumption(entries);

      expect(result[1].consumption, isNull,
          reason:
              'Дельта 1 км < 15 км блокирует расчет аномального расхода (1000 л/100 км)');
    });

    // ── Тест 5: Изоляция цепочек PHEV ────────────────────────────────────────
    test('test_isolated_chains_phev: Изоляция цепочек бензина и электричества',
        () {
      final entries = [
        // Бензин: Полный бак (1000 км, 40 л)
        FuelEntry(
          vehicleId: 1,
          date: DateTime(2025, 1, 1, 8),
          odometer: 1000.0,
          volume: 40.0,
          isFullTank: true,
          entryType: 'fuel',
        ),
        // Зарядка: Полный заряд (1050 км, 15 кВт·ч)
        FuelEntry(
          vehicleId: 1,
          date: DateTime(2025, 1, 2, 8),
          odometer: 1050.0,
          volume: 15.0,
          isFullTank: true,
          entryType: 'charge',
        ),
        // Зарядка: Полный заряд (1100 км, 14 кВт·ч)
        FuelEntry(
          vehicleId: 1,
          date: DateTime(2025, 1, 3, 8),
          odometer: 1100.0,
          volume: 14.0,
          isFullTank: true,
          entryType: 'charge',
        ),
        // Бензин: Полный бак (1400 км, 20 л)
        FuelEntry(
          vehicleId: 1,
          date: DateTime(2025, 1, 4, 8),
          odometer: 1400.0,
          volume: 20.0,
          isFullTank: true,
          entryType: 'fuel',
        ),
      ];

      final result = FuelEntryController.computeEntriesWithConsumption(entries);

      // Проверка бензина: Дельта = 1400 - 1000 = 400 км, расход = (20 / 400) * 100 = 5.0 л/100 км
      expect(result[0].consumption, isNull, reason: 'Первая заправка бензина');
      expect(result[3].consumption, isNotNull);
      expect(result[3].consumption!, closeTo(5.0, 0.001),
          reason:
              'Дельта бензина = 400 км, расход = 5.0 л/100 км. Электричество не смешалось с бензином');

      // Проверка электричества:
      // Первая зарядка (1050 км) -> null
      expect(result[1].consumption, isNull, reason: 'Первая зарядка АКБ');
      // Вторая зарядка (1100 км) -> дельта = 1100 - 1050 = 50 км, расход = (14 / 50) * 100 = 28.0 кВт·ч/100 км
      expect(result[2].consumption, isNotNull);
      expect(result[2].consumption!, closeTo(28.0, 0.001),
          reason: 'Дельта зарядки = 50 км, расход = 28.0 кВт·ч/100 км');
    });

    // ── Тест 6: Накопление промежуточных дозаправок ──────────────────────────
    test(
        'test_partial_fillups_chain_accumulation: Накопление объема частичных заправок до полного бака',
        () {
      final entries = [
        // 1000 км: Полный бак (40 л)
        FuelEntry(
          vehicleId: 1,
          date: DateTime(2025, 1, 1),
          odometer: 1000.0,
          volume: 40.0,
          isFullTank: true,
          entryType: 'fuel',
        ),
        // 1150 км: Частичная заправка (10 л) -> расход null
        FuelEntry(
          vehicleId: 1,
          date: DateTime(2025, 1, 2),
          odometer: 1150.0,
          volume: 10.0,
          isFullTank: false,
          entryType: 'fuel',
        ),
        // 1300 км: Частичная заправка (15 л) -> расход null
        FuelEntry(
          vehicleId: 1,
          date: DateTime(2025, 1, 3),
          odometer: 1300.0,
          volume: 15.0,
          isFullTank: false,
          entryType: 'fuel',
        ),
        // 1500 км: Полный бак (25 л) -> дельта = 500 км, общий объем = 10 + 15 + 25 = 50 л. Расход = 10.0 л/100 км
        FuelEntry(
          vehicleId: 1,
          date: DateTime(2025, 1, 4),
          odometer: 1500.0,
          volume: 25.0,
          isFullTank: true,
          entryType: 'fuel',
        ),
      ];

      final result = FuelEntryController.computeEntriesWithConsumption(entries);

      expect(result[0].consumption, isNull, reason: 'Базовый полный бак');
      expect(result[1].consumption, isNull,
          reason: 'Дозаправка 1 — расход null');
      expect(result[2].consumption, isNull,
          reason: 'Дозаправка 2 — расход null');
      expect(result[3].consumption, isNotNull);
      expect(result[3].consumption!, closeTo(10.0, 0.001),
          reason:
              'Дельта = 500 км, объем = 10 + 15 + 25 = 50 л, расход = 10.0 л/100 км');
    });

    // ── Тест 7: Заправка при нулевой дельте пробега ───────────────────────────
    test(
        'test_zero_distance_fuel_burn: Заправка при неизменном одометре возвращает null без деления на ноль',
        () {
      final entries = [
        FuelEntry(
          vehicleId: 1,
          date: DateTime(2025, 1, 1, 8),
          odometer: 1000.0,
          volume: 40.0,
          isFullTank: true,
          entryType: 'fuel',
        ),
        // Работа генератора на стоянке / перепарковка
        FuelEntry(
          vehicleId: 1,
          date: DateTime(2025, 1, 1, 14),
          odometer: 1000.0, // Дельта 0 км
          volume: 12.0,
          isFullTank: true,
          entryType: 'fuel',
        ),
      ];

      final result = FuelEntryController.computeEntriesWithConsumption(entries);

      expect(result[1].consumption, isNull,
          reason: 'При дельте 0 км расход null, деление на 0 предотвращено');
    });

    // ── Тест 8: Синхронизация цен и авторасчет ────────────────────────────────
    test(
        'test_price_synchronization: Проверка авторасчета totalCost и пересчета цены за литр при вводе чека',
        () {
      // 1. Авторасчет totalCost = volume * unitPrice
      final calcTotal = FuelEntryController.calculatePriceSync(
        volume: 50.0,
        unitPrice: 62.5,
      );
      expect(calcTotal.unitPrice, equals(62.5));
      expect(calcTotal.totalCost, equals(3125.0));

      // 2. Пересчет unitPrice = totalCost / volume при ручном вводе суммы чека
      final calcUnitPrice = FuelEntryController.calculatePriceSync(
        volume: 40.0,
        totalCost: 2500.0,
        preferTotalCost: true,
      );
      expect(calcUnitPrice.unitPrice, equals(62.5));
      expect(calcUnitPrice.totalCost, equals(2500.0));

      // 3. Проверка расчетного геттера totalCost в модели FuelEntry
      final entryFromUnitPrice = FuelEntry(
        vehicleId: 1,
        date: DateTime(2025, 1, 1),
        odometer: 1000.0,
        volume: 40.0,
        pricePerLiter: 60.0,
      );
      expect(entryFromUnitPrice.totalCost, equals(2400.0));

      final entryWithReceipt = FuelEntry(
        vehicleId: 1,
        date: DateTime(2025, 1, 1),
        odometer: 1000.0,
        volume: 40.0,
        pricePerLiter: 58.5,
        storedTotalCost: 2340.0,
      );
      expect(entryWithReceipt.totalCost, equals(2340.0),
          reason: 'storedTotalCost имеет абсолютный приоритет');
    });
  });
}

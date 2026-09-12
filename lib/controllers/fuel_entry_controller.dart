import 'dart:io';

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/fuel_database.dart';
import '../models/fuel_entry.dart';
import '../models/vehicle.dart';
import '../services/notification_service.dart';
import '../services/currency_service.dart';
import 'settings_controller.dart';
import 'vehicle_controller.dart';

// ─────────────────────────── Constants ──────────────────────────────────────

/// Минимальное расстояние в км для достоверного расчёта расхода (Zero & Micro-delta guard).
/// Если разница одометра меньше 15 км — удельный расход не рассчитывается (null).
const double kMinDistanceKm = 15.0;

/// Максимальный «разумный» расход топлива л/100 км.
const double kMaxReasonableConsumptionFuel = 50.0;

/// Минимальный «разумный» расход топлива л/100 км.
const double kMinReasonableConsumptionFuel = 1.0;

/// Максимальный «разумный» расход электроэнергии кВт·ч/100 км.
const double kMaxReasonableConsumptionEv = 80.0;

/// Минимальный «разумный» расход электроэнергии кВт·ч/100 км.
const double kMinReasonableConsumptionEv = 4.0;

/// Максимально допустимый разовый объём топлива в литрах (общий лимит).
const double kMaxSingleFuelVolume = 250.0;

/// Максимально допустимый разовый объём зарядки кВт·ч (общий лимит).
const double kMaxSingleEvVolume = 300.0;

/// Лимиты емкостей для BYD Chazor / Destroyer 05
const double kChazorFuelTankNominal = 48.0;
const double kChazorFuelTankMax = 53.0; // 48 л + 10% запас горловины
const double kChazorBatteryNominal = 18.3;
const double kChazorBatteryMax = 22.0; // 18.3 кВт·ч + потери зарядки

/// Порог «очень большого» расстояния (предупреждение о возможной ошибке ввода).
const double kMaxWarningDistanceKm = 3000.0;

// ─────────────────────── Overall PHEV Stats Model ───────────────────────────

/// Комбинированная сводная статистика для PHEV / гибридов и обычных авто.
class PhevOverallStats {
  /// Чистый средний расход бензина по методу Full-to-Full (L/100 km).
  final double? avgFuelConsumption;

  /// Средний расход энергии батареи (kWh/100 km).
  final double? avgEvConsumption;

  /// Общая совокупная стоимость 1 км пути (TCO):
  /// (Все потраченные деньги на бензин + Все потраченные деньги на зарядку) / (MaxOdo - MinOdo).
  final double? costPerKm;

  final double totalFuelVolume;
  final double totalEvVolume;
  final double totalCost;
  final double? totalDistance;
  final double? minConsumption;
  final double? maxConsumption;
  final int totalEntries;
  final int calcEntries;
  final double? kmPerDay;
  final double? costPerDay;

  const PhevOverallStats({
    this.avgFuelConsumption,
    this.avgEvConsumption,
    this.costPerKm,
    this.totalFuelVolume = 0.0,
    this.totalEvVolume = 0.0,
    this.totalCost = 0.0,
    this.totalDistance,
    this.minConsumption,
    this.maxConsumption,
    this.totalEntries = 0,
    this.calcEntries = 0,
    this.kmPerDay,
    this.costPerDay,
  });

  Map<String, double?> toMap() => {
        'min_consumption': minConsumption,
        'max_consumption': maxConsumption,
        'avg_consumption': avgFuelConsumption,
        'avg_ev_consumption': avgEvConsumption,
        'total_volume': totalFuelVolume,
        'total_ev_volume': totalEvVolume,
        'total_cost': totalCost,
        'total_entries': totalEntries.toDouble(),
        'calc_entries': calcEntries.toDouble(),
        'cost_per_km': costPerKm,
        'km_per_day': kmPerDay,
        'cost_per_day': costPerDay,
        'total_distance': totalDistance,
      };
}

// ─────────────────────────── Controller ─────────────────────────────────────

/// Контроллер записей о заправках и зарядках для ДВС, электромобилей и PHEV.
///
/// Ключевая ответственность:
///   — Изолированные цепочки для топлива и электричества (Isolated Chains)
///   — Классический алгоритм полного бака с накоплением дозаправок (Full-to-Full Accumulation)
///   — Защита от микропробегов (< 15 км) и деления на 0 (Zero & Micro-delta guard)
///   — Защита от физических аномалий емкости бака (Chazor 53 л) и батареи (22 кВт·ч)
///   — Корректность пересчета цен и затрат
///   — Комбинированная сводная статистика (TCO, L/100km, kWh/100km)
class FuelEntryController extends GetxController {
  final entries = <FuelEntry>[].obs;
  final stats = <String, double?>{}.obs;
  final isLoading = false.obs;

  /// Множество id записей, у которых расход помечен как аномальный.
  final anomalousIds = <int>{}.obs;

  VehicleController? get _vehicleCtrl => Get.isRegistered<VehicleController>()
      ? Get.find<VehicleController>()
      : null;

  @override
  void onInit() {
    super.onInit();
    final vc = _vehicleCtrl;
    if (vc != null) {
      ever(vc.selectedVehicle, (_) => _onVehicleChanged());
      _onVehicleChanged();
    }

    if (Get.isRegistered<SettingsController>()) {
      final settings = Get.find<SettingsController>();
      ever(settings.currency, (_) => _recalcStatsCurrentVehicle());
      ever(settings.volumeUnit, (_) => _recalcStatsCurrentVehicle());
    }
  }

  void _recalcStatsCurrentVehicle() {
    final v = _vehicleCtrl?.selectedVehicle.value;
    if (v != null) {
      _loadStats(v.id!);
    }
  }

  void _onVehicleChanged() {
    final v = _vehicleCtrl?.selectedVehicle.value;
    if (v != null) {
      loadEntries(v.id!);
    } else {
      entries.clear();
      stats.clear();
      anomalousIds.clear();
    }
  }

  // ───────────────────────────────────────── Load ──

  Future<void> loadEntries(int vehicleId) async {
    isLoading.value = true;
    try {
      final list = await FuelDatabase.instance.getEntries(vehicleId);
      entries.assignAll(list);
      _rebuildAnomalousSet(list);
      await _loadStats(vehicleId);
    } finally {
      isLoading.value = false;
    }
  }

  void _rebuildAnomalousSet(List<FuelEntry> list) {
    final Set<int> newSet = {};
    for (final e in list) {
      if (e.id != null && e.consumption != null) {
        if (isAnomalousConsumption(e.consumption!, e.entryType)) {
          newSet.add(e.id!);
        }
      }
    }
    anomalousIds.assignAll(newSet);
  }

  /// Возвращает true, если значение расхода аномально.
  bool isAnomalousConsumption(double value, String entryType) =>
      isAnomalousValue(value, entryType);

  static bool isAnomalousValue(double value, String entryType) {
    if (entryType == 'charge') {
      return value < kMinReasonableConsumptionEv ||
          value > kMaxReasonableConsumptionEv;
    }
    return value < kMinReasonableConsumptionFuel ||
        value > kMaxReasonableConsumptionFuel;
  }

  bool isEntryAnomalous(int? id) => id != null && anomalousIds.contains(id);

  // ─────────────────────────────── Stats ──

  Future<void> _loadStats(int vehicleId) async {
    final all = await FuelDatabase.instance.getEntries(vehicleId);
    final settings = Get.find<SettingsController>();
    final currencySvc = CurrencyService.instance;

    final overall = calculateOverallStats(
      all,
      currencySvc: currencySvc,
      targetCurrency: settings.currency.value,
      settings: settings,
    );

    stats.assignAll(overall.toMap());
  }

  /// Расчёт комбинированной сводной статистики гибрида/авто.
  static PhevOverallStats calculateOverallStats(
    List<FuelEntry> all, {
    CurrencyService? currencySvc,
    String targetCurrency = 'RUB',
    SettingsController? settings,
  }) {
    if (all.isEmpty) return const PhevOverallStats();

    final cSvc = currencySvc ?? CurrencyService.instance;

    double minFuelCons = double.infinity;
    double maxFuelCons = 0.0;
    double sumFuelCons = 0.0;
    int calcFuelEntries = 0;

    double sumEvCons = 0.0;
    int calcEvEntries = 0;

    double totalFuelVolume = 0.0;
    double totalEvVolume = 0.0;
    double totalCost = 0.0;

    DateTime? firstDate;
    DateTime? lastDate;
    double minOdo = double.infinity;
    double maxOdo = 0.0;

    for (final e in all) {
      if (firstDate == null || e.date.isBefore(firstDate)) firstDate = e.date;
      if (lastDate == null || e.date.isAfter(lastDate)) lastDate = e.date;
      if (e.odometer < minOdo) minOdo = e.odometer;
      if (e.odometer > maxOdo) maxOdo = e.odometer;

      if (e.entryType == 'fuel') {
        double vol = e.volume;
        if (settings != null) {
          vol = settings.convertVolume(
              e.volume, e.volumeUnit, settings.volumeUnit.value);
        }
        totalFuelVolume += vol;
      } else if (e.entryType == 'charge') {
        totalEvVolume += e.volume;
      }

      final cost = e.totalCost ?? 0.0;
      final convertedCost = cSvc.convert(cost, e.currency, targetCurrency);
      totalCost += convertedCost;

      if (e.consumption != null) {
        final isAnomaly = isAnomalousValue(e.consumption!, e.entryType);
        if (!isAnomaly) {
          if (e.entryType == 'fuel') {
            double cons = e.consumption!;
            if (settings != null) {
              cons = settings.convertVolume(
                  e.consumption!, e.volumeUnit, settings.volumeUnit.value);
            }
            if (cons < minFuelCons) minFuelCons = cons;
            if (cons > maxFuelCons) maxFuelCons = cons;
            sumFuelCons += cons;
            calcFuelEntries++;
          } else if (e.entryType == 'charge') {
            sumEvCons += e.consumption!;
            calcEvEntries++;
          }
        }
      }
    }

    final avgFuel = calcFuelEntries > 0 ? sumFuelCons / calcFuelEntries : null;
    final avgEv = calcEvEntries > 0 ? sumEvCons / calcEvEntries : null;

    double? costPerKm;
    double? kmPerDay;
    double? costPerDay;
    double? totalDistance;

    if (all.length >= 2 && minOdo < double.infinity && maxOdo > 0) {
      final distance = maxOdo - minOdo;
      if (distance > 0) {
        costPerKm = totalCost / distance;
        totalDistance = distance;
      }
      if (firstDate != null && lastDate != null) {
        int days = lastDate.difference(firstDate).inDays;
        if (days == 0) days = 1;
        kmPerDay = distance / days;
        costPerDay = totalCost / days;
      }
    }

    return PhevOverallStats(
      avgFuelConsumption: avgFuel,
      avgEvConsumption: avgEv,
      costPerKm: costPerKm,
      totalFuelVolume: totalFuelVolume,
      totalEvVolume: totalEvVolume,
      totalCost: totalCost,
      totalDistance: totalDistance,
      minConsumption:
          minFuelCons < double.infinity && minFuelCons > 0 ? minFuelCons : null,
      maxConsumption: maxFuelCons > 0 ? maxFuelCons : null,
      totalEntries: all.length,
      calcEntries: calcFuelEntries + calcEvEntries,
      kmPerDay: kmPerDay,
      costPerDay: costPerDay,
    );
  }

  /// Общая совокупная стоимость 1 км пути (TCO):
  /// (Все потраченные деньги на бензин + Все потраченные деньги на зарядку) / (Максимальный одометр - Начальный одометр)
  static double? calculateCostPerKm(
    List<FuelEntry> entries, {
    CurrencyService? currencySvc,
    String targetCurrency = 'RUB',
  }) {
    if (entries.length < 2) return null;
    final cSvc = currencySvc ?? CurrencyService.instance;

    double totalCost = 0.0;
    double minOdo = double.infinity;
    double maxOdo = 0.0;

    for (final e in entries) {
      if (e.odometer < minOdo) minOdo = e.odometer;
      if (e.odometer > maxOdo) maxOdo = e.odometer;
      final cost = e.totalCost ?? 0.0;
      totalCost += cSvc.convert(cost, e.currency, targetCurrency);
    }

    final distance = maxOdo - minOdo;
    if (distance <= 0) return null;
    return totalCost / distance;
  }

  Future<List<Map<String, dynamic>>> getMonthlyStats(int vehicleId) async {
    final all = await FuelDatabase.instance.getEntries(vehicleId);
    final settings = Get.find<SettingsController>();
    final currencySvc = CurrencyService.instance;

    final Map<String, _MonthStat> map = {};

    for (final e in all) {
      if (e.consumption == null && e.totalCost == null) continue;

      final y = e.date.year.toString();
      final m = e.date.month.toString().padLeft(2, '0');
      final month = '$y-$m';

      final stat = map.putIfAbsent(month, () => _MonthStat(month));

      if (e.entryType == 'fuel') {
        double vol = settings.convertVolume(
            e.volume, e.volumeUnit, settings.volumeUnit.value);
        stat.totalVolume += vol;
      } else if (e.entryType == 'charge') {
        stat.totalEvVolume += e.volume;
      }

      if (e.totalCost != null) {
        double cost = e.totalCost!;
        double convertedCost =
            currencySvc.convert(cost, e.currency, settings.currency.value);
        stat.totalCost += convertedCost;
      }

      if (e.consumption != null) {
        final isAnomaly = isAnomalousValue(e.consumption!, e.entryType);
        if (!isAnomaly) {
          if (e.entryType == 'fuel') {
            double cons = settings.convertVolume(
                e.consumption!, e.volumeUnit, settings.volumeUnit.value);
            stat.sumConsumption += cons;
            stat.calcEntries++;
          } else if (e.entryType == 'charge') {
            stat.sumEvConsumption += e.consumption!;
            stat.calcEvEntries++;
          }
        }
      }
    }

    final list = map.values.toList()
      ..sort((a, b) => a.month.compareTo(b.month));

    return list
        .map((s) => {
              'month': s.month,
              'avg_consumption':
                  s.calcEntries > 0 ? s.sumConsumption / s.calcEntries : null,
              'avg_ev_consumption': s.calcEvEntries > 0
                  ? s.sumEvConsumption / s.calcEvEntries
                  : null,
              'total_volume': s.totalVolume,
              'total_ev_volume': s.totalEvVolume,
              'total_cost': s.totalCost,
            })
        .toList();
  }

  // ───────────────────────────────────────── Add / Update / Delete ──

  Future<void> addEntry(FuelEntry entry) async {
    final bool isFirstEntryGlobally =
        await FuelDatabase.instance.getAllEntriesCount() == 0;

    final saved = await FuelDatabase.instance.insertEntry(entry);
    entries.add(saved);

    if (isFirstEntryGlobally) {
      await Get.find<SettingsController>().setCurrency(entry.currency);
    }

    await _recalculateConsumption(entry.vehicleId);
    await loadEntries(entry.vehicleId);
    await _checkReminder(entry.vehicleId);
  }

  Future<void> updateEntry(FuelEntry entry) async {
    await FuelDatabase.instance.updateEntry(entry);
    await _recalculateConsumption(entry.vehicleId);
    await loadEntries(entry.vehicleId);
    await _checkReminder(entry.vehicleId);
  }

  Future<void> deleteEntry(int entryId, int vehicleId) async {
    await FuelDatabase.instance.deleteEntry(entryId);
    entries.removeWhere((e) => e.id == entryId);

    await _recalculateConsumption(vehicleId);
    await loadEntries(vehicleId);
  }

  // ─────────────────────────────── Consumption Algorithm ──

  /// Пересчёт расхода в базе данных с применением изолированных цепочек Full-to-Full.
  Future<void> _recalculateConsumption(int vehicleId) async {
    final all = await FuelDatabase.instance.getEntries(vehicleId);
    final calculated = computeEntriesWithConsumption(all);

    final allMap = {for (final e in all) e.id: e};

    for (final entry in calculated) {
      if (entry.id != null) {
        final original = allMap[entry.id];
        if (original != null && original.consumption != entry.consumption) {
          await FuelDatabase.instance.updateEntry(entry);
        }
      }
    }
  }

  /// Чистая функция расчета расхода для PHEV (Full-to-Full Accumulation с изолированными цепочками).
  ///
  /// Гарантии:
  ///   1. Бензин связывается только с бензином, зарядка — только с зарядкой.
  ///   2. Частичные заправки (isFullTank == false) всегда имеют consumption == null.
  ///      Их объем накапливается до следующей полной заправки.
  ///   3. Полная заправка (isFullTank == true) рассчитывается строго от предыдущей полной:
  ///      deltaDistance = currentFull.odometer - previousFull.odometer.
  ///      totalFuel = currentVolume + sum(intermediatePartialVolumes).
  ///      Расход = (totalFuel / deltaDistance) * 100.
  ///   4. Zero & Micro-delta guard: если deltaDistance <= 0 или deltaDistance < 15 км —
  ///      consumption = null (защита от деления на 0 и нереальных цифр).
  ///   5. Буфер накопления сбрасывается после каждой полной заправки.
  static List<FuelEntry> computeEntriesWithConsumption(
      List<FuelEntry> entries) {
    if (entries.isEmpty) return [];

    final consumptions = List<double?>.filled(entries.length, null);

    // Группируем индексы по vehicleId
    final byVehicle = <int, List<int>>{};
    for (int i = 0; i < entries.length; i++) {
      byVehicle.putIfAbsent(entries[i].vehicleId, () => []).add(i);
    }

    for (final vehicleIndices in byVehicle.values) {
      final fuelIndices =
          vehicleIndices.where((i) => entries[i].entryType == 'fuel').toList();
      final chargeIndices = vehicleIndices
          .where((i) => entries[i].entryType == 'charge')
          .toList();

      _processIndexedChain(fuelIndices, entries, consumptions);
      _processIndexedChain(chargeIndices, entries, consumptions);
    }

    return List<FuelEntry>.generate(entries.length, (i) {
      final cons = consumptions[i];
      return entries[i].copyWith(
        consumption: cons,
        clearConsumption: cons == null,
      );
    });
  }

  static void _processIndexedChain(
    List<int> indices,
    List<FuelEntry> entries,
    List<double?> consumptions,
  ) {
    if (indices.isEmpty) return;

    // Сортируем по одометру, затем по дате
    final sortedIndices = List<int>.from(indices)
      ..sort((a, b) {
        final cmp = entries[a].odometer.compareTo(entries[b].odometer);
        if (cmp != 0) return cmp;
        return entries[a].date.compareTo(entries[b].date);
      });

    int? prevFullIdx;
    double accumulatedIntermediate = 0.0;

    for (final idx in sortedIndices) {
      final e = entries[idx];
      if (!e.isFullTank) {
        // Частичная заправка / зарядка: расход ОБЯЗАН быть null
        consumptions[idx] = null;
        if (prevFullIdx != null) {
          accumulatedIntermediate += e.volume;
        }
      } else {
        // Полный бак / полный заряд
        if (prevFullIdx == null) {
          // Первая полная заправка — точка отсчёта
          consumptions[idx] = null;
          prevFullIdx = idx;
          accumulatedIntermediate = 0.0;
        } else {
          final prevOdo = entries[prevFullIdx].odometer;
          final deltaDistance = e.odometer - prevOdo;
          final totalFuel = e.volume + accumulatedIntermediate;

          // Zero & Micro-delta guard (< 15 км или <= 0)
          if (deltaDistance <= 0 || deltaDistance < kMinDistanceKm) {
            consumptions[idx] = null;
          } else {
            consumptions[idx] = (totalFuel / deltaDistance) * 100.0;
          }

          prevFullIdx = idx;
          accumulatedIntermediate = 0.0;
        }
      }
    }
  }

  // ─────────────────────────────── Validation & Limits ──

  /// Возвращает номинальный объем бака (л) или батареи (кВт·ч) автомобиля.
  /// 1. Приоритет 1: Явно заданный пользователем tankCapacity / batteryCapacityKwh в профиле авто.
  /// 2. Приоритет 2: База пресетов популярных моделей (Lixiang, Geely, BYD, Chery, Haval и др.).
  /// 3. Приоритет 3: Дефолты по классу силовой установки (PHEV, бензин, электро).
  static double? getNominalCapacity(String entryType, {Vehicle? vehicle}) {
    if (vehicle == null) return null;

    final nameAndModel = '${vehicle.name} ${vehicle.model}'.toLowerCase();

    if (entryType == 'charge') {
      // 1. Задано пользователем в профиле
      if (vehicle.batteryCapacityKwh != null &&
          vehicle.batteryCapacityKwh! > 0) {
        return vehicle.batteryCapacityKwh!;
      }
      if (vehicle.usableCapacityKwh != null && vehicle.usableCapacityKwh! > 0) {
        return vehicle.usableCapacityKwh!;
      }

      // 2. Пресеты моделей
      if (nameAndModel.contains('lixiang') ||
          nameAndModel.contains('li auto') ||
          nameAndModel.contains('li l') ||
          nameAndModel.contains('li one')) {
        if (nameAndModel.contains('l9') ||
            nameAndModel.contains('l8') ||
            nameAndModel.contains('l7')) {
          return 44.5; // Li L7/L8/L9 ~42.8 - 52.3 кВт·ч
        }
        return 40.0;
      }
      if (nameAndModel.contains('chazor') ||
          nameAndModel.contains('destroyer') ||
          nameAndModel.contains('qin')) {
        return kChazorBatteryNominal; // 18.3 кВт·ч
      }
      if (nameAndModel.contains('song') ||
          nameAndModel.contains('tang') ||
          nameAndModel.contains('han')) {
        return 26.6;
      }
      if (nameAndModel.contains('galaxy') || nameAndModel.contains('monjaro')) {
        return 18.7;
      }
      if (nameAndModel.contains('voyah')) {
        return 39.0;
      }
      if (vehicle.isPhev) return 25.0;
      return null;
    } else {
      // entryType == 'fuel'
      // 1. Задано пользователем в профиле авто
      if (vehicle.tankCapacity != null && vehicle.tankCapacity! > 0) {
        return vehicle.tankCapacity!;
      }

      // 2. Пресеты моделей
      if (nameAndModel.contains('lixiang') ||
          nameAndModel.contains('li auto') ||
          nameAndModel.contains('li l')) {
        return 65.0; // Li L7/L8/L9 = 65 л, L6 = 60 л
      }
      if (nameAndModel.contains('li one')) {
        return 55.0;
      }
      if (nameAndModel.contains('chazor') ||
          nameAndModel.contains('destroyer') ||
          nameAndModel.contains('qin')) {
        return kChazorFuelTankNominal; // 48.0 л
      }
      if (nameAndModel.contains('song')) {
        return 60.0; // Song Plus DM-i = 60 л
      }
      if (nameAndModel.contains('monjaro')) {
        return 62.0; // Geely Monjaro = 62 л
      }
      if (nameAndModel.contains('coolray')) {
        return 45.0; // Geely Coolray = 45 л
      }
      if (nameAndModel.contains('tugella') || nameAndModel.contains('atlas')) {
        return 54.0;
      }
      if (nameAndModel.contains('galaxy')) {
        return 60.0; // Geely Galaxy L7/L6 = 60 л
      }
      if (nameAndModel.contains('tank 300') ||
          nameAndModel.contains('tank 500')) {
        return 80.0; // Tank 300/500 = 80 л
      }
      if (nameAndModel.contains('tiggo') ||
          nameAndModel.contains('jaecoo') ||
          nameAndModel.contains('omoda')) {
        return 57.0; // Chery Tiggo 7/8 / Jaecoo ~51-60 л
      }
      if (nameAndModel.contains('haval') ||
          nameAndModel.contains('jolion') ||
          nameAndModel.contains('dargo')) {
        return 60.0;
      }
      if (vehicle.isPhev) return 60.0;
      return null;
    }
  }

  /// Максимально допустимый физический объем для заправки/зарядки с учетом запаса.
  /// (+10% для топливного бака с горловиной, +20% для зарядки батареи с потерями).
  static double getMaxAllowedVolume(String entryType, {Vehicle? vehicle}) {
    final nominal = getNominalCapacity(entryType, vehicle: vehicle);
    if (nominal != null && nominal > 0) {
      if (entryType == 'charge') {
        final val = double.parse((nominal * 1.20).toStringAsFixed(2));
        return val.ceilToDouble(); // +20% потери
      } else {
        final val = double.parse((nominal * 1.10).toStringAsFixed(2));
        return val.ceilToDouble(); // +10% горловина
      }
    }

    if (entryType == 'charge') {
      return kMaxSingleEvVolume; // 300.0 кВт·ч
    } else {
      return kMaxSingleFuelVolume; // 250.0 л
    }
  }

  /// Физическая валидация объема заправки/зарядки с учетом горловины/потерь.
  /// Для бензина/дизеля/газа: max = tankCapacity * 1.10 (+10% горловина).
  /// Для зарядки: max = batteryCapacity * 1.20 (+20% потери).
  /// Возвращает понятный текст ошибки или null, если объем допустим.
  static String? validateEntryVolume({
    required double volume,
    required String entryType,
    required Vehicle? vehicle,
  }) {
    if (volume <= 0) {
      return 'Объем должен быть больше 0';
    }
    if (vehicle == null) return null;

    final maxAllowed = getMaxAllowedVolume(entryType, vehicle: vehicle);
    if (volume > maxAllowed) {
      final maxStr = maxAllowed % 1 == 0
          ? maxAllowed.toStringAsFixed(0)
          : maxAllowed.toStringAsFixed(1);
      if (entryType == 'charge') {
        return 'Заряженная энергия превышает физическую емкость батареи (макс. $maxStr кВт·ч)';
      } else {
        return 'Объем заправки превышает емкость бака с учетом горловины (макс. $maxStr л)';
      }
    }
    return null;
  }

  /// Валидация показаний одометра.
  /// Запрещает ввод одометра строго меньше последнего зафиксированного значения по данному авто.
  static String? validateOdometer({
    required double odometer,
    required double? lastOdometer,
  }) {
    if (lastOdometer != null && odometer < lastOdometer) {
      final odoStr = lastOdometer.toStringAsFixed(0);
      return 'Одометр не может быть меньше последнего зафиксированного значения ($odoStr км)';
    }
    return null;
  }

  /// Авторасчет и синхронизация стоимости:
  /// - totalCost = volume * unitPrice
  /// - Если общая стоимость введена пользователем вручную: unitPrice = totalCost / volume
  static ({double? unitPrice, double? totalCost}) calculatePriceSync({
    required double volume,
    double? unitPrice,
    double? totalCost,
    bool preferTotalCost = false,
  }) {
    if (volume <= 0) {
      return (unitPrice: unitPrice, totalCost: totalCost);
    }
    if (preferTotalCost && totalCost != null && totalCost > 0) {
      return (
        unitPrice: totalCost / volume,
        totalCost: totalCost,
      );
    }
    if (totalCost != null &&
        totalCost > 0 &&
        (unitPrice == null || unitPrice <= 0)) {
      return (
        unitPrice: totalCost / volume,
        totalCost: totalCost,
      );
    }
    if (unitPrice != null && unitPrice > 0) {
      return (
        unitPrice: unitPrice,
        totalCost: volume * unitPrice,
      );
    }
    return (unitPrice: unitPrice, totalCost: totalCost);
  }

  /// Расчёт предварительного расхода для предпросмотра при вводе.
  double? previewConsumption({
    required double odometer,
    required double volume,
    required double? prevOdometer,
    required bool isFullTank,
    required List<FuelEntry> tailPartials,
  }) {
    // Частичные дозаправки не имеют удельного расхода
    if (!isFullTank) return null;
    if (prevOdometer == null) return null;
    final distance = odometer - prevOdometer;
    if (distance <= 0 || distance < kMinDistanceKm) return null;

    final totalVolume = tailPartials.fold(0.0, (s, e) => s + e.volume) + volume;
    return (totalVolume / distance) * 100;
  }

  /// Проверяет, является ли запись аномальной перед сохранением.
  static AnomalyWarning? checkAnomalyWarning({
    required double odometer,
    required double volume,
    required double? prevOdometer,
    required String entryType,
    Vehicle? vehicle,
  }) {
    if (prevOdometer != null) {
      final distance = odometer - prevOdometer;
      if (distance < 0) {
        return AnomalyWarning.odometerDecreased;
      }
      if (distance > 0 && distance < kMinDistanceKm) {
        return AnomalyWarning.distanceTooSmall;
      }
      if (distance > kMaxWarningDistanceKm) {
        return AnomalyWarning.distanceTooLarge;
      }
    }

    final maxVol = getMaxAllowedVolume(entryType, vehicle: vehicle);
    if (volume > maxVol) {
      return AnomalyWarning.volumeTooLarge;
    }

    if (prevOdometer != null) {
      final distance = odometer - prevOdometer;
      if (distance >= kMinDistanceKm) {
        final cons = (volume / distance) * 100;
        if (entryType == 'charge') {
          if (cons > kMaxReasonableConsumptionEv ||
              cons < kMinReasonableConsumptionEv) {
            return AnomalyWarning.consumptionAnomalous;
          }
        } else {
          if (cons > kMaxReasonableConsumptionFuel ||
              cons < kMinReasonableConsumptionFuel) {
            return AnomalyWarning.consumptionAnomalous;
          }
        }
      }
    }

    return null;
  }

  // ─────────────────────────────────────── Reminder ──

  Future<void> checkAllReminders() async {
    final vehicles = _vehicleCtrl?.vehicles ?? [];
    for (final vehicle in vehicles) {
      if (vehicle.reminderDays == null || vehicle.id == null) continue;
      await _checkReminder(vehicle.id!);
    }
  }

  Future<void> _checkReminder(int vehicleId) async {
    final vehicle =
        _vehicleCtrl?.vehicles.firstWhereOrNull((v) => v.id == vehicleId);
    if (vehicle == null || vehicle.reminderDays == null) return;

    final lastDate = await FuelDatabase.instance.getLastEntryDate(vehicleId);
    if (lastDate == null) return;

    final days = DateTime.now().difference(lastDate).inDays;

    if (days >= vehicle.reminderDays!) {
      await NotificationService.instance.showFuelReminder(
        notificationId: vehicleId,
        vehicleName: vehicle.name,
        daysSinceLastEntry: days,
      );
    } else {
      await NotificationService.instance.cancel(vehicleId);
    }
  }

  // ───────────────────────────────────── CSV Export ──

  Future<void> exportToCsv(int vehicleId, String vehicleName) async {
    final all = await FuelDatabase.instance.getEntries(vehicleId);
    if (all.isEmpty) {
      Get.snackbar('Нет данных', 'Нет записей для экспорта',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final fmt = DateFormat('dd.MM.yyyy');
    final buf = StringBuffer();

    buf.writeln(
      '\uFEFFДата,Одометр (км),Объём,Ед.изм,Цена/ед,Валюта,Стоимость,Расход,Тип,Энергия,Станция,Широта,Долгота,Аномалия',
    );

    for (final e in all) {
      final fillType = e.isFullTank ? 'Полный' : 'Частичный';
      final energy = e.entryType == 'charge' ? 'Зарядка' : 'Топливо';
      final cost = e.totalCost?.toStringAsFixed(2) ?? '';
      final cons = e.consumption?.toStringAsFixed(2) ?? '—';
      final price = e.pricePerLiter?.toStringAsFixed(2) ?? '';
      final station = e.stationName ?? '';
      final lat = e.latitude?.toStringAsFixed(6) ?? '';
      final lon = e.longitude?.toStringAsFixed(6) ?? '';
      final anomaly = (e.consumption != null &&
              isAnomalousConsumption(e.consumption!, e.entryType))
          ? 'Да'
          : '';

      buf.writeln(
        '${fmt.format(e.date)},${e.odometer.toStringAsFixed(1)},${e.volume.toStringAsFixed(2)},${e.volumeUnit},$price,${e.currency},$cost,$cons,$fillType,$energy,$station,$lat,$lon,$anomaly',
      );
    }

    final dir = await getTemporaryDirectory();
    final safeName = vehicleName.replaceAll(RegExp(r'[^\w]'), '_');
    final file = File('${dir.path}/fuelman_${safeName}_export.csv');
    await file.writeAsString(buf.toString());

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'FuelMan — экспорт данных: $vehicleName',
      ),
    );
  }

  // ──────────────────────────────── Helpers ──

  List<FuelEntry> get entriesWithConsumption =>
      entries.where((e) => e.consumption != null).toList();

  double? get lastOdometer => entries.isNotEmpty ? entries.last.odometer : null;

  /// Возвращает максимальный одометр среди всех записей для текущего автомобиля.
  double? getLastRecordedOdometer({int? excludeEntryId}) {
    final filtered = excludeEntryId != null
        ? entries.where((e) => e.id != excludeEntryId).toList()
        : entries;
    if (filtered.isEmpty) return null;
    return filtered.map((e) => e.odometer).reduce((a, b) => a > b ? a : b);
  }

  /// Возвращает последнюю полную заправку/зарядку для данного типа энергии.
  FuelEntry? getLastFullEntry(String entryType) {
    final filtered =
        entries.where((e) => e.entryType == entryType && e.isFullTank).toList();
    if (filtered.isEmpty) return null;
    return filtered.last;
  }

  /// Возвращает хвостовые частичные заправки после последней полной
  /// (для предпросмотра расхода при добавлении новой полной заправки).
  List<FuelEntry> getTailPartials(String entryType) {
    final filtered = entries.where((e) => e.entryType == entryType).toList();
    if (filtered.isEmpty) return [];

    int lastFullIdx = -1;
    for (int i = filtered.length - 1; i >= 0; i--) {
      if (filtered[i].isFullTank) {
        lastFullIdx = i;
        break;
      }
    }
    if (lastFullIdx == -1) return filtered;
    return filtered.sublist(lastFullIdx + 1);
  }
}

// ─────────────────────── Anomaly Warning Enum ────────────────────────────────

enum AnomalyWarning {
  odometerDecreased,
  distanceTooSmall,
  distanceTooLarge,
  volumeTooLarge,
  consumptionAnomalous,
}

// ─────────────────────────── Month Stat ──────────────────────────────────────

class _MonthStat {
  final String month;
  double sumConsumption = 0.0;
  double totalVolume = 0.0;
  double totalCost = 0.0;
  int calcEntries = 0;

  double sumEvConsumption = 0.0;
  double totalEvVolume = 0.0;
  int calcEvEntries = 0;

  _MonthStat(this.month);
}

import 'package:get/get.dart';

import '../database/fuel_database.dart';
import '../models/charging_entry.dart';
import '../models/fuel_entry.dart';
import '../models/vehicle.dart';
import 'vehicle_controller.dart';

// ─────────────────────────── Constants ──────────────────────────────────────

/// Коэффициент пересчёта электроэнергии в литровый эквивалент.
///
/// По стандарту SAE J1711 / GREET: 1 литр бензина ≈ 8.9 кВт·ч
/// (нижняя теплотворная способность).
const double kGasolineEquivalentKwhPerLiter = 8.9;

/// Минимальный допустимый прирост одометра (км) между двумя записями.
/// Значения меньше этого порога считаются аномалией (сброс или ошибка ввода).
const double kMinOdometerDeltaKm = 0.1;

/// Максимальный допустимый прирост одометра (км) за одну сессию.
/// Значения выше считаются потенциальной ошибкой ввода.
const double kMaxOdometerDeltaKm = 10000.0;

// ─────────────────────────── Data Classes ───────────────────────────────────

/// Элемент объединённого таймлайна событий (заправка + зарядка).
///
/// Используется в [ChargingEntryController.unifiedTimeline] для
/// сквозного объединения обоих типов записей по общему одометру.
class TimelineItem {
  /// Тип события: `fuel` или `charge`.
  final String type;

  /// Показания одометра для сортировки.
  final double odometer;

  /// Дата события (для отображения и сортировки при одинаковом одометре).
  final DateTime date;

  /// Стоимость события в текущей валюте.
  final double cost;

  /// Источник данных: исходная запись.
  final Object source; // FuelEntry | ChargingEntry

  const TimelineItem({
    required this.type,
    required this.odometer,
    required this.date,
    required this.cost,
    required this.source,
  });

  FuelEntry? get asFuelEntry =>
      source is FuelEntry ? source as FuelEntry : null;

  ChargingEntry? get asChargingEntry =>
      source is ChargingEntry ? source as ChargingEntry : null;
}

/// Результат расчёта метрик Unified Timeline Engine.
class TimelineMetrics {
  /// Суммарная стоимость топлива (все FuelEntry).
  final double totalFuelCost;

  /// Суммарная стоимость зарядок (все ChargingEntry).
  final double totalChargingCost;

  /// Общая стоимость / км пути по всему таймлайну.
  ///
  /// `(totalFuelCost + totalChargingCost) / (odo_max - odo_min)`
  ///
  /// null если диапазон одометра недостаточен (< [kMinOdometerDeltaKm]).
  final double? combinedCostPerKm;

  /// Расход кВт·ч / 100 км по **общему** одометру.
  ///
  /// Рассчитывается: `∑kWhAdded / ΔTotalOdometer * 100`
  ///
  /// null если ΔTotalOdometer ≤ [kMinOdometerDeltaKm] или нет зарядок.
  final double? kwhPer100kmTotal;

  /// Расход кВт·ч / 100 км по **EV-одометру** (если доступен).
  ///
  /// Рассчитывается: `∑kWhAdded / ΔEVOdometer * 100`
  ///
  /// null если EV-одометр не заполнен ни в одной записи.
  final double? kwhPer100kmEv;

  /// Бензиновый эквивалент расхода, л-экв/100 км.
  ///
  /// `kwhPer100km / 8.9`
  ///
  /// Использует [kwhPer100kmEv] если доступен, иначе [kwhPer100kmTotal].
  final double? literEquivalentPer100km;

  /// Диапазон общего одометра в таймлайне, км.
  final double odometerRangeKm;

  /// Суммарно зарядной сессий.
  final int chargingSessionCount;

  /// Суммарно заправок.
  final int fuelEntryCount;

  const TimelineMetrics({
    required this.totalFuelCost,
    required this.totalChargingCost,
    this.combinedCostPerKm,
    this.kwhPer100kmTotal,
    this.kwhPer100kmEv,
    this.literEquivalentPer100km,
    required this.odometerRangeKm,
    required this.chargingSessionCount,
    required this.fuelEntryCount,
  });

  static const TimelineMetrics empty = TimelineMetrics(
    totalFuelCost: 0.0,
    totalChargingCost: 0.0,
    odometerRangeKm: 0.0,
    chargingSessionCount: 0,
    fuelEntryCount: 0,
  );
}

// ─────────────────────────── Controller ─────────────────────────────────────

/// Контроллер сессий зарядки.
///
/// Ключевая ответственность:
///   — CRUD операции с [ChargingEntry] через [FuelDatabase]
///   — Unified Timeline Engine: объединение [FuelEntry] + [ChargingEntry]
///     по общему одометру для расчёта комбинированной стоимости km
///   — Метрики энергоэффективности: кВт·ч/100 км, л-экв/100 км
///   — Детектор деградации/потерь АКБ (Battery Health Ratio)
///   — Защита от деления на ноль и аномальных скачков одометра
class ChargingEntryController extends GetxController {
  /// Реактивный список сессий зарядки для текущего автомобиля.
  final entries = <ChargingEntry>[].obs;

  /// Флаг загрузки данных из БД.
  final isLoading = false.obs;

  /// Последний рассчитанный набор метрик таймлайна.
  /// Обновляется при каждой загрузке/изменении данных.
  final metrics = Rx<TimelineMetrics>(TimelineMetrics.empty);

  /// Объединённый таймлайн событий (заправки + зарядки), отсортированный
  /// по одометру ASC. Обновляется вместе с [metrics].
  final timeline = <TimelineItem>[].obs;

  final _vehicleCtrl = Get.find<VehicleController>();
  final List<Worker> _workers = [];

  @override
  void onInit() {
    super.onInit();
    // Перезагружаем данные при смене активного автомобиля.
    _workers.add(ever(_vehicleCtrl.selectedVehicle, (_) => _onVehicleChanged()));
    _onVehicleChanged();
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }

  void _onVehicleChanged() {
    final v = _vehicleCtrl.selectedVehicle.value;
    if (v != null) {
      loadEntries(v.id!);
    } else {
      entries.clear();
      timeline.clear();
      metrics.value = TimelineMetrics.empty;
    }
  }

  // ───────────────────────────────────────────────── Load ──

  /// Загружает сессии зарядки для [vehicleId] из БД и пересчитывает метрики.
  Future<void> loadEntries(int vehicleId) async {
    isLoading.value = true;
    try {
      final list =
          await FuelDatabase.instance.getChargingEntriesByVehicleId(vehicleId);
      entries.assignAll(list);
      await _rebuildTimeline(vehicleId);
    } finally {
      isLoading.value = false;
    }
  }

  // ───────────────────────────────────────────────── CRUD ──

  /// Добавляет новую сессию зарядки и обновляет состояние.
  Future<ChargingEntry> addEntry(ChargingEntry entry) async {
    final saved = await FuelDatabase.instance.insertChargingEntry(entry);
    entries.add(saved);
    _sortEntries();
    await _rebuildTimeline(saved.vehicleId);
    return saved;
  }

  /// Обновляет существующую сессию зарядки.
  Future<void> updateEntry(ChargingEntry entry) async {
    await FuelDatabase.instance.updateChargingEntry(entry);
    final idx = entries.indexWhere((e) => e.id == entry.id);
    if (idx != -1) entries[idx] = entry;
    _sortEntries();
    await _rebuildTimeline(entry.vehicleId);
  }

  /// Удаляет сессию зарядки по [id].
  Future<void> deleteEntry(int id) async {
    final entry = entries.firstWhereOrNull((e) => e.id == id);
    await FuelDatabase.instance.deleteChargingEntry(id);
    entries.removeWhere((e) => e.id == id);
    if (entry != null) {
      await _rebuildTimeline(entry.vehicleId);
    }
  }

  void _sortEntries() {
    entries.sort((a, b) => a.odometer.compareTo(b.odometer));
  }

  // ──────────────────────── Unified Timeline Engine ──────────────────────────

  /// Перестраивает объединённый таймлайн и пересчитывает все метрики.
  ///
  /// Алгоритм:
  ///   1. Загружаем актуальные [FuelEntry] из контроллера заправок.
  ///   2. Объединяем с [ChargingEntry] в единый список [TimelineItem].
  ///   3. Сортируем по `odometer ASC` (при равенстве — по `date ASC`).
  ///   4. Фильтруем аномальные скачки одометра.
  ///   5. Рассчитываем метрики без наложения дистанций.
  Future<void> _rebuildTimeline(int vehicleId) async {
    // Получаем заправки от FuelEntryController если он зарегистрирован.
    // Если контроллер ещё не инициализирован — используем БД напрямую.
    List<FuelEntry> fuelEntries;
    try {
      // ignore: invalid_use_of_protected_member
      fuelEntries = Get.find<dynamic>(tag: 'FuelEntryController') == null
          ? await FuelDatabase.instance.getEntries(vehicleId)
          : (Get.find<dynamic>(tag: 'FuelEntryController').entries
                  as List<FuelEntry>?) ??
              await FuelDatabase.instance.getEntries(vehicleId);
    } catch (_) {
      fuelEntries = await FuelDatabase.instance.getEntries(vehicleId);
    }

    final chargingEntries = entries.toList();

    // Собираем единый список TimelineItem
    final items = <TimelineItem>[];

    for (final fe in fuelEntries) {
      items.add(TimelineItem(
        type: 'fuel',
        odometer: fe.odometer,
        date: fe.date,
        cost: fe.totalCost ?? 0.0,
        source: fe,
      ));
    }

    for (final ce in chargingEntries) {
      items.add(TimelineItem(
        type: 'charge',
        odometer: ce.odometer,
        date: ce.date,
        cost: ce.totalCost,
        source: ce,
      ));
    }

    // Сортировка: одометр ASC, при равенстве — дата ASC
    items.sort((a, b) {
      final odoCmp = a.odometer.compareTo(b.odometer);
      return odoCmp != 0 ? odoCmp : a.date.compareTo(b.date);
    });

    // Фильтрация аномальных скачков одометра
    final filteredItems = _filterOdometerAnomalies(items);

    timeline.assignAll(filteredItems);
    metrics.value = _calculateMetrics(filteredItems, chargingEntries);
  }

  /// Фильтрует записи с аномальными показаниями одометра.
  ///
  /// Удаляет записи где:
  ///   — Δodo ≤ [kMinOdometerDeltaKm] (сброс, повтор или ошибка ввода)
  ///   — Δodo > [kMaxOdometerDeltaKm] (нереальный прыжок)
  ///
  /// Первая запись всегда сохраняется как базовая точка отсчёта.
  List<TimelineItem> _filterOdometerAnomalies(List<TimelineItem> items) {
    if (items.isEmpty) return items;

    final result = <TimelineItem>[];
    result.add(items.first); // Первая запись — точка отсчёта

    for (int i = 1; i < items.length; i++) {
      final delta = items[i].odometer - result.last.odometer;
      if (delta <= kMinOdometerDeltaKm) continue; // Убываний/нулей нет
      if (delta > kMaxOdometerDeltaKm) continue; // Нереальный скачок
      result.add(items[i]);
    }

    return result;
  }

  /// Рассчитывает все метрики по отфильтрованному таймлайну.
  TimelineMetrics _calculateMetrics(
    List<TimelineItem> items,
    List<ChargingEntry> chargingEntries,
  ) {
    if (items.isEmpty) return TimelineMetrics.empty;

    // Суммируем стоимости по типам
    double totalFuelCost = 0.0;
    double totalChargingCost = 0.0;

    for (final item in items) {
      if (item.type == 'fuel') {
        totalFuelCost += item.cost;
      } else {
        totalChargingCost += item.cost;
      }
    }

    // Диапазон одометра
    final odoMin = items.first.odometer;
    final odoMax = items.last.odometer;
    final odoRange = odoMax - odoMin;

    // Combined cost / km
    double? combinedCostPerKm;
    if (odoRange >= kMinOdometerDeltaKm) {
      combinedCostPerKm = (totalFuelCost + totalChargingCost) / odoRange;
    }

    // ── Электрические метрики ──

    final chargeItems = items.where((i) => i.type == 'charge').toList();
    if (chargeItems.isEmpty) {
      return TimelineMetrics(
        totalFuelCost: totalFuelCost,
        totalChargingCost: totalChargingCost,
        combinedCostPerKm: combinedCostPerKm,
        odometerRangeKm: odoRange,
        chargingSessionCount: chargingEntries.length,
        fuelEntryCount: items.where((i) => i.type == 'fuel').length,
      );
    }

    // Суммарная заряженная энергия (из отфильтрованных записей)
    final totalKwh = chargeItems.fold<double>(
      0.0,
      (sum, item) => sum + (item.asChargingEntry?.kwhAdded ?? 0.0),
    );

    // kWh/100km по ОБЩЕМУ одометру
    double? kwhPer100kmTotal;
    if (odoRange >= kMinOdometerDeltaKm && totalKwh > 0) {
      kwhPer100kmTotal = (totalKwh / odoRange) * 100.0;
    }

    // kWh/100km по EV-одометру (если хотя бы часть записей имеет evOdometer)
    double? kwhPer100kmEv;
    final evOdoValues = chargingEntries
        .where((e) => e.evOdometer != null && e.evOdometer! > 0)
        .map((e) => e.evOdometer!)
        .toList();

    if (evOdoValues.length >= 2 && totalKwh > 0) {
      final evOdoMin = evOdoValues.reduce((a, b) => a < b ? a : b);
      final evOdoMax = evOdoValues.reduce((a, b) => a > b ? a : b);
      final evOdoDelta = evOdoMax - evOdoMin;
      if (evOdoDelta >= kMinOdometerDeltaKm) {
        kwhPer100kmEv = (totalKwh / evOdoDelta) * 100.0;
      }
    }

    // Бензиновый эквивалент: предпочитаем EV-одометр, иначе общий
    final kwhBasis = kwhPer100kmEv ?? kwhPer100kmTotal;
    final literEquivalent = kwhBasis != null
        ? kwhBasis / kGasolineEquivalentKwhPerLiter
        : null;

    return TimelineMetrics(
      totalFuelCost: totalFuelCost,
      totalChargingCost: totalChargingCost,
      combinedCostPerKm: combinedCostPerKm,
      kwhPer100kmTotal: kwhPer100kmTotal,
      kwhPer100kmEv: kwhPer100kmEv,
      literEquivalentPer100km: literEquivalent,
      odometerRangeKm: odoRange,
      chargingSessionCount: chargingEntries.length,
      fuelEntryCount: items.where((i) => i.type == 'fuel').length,
    );
  }

  // ──────────────────── Battery Health & Loss Ratio ──────────────────────────

  /// Рассчитывает Battery Health Ratio — средний КПД передачи энергии
  /// по всем сессиям зарядки с заполненными данными SOC.
  ///
  /// Параметр [vehicle] нужен для доступа к [Vehicle.effectiveCapacityKwh].
  ///
  /// Возвращает:
  ///   — [BatteryHealthReport.averageEfficiencyPercent]: средний КПД %
  ///   — [BatteryHealthReport.anomalousSessions]: сессии с аномальным КПД
  ///   — [BatteryHealthReport.temperatureCorrectedEfficiency]: КПД с поправкой
  ///     на температуру (температуры < 10°C снижают КПД, учитывается +2% корр.)
  BatteryHealthReport calculateBatteryHealth(Vehicle vehicle) {
    final capacity = vehicle.effectiveCapacityKwh;
    if (capacity == null || capacity <= 0) {
      return BatteryHealthReport.unavailable;
    }

    final socEntries = entries
        .where((e) =>
            e.startSocPercent != null &&
            e.endSocPercent != null &&
            e.endSocPercent! > e.startSocPercent! &&
            e.kwhAdded > 0)
        .toList();

    if (socEntries.isEmpty) {
      return BatteryHealthReport.unavailable;
    }

    double sumEfficiency = 0.0;
    double sumCorrectedEfficiency = 0.0;
    int count = 0;
    final anomalous = <ChargingEntry>[];

    for (final entry in socEntries) {
      final ratio = entry.efficiencyRatio(capacity);
      if (ratio == null) continue;

      // Температурная поправка: при T < 10°C добавляем 2% к «ожидаемым потерям»
      // (холод увеличивает внутреннее сопротивление → снижает кажущийся КПД)
      double corrected = ratio;
      if (entry.temperatureCelsius != null && entry.temperatureCelsius! < 10.0) {
        final tempPenalty = (10.0 - entry.temperatureCelsius!).clamp(0.0, 30.0);
        corrected = ratio + (tempPenalty * 0.067); // ~2% на 30°C диапазон
      }

      sumEfficiency += ratio;
      sumCorrectedEfficiency += corrected;
      count++;

      if (entry.isEfficiencyAnomalous(capacity)) {
        anomalous.add(entry);
      }
    }

    if (count == 0) return BatteryHealthReport.unavailable;

    return BatteryHealthReport(
      averageEfficiencyPercent: sumEfficiency / count,
      temperatureCorrectedEfficiency: sumCorrectedEfficiency / count,
      anomalousSessions: anomalous,
      analyzedSessionCount: count,
    );
  }

  // ──────────────────────────────── Convenience Getters ──────────────────────

  /// Текущая комбинированная стоимость 1 км пути (руб/км или текущая валюта).
  double? get combinedCostPerKm => metrics.value.combinedCostPerKm;

  /// Текущий расход кВт·ч/100 км (предпочитает EV-одометр).
  double? get kwhPer100km =>
      metrics.value.kwhPer100kmEv ?? metrics.value.kwhPer100kmTotal;

  /// Текущий л-экв/100 км.
  double? get literEquivalentPer100km =>
      metrics.value.literEquivalentPer100km;

  /// Общее количество зарядных сессий для текущего авто.
  int get sessionCount => entries.length;

  /// Суммарная заряженная энергия (кВт·ч) за всё время.
  double get totalKwhCharged =>
      entries.fold(0.0, (sum, e) => sum + e.kwhAdded);

  /// Суммарная стоимость всех зарядок.
  double get totalChargingCost =>
      entries.fold(0.0, (sum, e) => sum + e.totalCost);

  /// Средняя стоимость 1 кВт·ч по всем сессиям.
  ///
  /// Возвращает 0.0 если данных нет.
  double get averageCostPerKwh {
    final totalKwh = totalKwhCharged;
    if (totalKwh <= 0) return 0.0;
    return totalChargingCost / totalKwh;
  }
}

// ─────────────────────── Battery Health Report ───────────────────────────────

/// Отчёт о здоровье батареи и потерях при зарядке.
class BatteryHealthReport {
  /// Средний КПД передачи энергии из сети в АКБ, %.
  final double averageEfficiencyPercent;

  /// КПД с поправкой на температурные потери, %.
  final double temperatureCorrectedEfficiency;

  /// Список сессий с аномальным КПД (< 50% или > 100%).
  final List<ChargingEntry> anomalousSessions;

  /// Количество проанализированных сессий (с SOC-данными).
  final int analyzedSessionCount;

  /// Данные недоступны (нет SOC или ёмкости АКБ).
  final bool isUnavailable;

  const BatteryHealthReport({
    required this.averageEfficiencyPercent,
    required this.temperatureCorrectedEfficiency,
    required this.anomalousSessions,
    required this.analyzedSessionCount,
    this.isUnavailable = false,
  });

  static const BatteryHealthReport unavailable = BatteryHealthReport(
    averageEfficiencyPercent: 0,
    temperatureCorrectedEfficiency: 0,
    anomalousSessions: [],
    analyzedSessionCount: 0,
    isUnavailable: true,
  );

  /// Оценка здоровья батареи.
  ///
  /// — ≥ 90 %: Отличное
  /// — 80–90 %: Хорошее
  /// — 70–80 %: Удовлетворительное
  /// — < 70 %: Требует внимания
  String get healthLabel {
    if (isUnavailable) return '—';
    if (averageEfficiencyPercent >= 90) return '✅';
    if (averageEfficiencyPercent >= 80) return '🟡';
    if (averageEfficiencyPercent >= 70) return '🟠';
    return '🔴';
  }
}

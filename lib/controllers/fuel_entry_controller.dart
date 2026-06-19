import 'dart:io';

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/fuel_database.dart';
import '../models/fuel_entry.dart';
import '../services/notification_service.dart';
import '../services/currency_service.dart';
import 'settings_controller.dart';
import 'vehicle_controller.dart';

// ─────────────────────────── Constants ──────────────────────────────────────

/// Минимальное расстояние в км для достоверного расчёта расхода.
/// Если разница одометра меньше — расход не рассчитывается (слишком ненадёжно).
const double kMinDistanceKm = 10.0;

/// Максимальный «разумный» расход топлива л/100 км.
/// Выше — помечаем как аномалию.
const double kMaxReasonableConsumptionFuel = 50.0;

/// Минимальный «разумный» расход топлива л/100 км.
const double kMinReasonableConsumptionFuel = 1.0;

/// Максимальный «разумный» расход электроэнергии кВт·ч/100 км.
const double kMaxReasonableConsumptionEv = 80.0;

/// Минимальный «разумный» расход электроэнергии кВт·ч/100 км.
const double kMinReasonableConsumptionEv = 4.0;

/// Максимально допустимый разовый объём топлива в литрах.
/// Больше — скорее всего ошибка ввода.
const double kMaxSingleFuelVolume = 250.0;

/// Максимально допустимый разовый объём зарядки кВт·ч.
const double kMaxSingleEvVolume = 300.0;

/// Порог «очень маленького» расстояния (предупреждение без блокировки).
const double kWarningDistanceKm = 30.0;

/// Порог «очень большого» расстояния (предупреждение о возможной ошибке ввода).
const double kMaxWarningDistanceKm = 3000.0;

// ─────────────────────────── Controller ─────────────────────────────────────

/// Контроллер записей о заправках.
///
/// Ключевая ответственность:
///   — CRUD операции с [FuelEntry]
///   — Алгоритм Full-to-Full (пересчёт расхода после каждого изменения)
///   — Агрегированная статистика
///   — Экспорт в CSV через share_plus
///   — Проверка напоминаний о заправке
///   — Детектирование аномального расхода
class FuelEntryController extends GetxController {
  final entries = <FuelEntry>[].obs;
  final stats = <String, double?>{}.obs;
  final isLoading = false.obs;

  /// Множество id записей, у которых расход помечен как аномальный.
  final anomalousIds = <int>{}.obs;

  final _vehicleCtrl = Get.find<VehicleController>();

  @override
  void onInit() {
    super.onInit();
    // Перезагружаем данные при смене активного автомобиля.
    ever(_vehicleCtrl.selectedVehicle, (_) => _onVehicleChanged());
    _onVehicleChanged();

    // Пересчет статистики при смене валюты или единиц измерения
    final settings = Get.find<SettingsController>();
    ever(settings.currency, (_) => _recalcStatsCurrentVehicle());
    ever(settings.volumeUnit, (_) => _recalcStatsCurrentVehicle());
  }

  void _recalcStatsCurrentVehicle() {
    final v = _vehicleCtrl.selectedVehicle.value;
    if (v != null) {
      _loadStats(v.id!);
    }
  }

  void _onVehicleChanged() {
    final v = _vehicleCtrl.selectedVehicle.value;
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

  /// Перестраивает набор id аномальных записей.
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

  /// Возвращает true, если значение расхода аномально (вне разумных пределов).
  bool isAnomalousConsumption(double value, String entryType) {
    if (entryType == 'charge') {
      return value < kMinReasonableConsumptionEv ||
          value > kMaxReasonableConsumptionEv;
    }
    return value < kMinReasonableConsumptionFuel ||
        value > kMaxReasonableConsumptionFuel;
  }

  /// Возвращает true, если запись с данным id является аномальной.
  bool isEntryAnomalous(int? id) => id != null && anomalousIds.contains(id);

  // ─────────────────────────────── Stats ──

  Future<void> _loadStats(int vehicleId) async {
    final all = await FuelDatabase.instance.getEntries(vehicleId);
    final settings = Get.find<SettingsController>();
    final currencySvc = CurrencyService.instance;

    double minCons = double.infinity;
    double maxCons = 0.0;
    double sumCons = 0.0;
    int calcEntries = 0;

    // EV / зарядка — отдельная статистика
    double sumEvCons = 0.0;
    int calcEvEntries = 0;

    double totalVolume = 0.0;
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
        double vol = settings.convertVolume(
            e.volume, e.volumeUnit, settings.volumeUnit.value);
        totalVolume += vol;
      } else if (e.entryType == 'charge') {
        totalEvVolume += e.volume; // кВт·ч не конвертируем
      }

      double cost = e.totalCost ?? 0.0;
      double convertedCost =
          currencySvc.convert(cost, e.currency, settings.currency.value);
      totalCost += convertedCost;

      if (e.consumption != null) {
        // Аномальные записи исключаем из статистики avg/min/max
        final isAnomaly = isAnomalousConsumption(e.consumption!, e.entryType);
        if (!isAnomaly) {
          if (e.entryType == 'fuel') {
            double cons = settings.convertVolume(
                e.consumption!, e.volumeUnit, settings.volumeUnit.value);
            if (cons < minCons) minCons = cons;
            if (cons > maxCons) maxCons = cons;
            sumCons += cons;
            calcEntries++;
          } else if (e.entryType == 'charge') {
            sumEvCons += e.consumption!;
            calcEvEntries++;
          }
        }
      }
    }

    double? avgCons = calcEntries > 0 ? sumCons / calcEntries : null;
    double? avgEvCons = calcEvEntries > 0 ? sumEvCons / calcEvEntries : null;
    if (minCons == double.infinity) minCons = 0;

    double? costPerKm;
    double? kmPerDay;
    double? costPerDay;
    double? totalDistance;

    if (all.length >= 2 && firstDate != null && lastDate != null) {
      double distance = maxOdo - minOdo;
      int days = lastDate.difference(firstDate).inDays;
      if (days == 0) days = 1;

      if (distance > 0) {
        costPerKm = totalCost / distance;
        totalDistance = distance;
      }
      kmPerDay = distance / days;
      costPerDay = totalCost / days;
    }

    stats.assignAll({
      'min_consumption': minCons > 0 ? minCons : null,
      'max_consumption': maxCons > 0 ? maxCons : null,
      'avg_consumption': avgCons,
      'avg_ev_consumption': avgEvCons,
      'total_volume': totalVolume,
      'total_ev_volume': totalEvVolume,
      'total_cost': totalCost,
      'total_entries': all.length.toDouble(),
      'calc_entries': calcEntries.toDouble(),
      'cost_per_km': costPerKm,
      'km_per_day': kmPerDay,
      'cost_per_day': costPerDay,
      'total_distance': totalDistance,
    });
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
        // Аномалии не включаем в ежемесячную статистику avg
        final isAnomaly = isAnomalousConsumption(e.consumption!, e.entryType);
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

    return list.map((s) => {
          'month': s.month,
          'avg_consumption':
              s.calcEntries > 0 ? s.sumConsumption / s.calcEntries : null,
          'avg_ev_consumption':
              s.calcEvEntries > 0 ? s.sumEvConsumption / s.calcEvEntries : null,
          'total_volume': s.totalVolume,
          'total_ev_volume': s.totalEvVolume,
          'total_cost': s.totalCost,
        }).toList();
  }

  // ───────────────────────────────────────── Add ──

  Future<void> addEntry(FuelEntry entry) async {
    final bool isFirstEntryGlobally =
        await FuelDatabase.instance.getAllEntriesCount() == 0;

    // 1. Сохраняем запись в БД (без расхода — будет пересчитан ниже).
    final saved = await FuelDatabase.instance.insertEntry(entry);
    entries.add(saved);

    // Если это первая запись вообще, меняем глобальную валюту на выбранную пользователем
    if (isFirstEntryGlobally) {
      await Get.find<SettingsController>().setCurrency(entry.currency);
    }

    // 2. Пересчитываем расход для ВСЕХ записей этого авто (Full-to-Full).
    await _recalculateConsumption(entry.vehicleId);

    // 3. Перезагружаем список и статистику после пересчёта.
    await loadEntries(entry.vehicleId);

    // 4. Проверяем напоминания (сброс при новой заправке).
    await _checkReminder(entry.vehicleId);
  }

  Future<void> updateEntry(FuelEntry entry) async {
    await FuelDatabase.instance.updateEntry(entry);
    await _recalculateConsumption(entry.vehicleId);
    await loadEntries(entry.vehicleId);
    await _checkReminder(entry.vehicleId);
  }

  // ───────────────────────────────────────── Delete ──

  Future<void> deleteEntry(int entryId, int vehicleId) async {
    await FuelDatabase.instance.deleteEntry(entryId);
    entries.removeWhere((e) => e.id == entryId);

    // Пересчёт необходим: удаление меняет цепочку Full-to-Full.
    await _recalculateConsumption(vehicleId);
    await loadEntries(vehicleId);
  }

  // ─────────────────────────────── Consumption Algorithm ──

  /// Алгоритм Full-to-Full с защитой от аномалий и малых расстояний.
  ///
  /// Ключевые правила:
  ///   1. Если расстояние между точками < [kMinDistanceKm] → consumption = null.
  ///   2. Блок суммирует объёмы от одной полной заправки до следующей.
  ///   3. Хвостовой блок (частичные после последней полной) → накопительный.
  ///   4. Первая запись всегда null (нет предыдущей точки).
  ///   5. Аномальный расход сохраняется в БД AS IS, но помечается в [anomalousIds].
  Future<void> _recalculateConsumption(int vehicleId) async {
    final all = await FuelDatabase.instance.getEntries(vehicleId);

    // Разделим на топливо и электричество
    final fuelEntries = all.where((e) => e.entryType == 'fuel').toList();
    final chargeEntries = all.where((e) => e.entryType == 'charge').toList();

    final Map<int, double?> updates = {};

    void calculateList(List<FuelEntry> list) {
      if (list.isEmpty) return;
      if (list.length < 2) {
        updates[list[0].id!] = null;
        return;
      }

      // Найдём индексы «полных» заправок, игнорируя слишком короткие дистанции (агрегация)
      final fullIndices = <int>[];
      for (int i = 0; i < list.length; i++) {
        if (list[i].isFullTank) {
          if (fullIndices.isEmpty) {
            fullIndices.add(i);
          } else {
            final distance = list[i].odometer - list[fullIndices.last].odometer;
            if (distance >= kMinDistanceKm) {
              fullIndices.add(i);
            }
          }
        }
      }

      // Первая запись всегда имеет расход null
      updates[list[0].id!] = null;

      // ── Хелпер: рассчитать расход за блок ──────────────────────────────
      double? calcBlockConsumption({
        required double distance,
        required double sumVolume,
      }) {
        if (distance < kMinDistanceKm) return null; // слишком мало — ненадёжно
        return (sumVolume / distance) * 100;
      }

      // ── Сценарий: нет полных заправок вообще ────────────────────────────
      if (fullIndices.isEmpty) {
        final startOdo = list[0].odometer;
        for (int i = 1; i < list.length; i++) {
          final distance = list[i].odometer - startOdo;
          double sumVolume = 0.0;
          for (int j = 1; j <= i; j++) {
            sumVolume += list[j].volume;
          }
          updates[list[i].id!] =
              calcBlockConsumption(distance: distance, sumVolume: sumVolume);
        }
        return;
      }

      // ── Блок 1: от записи 0 до первой полной заправки ───────────────────
      final int firstFullIdx = fullIndices[0];
      if (firstFullIdx > 0) {
        final distance =
            list[firstFullIdx].odometer - list[0].odometer;
        final double sumVolume = list
            .sublist(1, firstFullIdx + 1)
            .fold(0.0, (s, e) => s + e.volume);
        final cons = calcBlockConsumption(
            distance: distance, sumVolume: sumVolume);
        for (int j = 1; j <= firstFullIdx; j++) {
          updates[list[j].id!] = cons;
        }
      }

      // ── Блоки между полными заправками ──────────────────────────────────
      for (int i = 0; i < fullIndices.length - 1; i++) {
        final int startIdx = fullIndices[i];
        final int endIdx = fullIndices[i + 1];
        final distance =
            list[endIdx].odometer - list[startIdx].odometer;
        final double sumVolume = list
            .sublist(startIdx + 1, endIdx + 1)
            .fold(0.0, (s, e) => s + e.volume);
        final cons = calcBlockConsumption(
            distance: distance, sumVolume: sumVolume);
        for (int j = startIdx + 1; j <= endIdx; j++) {
          updates[list[j].id!] = cons;
        }
      }

      // ── Хвостовой блок: от последней полной до конца ────────────────────
      final int lastFullIdx = fullIndices.last;
      if (lastFullIdx < list.length - 1) {
        for (int i = lastFullIdx + 1; i < list.length; i++) {
          final distance =
              list[i].odometer - list[lastFullIdx].odometer;
          final double sumVolume = list
              .sublist(lastFullIdx + 1, i + 1)
              .fold(0.0, (s, e) => s + e.volume);
          updates[list[i].id!] = calcBlockConsumption(
              distance: distance, sumVolume: sumVolume);
        }
      }
    }

    calculateList(fuelEntries);
    calculateList(chargeEntries);

    // Применим все обновления к базе данных
    for (final entry in all) {
      if (!updates.containsKey(entry.id)) continue;
      final newConsumption = updates[entry.id];
      if (entry.consumption != newConsumption) {
        final updated = entry.copyWith(
          consumption: newConsumption,
          clearConsumption: newConsumption == null,
        );
        await FuelDatabase.instance.updateEntry(updated);
      }
    }
  }

  // ─────────────────────────────── Validation Helpers ──

  /// Расчёт предварительного расхода для предпросмотра при вводе.
  ///
  /// Возвращает null если данных недостаточно или расстояние слишком мало.
  double? previewConsumption({
    required double odometer,
    required double volume,
    required double? prevOdometer,
    required bool isFullTank,
    required List<FuelEntry> tailPartials,
  }) {
    if (prevOdometer == null) return null;
    final distance = odometer - prevOdometer;
    if (distance < kMinDistanceKm) return null;

    // Суммируем объёмы хвостовых частичных + текущий
    double totalVolume = tailPartials.fold(0.0, (s, e) => s + e.volume) + volume;
    return (totalVolume / distance) * 100;
  }

  /// Проверяет, является ли предварительный расход аномальным.
  AnomalyWarning? checkAnomalyWarning({
    required double odometer,
    required double volume,
    required double? prevOdometer,
    required String entryType,
  }) {
    if (prevOdometer == null) return null;
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

    final maxVol = entryType == 'charge' ? kMaxSingleEvVolume : kMaxSingleFuelVolume;
    if (volume > maxVol) {
      return AnomalyWarning.volumeTooLarge;
    }

    if (distance >= kMinDistanceKm) {
      final cons = (volume / distance) * 100;
      if (entryType == 'charge') {
        if (cons > kMaxReasonableConsumptionEv || cons < kMinReasonableConsumptionEv) {
          return AnomalyWarning.consumptionAnomalous;
        }
      } else {
        if (cons > kMaxReasonableConsumptionFuel || cons < kMinReasonableConsumptionFuel) {
          return AnomalyWarning.consumptionAnomalous;
        }
      }
    }

    return null;
  }

  // ─────────────────────────────────────── Reminder ──

  /// Проверяет, нужно ли показать напоминание о заправке.
  Future<void> checkAllReminders() async {
    final vehicles = _vehicleCtrl.vehicles;
    for (final vehicle in vehicles) {
      if (vehicle.reminderDays == null || vehicle.id == null) continue;
      await _checkReminder(vehicle.id!);
    }
  }

  Future<void> _checkReminder(int vehicleId) async {
    final vehicle = _vehicleCtrl.vehicles
        .firstWhereOrNull((v) => v.id == vehicleId);
    if (vehicle == null || vehicle.reminderDays == null) return;

    final lastDate =
        await FuelDatabase.instance.getLastEntryDate(vehicleId);
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

  /// Возвращает только записи с рассчитанным расходом (для графика).
  List<FuelEntry> get entriesWithConsumption =>
      entries.where((e) => e.consumption != null).toList();

  /// Одометр последней записи (для валидации новой записи).
  double? get lastOdometer =>
      entries.isNotEmpty ? entries.last.odometer : null;

  /// Возвращает хвостовые частичные заправки после последней полной
  /// (нужно для предпросмотра расхода при добавлении новой полной заправки).
  List<FuelEntry> getTailPartials(String entryType) {
    final filtered =
        entries.where((e) => e.entryType == entryType).toList();
    if (filtered.isEmpty) return [];

    // Ищем с конца последнюю полную
    int lastFullIdx = -1;
    for (int i = filtered.length - 1; i >= 0; i--) {
      if (filtered[i].isFullTank) {
        lastFullIdx = i;
        break;
      }
    }
    if (lastFullIdx == -1) return filtered; // нет полных — все хвост
    return filtered.sublist(lastFullIdx + 1);
  }
}

// ─────────────────────── Anomaly Warning Enum ────────────────────────────────

/// Типы предупреждений при вводе записи.
enum AnomalyWarning {
  /// Одометр меньше предыдущего.
  odometerDecreased,

  /// Расстояние слишком маленькое (< 10 км) — расход не будет рассчитан.
  distanceTooSmall,

  /// Расстояние слишком большое (> 3000 км) — возможна ошибка ввода.
  distanceTooLarge,

  /// Введённый объём нереально большой.
  volumeTooLarge,

  /// Предварительный расход выходит за разумные пределы.
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

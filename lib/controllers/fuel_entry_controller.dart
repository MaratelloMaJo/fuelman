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

/// Контроллер записей о заправках.
///
/// Ключевая ответственность:
///   — CRUD операции с [FuelEntry]
///   — Алгоритм Full-to-Full (пересчёт расхода после каждого изменения)
///   — Агрегированная статистика
///   — Экспорт в CSV через share_plus
///   — Проверка напоминаний о заправке
class FuelEntryController extends GetxController {
  final entries = <FuelEntry>[].obs;
  final stats = <String, double?>{}.obs;
  final isLoading = false.obs;

  final _vehicleCtrl = Get.find<VehicleController>();

  @override
  void onInit() {
    super.onInit();
    // Перезагружаем данные при смене активного автомобиля.
    ever(_vehicleCtrl.selectedVehicle, (_) => _onVehicleChanged());
    _onVehicleChanged();
  }

  void _onVehicleChanged() {
    final v = _vehicleCtrl.selectedVehicle.value;
    if (v != null) {
      loadEntries(v.id!);
    } else {
      entries.clear();
      stats.clear();
    }
  }

  // ───────────────────────────────────────── Load ──

  Future<void> loadEntries(int vehicleId) async {
    isLoading.value = true;
    try {
      final list = await FuelDatabase.instance.getEntries(vehicleId);
      entries.assignAll(list);
      await _loadStats(vehicleId);
    } finally {
      isLoading.value = false;
    }
  }

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
         double vol = settings.convertVolume(e.volume, e.volumeUnit, settings.volumeUnit.value);
         totalVolume += vol;
      } else if (e.entryType == 'charge') {
         totalEvVolume += e.volume; // кВт·ч не конвертируем
      }
      
      double cost = e.totalCost ?? 0.0;
      double convertedCost = currencySvc.convert(cost, e.currency, settings.currency.value);
      totalCost += convertedCost;
      
      if (e.consumption != null) {
        if (e.entryType == 'fuel') {
           double cons = settings.convertVolume(e.consumption!, e.volumeUnit, settings.volumeUnit.value);
           if (cons < minCons) minCons = cons;
           if (cons > maxCons) maxCons = cons;
           sumCons += cons;
           calcEntries++;
        } else if (e.entryType == 'charge') {
           // кВт·ч/100 км — не конвертируем
           sumEvCons += e.consumption!;
           calcEvEntries++;
        }
      }
    }
    
    double? avgCons = calcEntries > 0 ? sumCons / calcEntries : null;
    double? avgEvCons = calcEvEntries > 0 ? sumEvCons / calcEvEntries : null;
    if (minCons == double.infinity) minCons = 0;
    
    double? costPerKm;
    double? kmPerDay;
    double? costPerDay;
    
    if (all.length >= 2 && firstDate != null && lastDate != null) {
       double distance = maxOdo - minOdo;
       int days = lastDate.difference(firstDate).inDays;
       if (days == 0) days = 1;
       
       if (distance > 0) costPerKm = totalCost / distance;
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
         double vol = settings.convertVolume(e.volume, e.volumeUnit, settings.volumeUnit.value);
         stat.totalVolume += vol;
      }
      
      if (e.totalCost != null) {
         double cost = e.totalCost!;
         double convertedCost = currencySvc.convert(cost, e.currency, settings.currency.value);
         stat.totalCost += convertedCost;
      }
      
      if (e.consumption != null && e.entryType == 'fuel') {
         double cons = settings.convertVolume(e.consumption!, e.volumeUnit, settings.volumeUnit.value);
         stat.sumConsumption += cons;
         stat.calcEntries++;
      }
    }

    final list = map.values.toList()..sort((a, b) => a.month.compareTo(b.month));

    return list.map((s) => {
      'month': s.month,
      'avg_consumption': s.calcEntries > 0 ? s.sumConsumption / s.calcEntries : null,
      'total_volume': s.totalVolume,
      'total_cost': s.totalCost,
    }).toList();
  }

  // ───────────────────────────────────────── Add ──

  Future<void> addEntry(FuelEntry entry) async {
    // 1. Сохраняем запись в БД (без расхода — будет пересчитан ниже).
    final saved = await FuelDatabase.instance.insertEntry(entry);
    entries.add(saved);

    // 2. Пересчитываем расход для ВСЕХ записей этого авто (Full-to-Full).
    await _recalculateConsumption(entry.vehicleId);

    // 3. Перезагружаем список и статистику после пересчёта.
    await loadEntries(entry.vehicleId);

    // 4. Проверяем напоминания (сброс при новой заправке).
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

  // ─────────────────────────────── Full-to-Full Algorithm ──

  /// Алгоритм Full-to-Full для расчёта расхода топлива.
  ///
  /// Логика:
  ///   1. Записи сортируются по дате ASC.
  ///   2. Накапливаем объём топлива с момента последнего "полного бака".
  ///   3. Когда встречаем новый "полный бак", рассчитываем расход:
  ///      расход = накопленный_объём / пройденное_расстояние * 100
  ///   4. Первая запись "полный бак" получает consumption = null
  ///      (нет предыдущей точки отсчёта).
  ///   5. Дозаправки (isFullTank == false) всегда имеют consumption = null.
  Future<void> _recalculateConsumption(int vehicleId) async {
    final all = await FuelDatabase.instance.getEntries(vehicleId);

    double? prevFullOdoFuel;
    double? prevFullOdoCharge;
    double accumulatedFuel = 0.0;
    double accumulatedCharge = 0.0;

    for (final entry in all) {
      final double? newConsumption;
      final isFuel = entry.entryType == 'fuel';

      if (!entry.isFullTank) {
        if (isFuel) {
          accumulatedFuel += entry.volume;
        } else {
          accumulatedCharge += entry.volume;
        }
        newConsumption = null;
      } else {
        if (isFuel) {
          accumulatedFuel += entry.volume;
          if (prevFullOdoFuel != null) {
            final distance = entry.odometer - prevFullOdoFuel;
            newConsumption = distance > 0 ? (accumulatedFuel / distance * 100) : null;
          } else {
            newConsumption = null;
          }
          prevFullOdoFuel = entry.odometer;
          accumulatedFuel = 0.0;
        } else {
          accumulatedCharge += entry.volume;
          if (prevFullOdoCharge != null) {
            final distance = entry.odometer - prevFullOdoCharge;
            newConsumption = distance > 0 ? (accumulatedCharge / distance * 100) : null;
          } else {
            newConsumption = null;
          }
          prevFullOdoCharge = entry.odometer;
          accumulatedCharge = 0.0;
        }
      }

      if (entry.consumption != newConsumption) {
        final updated = entry.copyWith(
          consumption: newConsumption,
          clearConsumption: newConsumption == null,
        );
        await FuelDatabase.instance.updateEntry(updated);
      }
    }
  }

  // ─────────────────────────────────────── Reminder ──

  /// Проверяет, нужно ли показать напоминание о заправке.
  /// Вызывается при старте приложения и после добавления записи.
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
      // Отменяем ранее показанное уведомление (заправился).
      await NotificationService.instance.cancel(vehicleId);
    }
  }

  // ───────────────────────────────────── CSV Export ──

  /// Генерирует CSV-файл с данными выбранного автомобиля
  /// и открывает системный диалог «Поделиться».
  Future<void> exportToCsv(int vehicleId, String vehicleName) async {
    final all = await FuelDatabase.instance.getEntries(vehicleId);
    if (all.isEmpty) {
      Get.snackbar('Нет данных', 'Нет записей для экспорта',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final fmt = DateFormat('dd.MM.yyyy');
    final buf = StringBuffer();

    // Заголовок CSV с BOM для корректного отображения в Excel.
    buf.writeln(
      '\uFEFFДата,Одометр (км),Объём,Ед.изм,Цена/ед,Валюта,Стоимость,Расход,Тип,Энергия',
    );

    for (final e in all) {
      final fillType = e.isFullTank ? 'Полный' : 'Частичный';
      final energy = e.entryType == 'charge' ? 'Зарядка' : 'Топливо';
      final cost = e.totalCost?.toStringAsFixed(2) ?? '';
      final cons = e.consumption?.toStringAsFixed(2) ?? '—';
      final price = e.pricePerLiter?.toStringAsFixed(2) ?? '';

      buf.writeln(
        '${fmt.format(e.date)},${e.odometer.toStringAsFixed(1)},${e.volume.toStringAsFixed(2)},${e.volumeUnit},$price,${e.currency},$cost,$cons,$fillType,$energy',
      );
    }

    // Пишем во временный файл и передаём системному диалогу.
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
}

class _MonthStat {
  final String month;
  double sumConsumption = 0.0;
  double totalVolume = 0.0;
  double totalCost = 0.0;
  int calcEntries = 0;

  _MonthStat(this.month);
}

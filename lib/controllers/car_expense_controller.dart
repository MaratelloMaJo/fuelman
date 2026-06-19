import 'dart:io';

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/fuel_database.dart';
import '../models/car_expense.dart';
import 'vehicle_controller.dart';
import 'settings_controller.dart';
import '../services/currency_service.dart';

/// Контроллер расходов на уход за автомобилем.
class CarExpenseController extends GetxController {
  final expenses = <CarExpense>[].obs;
  final expenseStats = <String, double>{}.obs;
  final isLoading = false.obs;

  final _vehicleCtrl = Get.find<VehicleController>();

  @override
  void onInit() {
    super.onInit();
    ever(_vehicleCtrl.selectedVehicle, (_) => _onVehicleChanged());
    _onVehicleChanged();
  }

  void _onVehicleChanged() {
    final v = _vehicleCtrl.selectedVehicle.value;
    if (v != null) {
      loadExpenses(v.id!);
    } else {
      expenses.clear();
      expenseStats.clear();
    }
  }

  // ─────────────────────────────────── Load ──

  Future<void> loadExpenses(int vehicleId) async {
    isLoading.value = true;
    try {
      final list = await FuelDatabase.instance.getExpenses(vehicleId);
      expenses.assignAll(list);
      await _loadStats(vehicleId);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadStats(int vehicleId) async {
    final settings = Get.find<SettingsController>();
    final currencySvc = CurrencyService.instance;
    final all = await FuelDatabase.instance.getExpenses(vehicleId);

    final Map<String, double> stats = {};
    for (final e in all) {
      final converted = currencySvc.convert(e.amount, e.currency, settings.currency.value);
      stats[e.category] = (stats[e.category] ?? 0.0) + converted;
    }
    expenseStats.assignAll(stats);
  }

  // ─────────────────────────────────── CRUD ──

  Future<void> addExpense(CarExpense expense) async {
    await FuelDatabase.instance.insertExpense(expense);
    final v = _vehicleCtrl.selectedVehicle.value;
    if (v != null) await loadExpenses(v.id!);
  }

  Future<void> updateExpense(CarExpense expense) async {
    await FuelDatabase.instance.updateExpense(expense);
    final v = _vehicleCtrl.selectedVehicle.value;
    if (v != null) await loadExpenses(v.id!);
  }

  Future<void> deleteExpense(int expenseId) async {
    await FuelDatabase.instance.deleteExpense(expenseId);
    expenses.removeWhere((e) => e.id == expenseId);
    final v = _vehicleCtrl.selectedVehicle.value;
    if (v != null) await _loadStats(v.id!);
  }

  // ─────────────────────────── Monthly Stats ──

  Future<List<Map<String, dynamic>>> getMonthlyExpenses(int vehicleId) async {
    return FuelDatabase.instance.getMonthlyExpenses(vehicleId);
  }

  // ─────────────────────────── Total for period ──

  double get totalExpenses {
    final settings = Get.find<SettingsController>();
    final currencySvc = CurrencyService.instance;
    return expenses.fold(0.0, (sum, e) {
      return sum + currencySvc.convert(e.amount, e.currency, settings.currency.value);
    });
  }

  // ─────────────────────────────── CSV Export ──

  Future<void> exportToCsv(int vehicleId, String vehicleName) async {
    final all = await FuelDatabase.instance.getExpenses(vehicleId);
    if (all.isEmpty) {
      Get.snackbar('Нет данных', 'Нет записей о расходах для экспорта',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final fmt = DateFormat('dd.MM.yyyy');
    final buf = StringBuffer();

    buf.writeln(
      '\uFEFFДата,Категория,Название,Сумма,Валюта,Одометр,Место,Широта,Долгота,Заметки',
    );

    for (final e in all) {
      final cat = _categoryLabel(e.category);
      final odo = e.odometer?.toStringAsFixed(0) ?? '';
      final lat = e.latitude?.toStringAsFixed(6) ?? '';
      final lon = e.longitude?.toStringAsFixed(6) ?? '';
      final place = e.placeName ?? '';
      final notes = (e.notes ?? '').replaceAll(',', ';');
      final title = e.title.replaceAll(',', ';');

      buf.writeln(
        '${fmt.format(e.date)},$cat,$title,${e.amount.toStringAsFixed(2)},${e.currency},$odo,$place,$lat,$lon,$notes',
      );
    }

    final dir = await getTemporaryDirectory();
    final safeName = vehicleName.replaceAll(RegExp(r'[^\w]'), '_');
    final file = File('${dir.path}/fuelman_expenses_$safeName.csv');
    await file.writeAsString(buf.toString());

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'FuelMan — расходы: $vehicleName',
      ),
    );
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'service': return 'Сервис';
      case 'oil_change': return 'Замена масла';
      case 'wash': return 'Мойка';
      case 'tires': return 'Шины';
      case 'tax': return 'Налог/страховка';
      case 'parts': return 'Запчасти';
      default: return 'Другое';
    }
  }
}

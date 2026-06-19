import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/car_expense_controller.dart';
import '../controllers/fuel_entry_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/vehicle_controller.dart';
import '../models/car_expense.dart';
import '../models/fuel_entry.dart';
import '../widgets/empty_state.dart';
import '../widgets/expense_tile.dart';
import '../widgets/fuel_entry_tile.dart';
import 'add_entry_screen.dart';
import 'add_expense_screen.dart';

/// Вкладка истории — содержит 2 подраздела: Топливо и Уход.
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

enum _Period { all, month, quarter, year }

extension on _Period {
  String get labelKey {
    switch (this) {
      case _Period.all:    return 'period_all';
      case _Period.month:  return 'period_month';
      case _Period.quarter: return 'period_quarter';
      case _Period.year:   return 'period_year';
    }
  }
}

class _HistoryTabState extends State<HistoryTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  _Period _period = _Period.all;

  final _entryCtrl = Get.find<FuelEntryController>();
  final _expenseCtrl = Get.find<CarExpenseController>();
  final _vehicleCtrl = Get.find<VehicleController>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<FuelEntry> _applyFuelFilter(List<FuelEntry> all) {
    if (_period == _Period.all) return all;
    final cutoff = _getCutoff();
    return all.where((e) => e.date.isAfter(cutoff)).toList();
  }

  List<CarExpense> _applyExpenseFilter(List<CarExpense> all) {
    if (_period == _Period.all) return all;
    final cutoff = _getCutoff();
    return all.where((e) => e.date.isAfter(cutoff)).toList();
  }

  DateTime _getCutoff() {
    final now = DateTime.now();
    return switch (_period) {
      _Period.month   => DateTime(now.year, now.month - 1, now.day),
      _Period.quarter => DateTime(now.year, now.month - 3, now.day),
      _Period.year    => DateTime(now.year - 1, now.month, now.day),
      _Period.all     => DateTime(2000),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('history_title'.tr),
        centerTitle: true,
        actions: [
          Obx(() {
            final vehicle = _vehicleCtrl.selectedVehicle.value;
            if (vehicle == null) return const SizedBox.shrink();
            return PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (val) {
                if (val == 'export_fuel') {
                  _entryCtrl.exportToCsv(vehicle.id!, vehicle.name);
                } else if (val == 'export_expenses') {
                  _expenseCtrl.exportToCsv(vehicle.id!, vehicle.name);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'export_fuel',
                  child: Row(children: [
                    const Icon(Icons.local_gas_station_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text('export_csv'.tr),
                  ]),
                ),
                PopupMenuItem(
                  value: 'export_expenses',
                  child: Row(children: [
                    const Icon(Icons.build_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text('export_expenses_csv'.tr),
                  ]),
                ),
              ],
            );
          }),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'history_fuel_tab'.tr),
            Tab(text: 'history_care_tab'.tr),
          ],
        ),
      ),
      body: Obx(() {
        final vehicle = _vehicleCtrl.selectedVehicle.value;

        if (vehicle == null) {
          return EmptyState(
            icon: Icons.directions_car_outlined,
            title: 'no_vehicle'.tr,
            subtitle: 'select_vehicle_hint'.tr,
          );
        }

        return Column(
          children: [
            // ── Фильтр периода ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<_Period>(
                  showSelectedIcon: false,
                  segments: _Period.values
                      .map((p) => ButtonSegment(
                            value: p,
                            label: Text(p.labelKey.tr),
                          ))
                      .toList(),
                  selected: {_period},
                  onSelectionChanged: (s) =>
                      setState(() => _period = s.first),
                ),
              ),
            ),

            // ── Контент вкладок ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ── Вкладка: Топливо ──
                  _FuelHistoryList(
                    period: _period,
                    filter: _applyFuelFilter,
                  ),

                  // ── Вкладка: Уход ──
                  _CareHistoryList(
                    period: _period,
                    filter: _applyExpenseFilter,
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ─────────────────────── Fuel History List ──

class _FuelHistoryList extends StatelessWidget {
  final _Period period;
  final List<FuelEntry> Function(List<FuelEntry>) filter;

  const _FuelHistoryList({required this.period, required this.filter});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entryCtrl = Get.find<FuelEntryController>();
    final settingsCtrl = Get.find<SettingsController>();
    final avgConsumption = entryCtrl.stats['avg_consumption'];

    final filtered = filter(
      List<FuelEntry>.from(entryCtrl.entries).reversed.toList(),
    );

    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.local_gas_station_outlined,
        title: 'no_entries'.tr,
        subtitle: period == _Period.all ? 'no_entries_hint'.tr : 'no_entries_period'.tr,
      );
    }

    return Column(
      children: [
        // Итог
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              Text(
                '${filtered.length} ${'entries_count'.tr}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const Spacer(),
              if (filtered.any((e) => e.totalCost != null))
                Text(
                  '${'total_prefix'.tr}${filtered.fold<double>(0, (s, e) => s + (e.totalCost ?? 0)).toStringAsFixed(0)} ${settingsCtrl.currencySymbol}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 32),
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final entry = filtered[i];
              final double? prevOdo = (i + 1 < filtered.length)
                  ? filtered[i + 1].odometer
                  : null;
              return FuelEntryTile(
                entry: entry,
                avgConsumption: avgConsumption,
                prevOdometer: prevOdo,
                onTap: () => Get.to(() => AddEntryScreen(editEntry: entry)),
                onDelete: () async {
                  await entryCtrl.deleteEntry(entry.id!, entry.vehicleId);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────── Care History List ──

class _CareHistoryList extends StatefulWidget {
  final _Period period;
  final List<CarExpense> Function(List<CarExpense>) filter;

  const _CareHistoryList({required this.period, required this.filter});

  @override
  State<_CareHistoryList> createState() => _CareHistoryListState();
}

class _CareHistoryListState extends State<_CareHistoryList> {
  String _categoryFilter = 'all';

  static const _categories = [
    'all', 'service', 'oil_change', 'wash', 'tires', 'tax', 'parts', 'other',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final expenseCtrl = Get.find<CarExpenseController>();
    final settingsCtrl = Get.find<SettingsController>();

    final List<CarExpense> periodFiltered = widget.filter(
      List<CarExpense>.from(expenseCtrl.expenses),
    );

    final filtered = _categoryFilter == 'all'
        ? periodFiltered
        : periodFiltered.where((e) => e.category == _categoryFilter).toList();

    final total = filtered.fold<double>(0, (s, e) => s + e.amount);

    return Column(
      children: [
        // ── Фильтр категорий ──
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final cat = _categories[i];
              final isActive = _categoryFilter == cat;
              return FilterChip(
                label: Text('cat_$cat'.tr),
                selected: isActive,
                showCheckmark: false,
                onSelected: (_) => setState(() => _categoryFilter = cat),
                selectedColor: cs.primaryContainer,
                backgroundColor: cs.surfaceContainerHighest,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                  color: isActive ? cs.onPrimaryContainer : cs.onSurface,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              );
            },
          ),
        ),

        // Итог
        if (filtered.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
            child: Row(
              children: [
                Text(
                  '${filtered.length} ${'entries_count'.tr}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
                const Spacer(),
                Text(
                  '${'total_prefix'.tr}${total.toStringAsFixed(0)} ${settingsCtrl.currencySymbol}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),

        // ── Список ──
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(
                  icon: Icons.build_outlined,
                  title: 'care_no_entries'.tr,
                  subtitle: 'care_no_entries_hint'.tr,
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 32),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final expense = filtered[i];
                    return ExpenseTile(
                      expense: expense,
                      onTap: () => Get.to(() => AddExpenseScreen(editExpense: expense)),
                      onDelete: () => expenseCtrl.deleteExpense(expense.id!),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

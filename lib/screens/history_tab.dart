import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/fuel_entry_controller.dart';
import '../controllers/vehicle_controller.dart';
import '../models/fuel_entry.dart';
import '../widgets/empty_state.dart';
import '../widgets/fuel_entry_tile.dart';
import 'add_entry_screen.dart';
import '../controllers/settings_controller.dart';

/// Вкладка истории заправок.
///
/// Особенности:
///   — Фильтрация по периоду (месяц / квартал / год / всё время)
///   — Поиск по дате/объёму (через строку поиска)
///   — Swipe-to-delete с пересчётом расхода
///   — Кнопка экспорта в CSV (share_plus)
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

enum _Period { all, month, quarter, year }

extension on _Period {
  String get label {
    switch (this) {
      case _Period.all:
        return 'Всё время';
      case _Period.month:
        return 'Месяц';
      case _Period.quarter:
        return 'Квартал';
      case _Period.year:
        return 'Год';
    }
  }
}

class _HistoryTabState extends State<HistoryTab> {
  _Period _period = _Period.all;

  final _entryCtrl = Get.find<FuelEntryController>();
  final _vehicleCtrl = Get.find<VehicleController>();

  List<FuelEntry> _applyFilter(List<FuelEntry> all) {
    if (_period == _Period.all) return all;
    final now = DateTime.now();
    final cutoff = switch (_period) {
      _Period.month => DateTime(now.year, now.month - 1, now.day),
      _Period.quarter => DateTime(now.year, now.month - 3, now.day),
      _Period.year => DateTime(now.year - 1, now.month, now.day),
      _Period.all => DateTime(2000),
    };
    return all.where((e) => e.date.isAfter(cutoff)).toList();
  }


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('history_title'.tr),
        centerTitle: true,
      ),
      floatingActionButton: Obx(() {
        if (_vehicleCtrl.selectedVehicle.value == null) {
          return const SizedBox.shrink();
        }
        // Показываем «Зарядка» для электромобилей
        final vehicle = _vehicleCtrl.selectedVehicle.value!;
        final isElectric = vehicle.isFullyElectric;
        return FloatingActionButton.extended(
          heroTag: 'history_fab',
          onPressed: () => Get.to(() => const AddEntryScreen()),
          icon: Icon(isElectric ? Icons.bolt_rounded : Icons.add_rounded),
          label: Text(isElectric ? 'charge_fab'.tr : 'refuel_fab'.tr),
        );
      }),
      body: Obx(() {
        final vehicle = _vehicleCtrl.selectedVehicle.value;
        final avgConsumption =
            _entryCtrl.stats['avg_consumption'];

        if (vehicle == null) {
          return EmptyState(
            icon: Icons.directions_car_outlined,
            title: 'no_vehicle'.tr,
            subtitle: 'select_vehicle_hint'.tr,
          );
        }

        final filtered = _applyFilter(
          List<FuelEntry>.from(_entryCtrl.entries).reversed.toList(),
        );

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
                            label: Text(p.label),
                          ))
                      .toList(),
                  selected: {_period},
                  onSelectionChanged: (s) =>
                      setState(() => _period = s.first),
                ),
              ),
            ),

            // ── Итог по фильтру ──
            if (filtered.isNotEmpty)
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
                        '${'total_prefix'.tr}${filtered.fold<double>(0, (s, e) => s + (e.totalCost ?? 0)).toStringAsFixed(0)} ${Get.find<SettingsController>().currencySymbol}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
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
                      icon: Icons.history_rounded,
                      title: 'no_entries'.tr,
                      subtitle: _period == _Period.all
                          ? 'no_entries_hint'.tr
                          : 'no_entries_period'.tr,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final entry = filtered[i];
                        // Предыдущий одометр: запись следующая в filtered (filtered DESC)
                        final double? prevOdo = (i + 1 < filtered.length)
                            ? filtered[i + 1].odometer
                            : null;
                        return FuelEntryTile(
                          entry: entry,
                          avgConsumption: avgConsumption,
                          prevOdometer: prevOdo,
                          onTap: () => Get.to(() => AddEntryScreen(editEntry: entry)),
                          onDelete: () async {
                            await _entryCtrl.deleteEntry(
                              entry.id!,
                              entry.vehicleId,
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      }),
    );
  }
}

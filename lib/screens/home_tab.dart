import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/fuel_entry_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/vehicle_controller.dart';
import '../models/vehicle.dart';
import '../widgets/consumption_chart.dart';
import '../widgets/empty_state.dart';
import '../widgets/fuel_entry_tile.dart';
import '../widgets/goal_progress_bar.dart';
import '../widgets/stats_card.dart';
import 'add_entry_screen.dart';

/// Главный экран (вкладка «Главная»).
///
/// Содержит:
///   — Горизонтальный скролл выбора автомобиля
///   — Карточки статистики (avg/min/max расход, общая стоимость)
///   — Прогресс-бар цели по расходу (если задана)
///   — Переключаемый график расхода / стоимости
///   — Последние 3 записи
///   — FAB для добавления новой заправки
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final vehicleCtrl = Get.find<VehicleController>();
    final entryCtrl = Get.find<FuelEntryController>();
    final settingsCtrl = Get.find<SettingsController>();

    return Scaffold(
      appBar: AppBar(
        title: Text('app_title'.tr),
        centerTitle: false,
      ),
      floatingActionButton: Obx(() {
        if (vehicleCtrl.selectedVehicle.value == null) {
          return const SizedBox.shrink();
        }
        // Показываем «Зарядка» для электромобилей
        final vehicle = vehicleCtrl.selectedVehicle.value!;
        final isElectric = vehicle.isFullyElectric;
        return FloatingActionButton.extended(
          heroTag: 'home_fab',
          onPressed: () => Get.to(() => const AddEntryScreen()),
          icon: Icon(isElectric ? Icons.bolt_rounded : Icons.add_rounded),
          label: Text(isElectric ? 'charge_fab'.tr : 'refuel_fab'.tr),
        );
      }),
      body: Obx(() {
        final vehicles = vehicleCtrl.vehicles;

        // Нет автомобилей — показываем онбординг
        if (vehicles.isEmpty) {
          return EmptyState(
            icon: Icons.directions_car_outlined,
            title: 'add_vehicle_prompt'.tr,
            subtitle: 'add_vehicle_subtitle'.tr,
            actionLabel: null,
            onAction: null,
          );
        }

        final selected = vehicleCtrl.selectedVehicle.value;
        final entries = entryCtrl.entries;
        final chartEntries = entryCtrl.entriesWithConsumption;
        final stats = entryCtrl.stats;
        final avgConsumption = stats['avg_consumption'];

        return RefreshIndicator(
          onRefresh: () async {
            if (selected != null) await entryCtrl.loadEntries(selected.id!);
          },
          child: CustomScrollView(
            slivers: [
              // ── Выбор автомобиля ──
              SliverToBoxAdapter(
                child: _VehicleSelector(
                  vehicles: vehicles,
                  selected: selected,
                  onSelect: vehicleCtrl.selectVehicle,
                ),
              ),

              if (selected == null) ...[
                const SliverFillRemaining(
                  child: Center(child: Text('Выберите автомобиль')),
                ),
              ] else ...[
                // ── Статистика ──
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.3,
                    children: [
                      StatsCard(
                        icon: Icons.show_chart_rounded,
                        value: avgConsumption != null
                            ? '${avgConsumption.toStringAsFixed(1)} ${settingsCtrl.volumeUnit.value}'
                            : 'no_data'.tr,
                        label: 'avg_consumption'.tr,
                      ),
                      StatsCard(
                        icon: Icons.payments_rounded,
                        value: stats['cost_per_km'] != null
                            ? '${stats['cost_per_km']!.toStringAsFixed(2)} ${settingsCtrl.currencySymbol}'
                            : 'no_data'.tr,
                        label: 'cost_per_km'.tr,
                        valueColor: Colors.orange,
                      ),
                      StatsCard(
                        icon: Icons.directions_car_rounded,
                        value: stats['km_per_day'] != null
                            ? '${stats['km_per_day']!.toStringAsFixed(1)} ${'km_unit'.tr}'
                            : 'no_data'.tr,
                        label: 'km_per_day'.tr,
                        valueColor: Colors.blue,
                      ),
                      StatsCard(
                        icon: Icons.account_balance_wallet_rounded,
                        value: stats['total_cost'] != null &&
                                stats['total_cost']! > 0
                            ? '${stats['total_cost']!.toStringAsFixed(0)} ${settingsCtrl.currencySymbol}'
                            : 'no_data'.tr,
                        label: 'total_spent'.tr,
                        valueColor: Colors.green,
                      ),
                    ],
                  ),
                ),

                // ── Цель по расходу ──
                if (selected.fuelGoal != null && avgConsumption != null)
                  SliverPadding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: GoalProgressBar(
                        current: avgConsumption,
                        goal: selected.fuelGoal!,
                      ),
                    ),
                  ),

                // ── График ──
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: ConsumptionChart(entries: chartEntries),
                  ),
                ),

                // ── Последние записи ──
                if (entries.isNotEmpty) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        'last_refuels'.tr,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  SliverList.builder(
                    itemCount: entries.length.clamp(0, 3),
                    itemBuilder: (_, i) {
                      final e = entries[entries.length - 1 - i]; // последние первыми
                      return FuelEntryTile(
                        entry: e,
                        avgConsumption: avgConsumption,
                      );
                    },
                  ),
                ] else ...[
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.local_gas_station_outlined,
                      title: 'no_entries'.tr,
                      subtitle: 'no_entries_hint'.tr,
                    ),
                  ),
                ],

                // Отступ для FAB
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ],
          ),
        );
      }),
    );
  }
}

// ─────────────────────────── Vehicle Selector ──

class _VehicleSelector extends StatelessWidget {
  final List<Vehicle> vehicles;
  final Vehicle? selected;
  final void Function(Vehicle) onSelect;

  const _VehicleSelector({
    required this.vehicles,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: vehicles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final v = vehicles[i];
          final isActive = selected?.id == v.id;
          return FilterChip(
            label: Text(v.name),
            selected: isActive,
            onSelected: (_) => onSelect(v),
            avatar: Icon(
              _iconForType(v.iconType),
              size: 16,
              color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
            ),
            showCheckmark: false,
            backgroundColor: cs.surfaceContainerHighest,
            selectedColor: cs.primary,
            labelStyle: TextStyle(
              color: isActive ? cs.onPrimary : cs.onSurface,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          );
        },
      ),
    );
  }

  static IconData _iconForType(String type) {
    switch (type) {
      case 'hatchback':
        return Icons.directions_car_filled_rounded;
      case 'suv':
        return Icons.airport_shuttle_rounded;
      case 'crossover':
        return Icons.drive_eta_rounded;
      case 'truck':
        return Icons.local_shipping_rounded;
      case 'van':
        return Icons.airport_shuttle_rounded;
      case 'moto':
        return Icons.two_wheeler_rounded;
      case 'other':
        return Icons.commute_rounded;
      default:
        return Icons.directions_car_rounded; // sedan
    }
  }
}

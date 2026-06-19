import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/car_expense_controller.dart';
import '../controllers/fuel_entry_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/vehicle_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/expense_category_icon.dart';
import '../widgets/stats_card.dart';

/// Вкладка детальной статистики с двумя разделами: Топливо и Уход.
class StatisticsTab extends StatefulWidget {
  const StatisticsTab({super.key});

  @override
  State<StatisticsTab> createState() => _StatisticsTabState();
}

class _StatisticsTabState extends State<StatisticsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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

  @override
  Widget build(BuildContext context) {
    final vehicleCtrl = Get.find<VehicleController>();

    return Scaffold(
      appBar: AppBar(
        title: Text('statistics_title'.tr),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'stats_tab_fuel'.tr),
            Tab(text: 'stats_tab_care'.tr),
          ],
        ),
      ),
      body: Obx(() {
        final vehicle = vehicleCtrl.selectedVehicle.value;

        if (vehicle == null) {
          return EmptyState(
            icon: Icons.bar_chart_rounded,
            title: 'stats_no_data_title'.tr,
            subtitle: 'select_vehicle_hint'.tr,
          );
        }

        return TabBarView(
          controller: _tabController,
          children: [
            _FuelStatsView(vehicleId: vehicle.id!, vehicleName: vehicle.name),
            _CareStatsView(vehicleId: vehicle.id!, vehicleName: vehicle.name),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────── Fuel Stats ──

class _FuelStatsView extends StatelessWidget {
  final int vehicleId;
  final String vehicleName;

  const _FuelStatsView({required this.vehicleId, required this.vehicleName});

  @override
  Widget build(BuildContext context) {
    final entryCtrl = Get.find<FuelEntryController>();
    final settingsCtrl = Get.find<SettingsController>();
    final stats = entryCtrl.stats;
    final totalEntries = stats['total_entries']?.toInt() ?? 0;

    if (totalEntries == 0) {
      return EmptyState(
        icon: Icons.bar_chart_rounded,
        title: 'stats_no_entries_title'.tr,
        subtitle: 'stats_no_entries_subtitle'.tr,
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: entryCtrl.getMonthlyStats(vehicleId),
      builder: (context, snap) {
        final monthly = snap.data ?? [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Сводные карточки ──
            Text(
              '${'stats_summary_prefix'.tr}$vehicleName',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            Builder(builder: (context) {
              String volumeText = '';
              if (stats['total_volume'] != null && stats['total_volume']! > 0) {
                volumeText +=
                    '${stats['total_volume']!.toStringAsFixed(1)} ${settingsCtrl.volumeUnit.value}';
              }
              if (stats['total_ev_volume'] != null &&
                  stats['total_ev_volume']! > 0) {
                if (volumeText.isNotEmpty) volumeText += '\n';
                volumeText +=
                    '${stats['total_ev_volume']!.toStringAsFixed(1)} kWh';
              }
              if (volumeText.isEmpty) volumeText = 'no_data'.tr;

              String avgText = '';
              if (stats['avg_consumption'] != null &&
                  stats['avg_consumption']! > 0) {
                avgText +=
                    '${stats['avg_consumption']!.toStringAsFixed(1)} ${settingsCtrl.volumeUnit.value}';
              }
              if (stats['avg_ev_consumption'] != null &&
                  stats['avg_ev_consumption']! > 0) {
                if (avgText.isNotEmpty) avgText += '\n';
                avgText +=
                    '${stats['avg_ev_consumption']!.toStringAsFixed(1)} kWh';
              }
              if (avgText.isEmpty) avgText = 'no_data'.tr;

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.15,
                children: [
                  StatsCard(
                    icon: Icons.local_gas_station_rounded,
                    value: volumeText,
                    label: 'stats_total_volume'.tr,
                  ),
                  StatsCard(
                    icon: Icons.payments_rounded,
                    value: stats['total_cost'] != null &&
                            stats['total_cost']! > 0
                        ? '${stats['total_cost']!.toStringAsFixed(0)} ${settingsCtrl.currencySymbol}'
                        : 'no_data'.tr,
                    label: 'total_spent'.tr,
                    valueColor: Colors.green,
                  ),
                  StatsCard(
                    icon: Icons.show_chart_rounded,
                    value: avgText,
                    label: 'avg_consumption'.tr,
                    valueColor: Colors.blue,
                  ),
                  StatsCard(
                    icon: Icons.format_list_numbered_rounded,
                    value: totalEntries.toString(),
                    label: 'stats_total_entries'.tr,
                  ),
                ],
              );
            }),

            // ── График расхода ──
            if (monthly.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                '${'stats_monthly_consumption'.tr} (${settingsCtrl.volumeUnit.value}/100)',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _MonthlyBarChart(
                monthly: monthly,
                valueKey: 'avg_consumption',
                color: AppTheme.chartPrimary,
                suffix: ' ${settingsCtrl.volumeUnit.value}',
              ),

              // ── График стоимости ──
              if (monthly
                  .any((m) => (m['total_cost'] as num?) != null && (m['total_cost'] as num) > 0)) ...[
                const SizedBox(height: 24),
                Text(
                  '${'stats_monthly_costs'.tr} (${settingsCtrl.currencySymbol})',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _MonthlyBarChart(
                  monthly: monthly,
                  valueKey: 'total_cost',
                  color: AppTheme.efficiencyMid,
                  suffix: ' ${settingsCtrl.currencySymbol}',
                ),
              ],

              // ── График объёма ──
              if (monthly.any((m) => (m['total_volume'] as num?) != null && (m['total_volume'] as num) > 0)) ...[
                const SizedBox(height: 24),
                Text(
                  'stats_total_volume'.tr,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _MonthlyBarChart(
                  monthly: monthly,
                  valueKey: 'total_volume',
                  color: Colors.indigo,
                  suffix: ' ${settingsCtrl.volumeUnit.value}',
                ),
              ],
            ],

            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}

// ─────────────────────────── Care Stats ──

class _CareStatsView extends StatelessWidget {
  final int vehicleId;
  final String vehicleName;

  const _CareStatsView({required this.vehicleId, required this.vehicleName});

  static const _categories = [
    'service', 'oil_change', 'wash', 'tires', 'tax', 'parts', 'other',
  ];

  @override
  Widget build(BuildContext context) {
    final expenseCtrl = Get.find<CarExpenseController>();
    final settingsCtrl = Get.find<SettingsController>();

    return Obx(() {
      final expenses = expenseCtrl.expenses;
      final stats = expenseCtrl.expenseStats;
      final total = expenseCtrl.totalExpenses;

      if (expenses.isEmpty) {
        return EmptyState(
          icon: Icons.build_outlined,
          title: 'stats_care_no_data'.tr,
          subtitle: 'stats_care_no_data_hint'.tr,
        );
      }

      return FutureBuilder<List<Map<String, dynamic>>>(
        future: expenseCtrl.getMonthlyExpenses(vehicleId),
        builder: (context, snap) {
          final monthly = snap.data ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Общая сумма ──
              Text(
                '${'stats_summary_prefix'.tr}$vehicleName',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              StatsCard(
                icon: Icons.account_balance_wallet_rounded,
                value: '${total.toStringAsFixed(0)} ${settingsCtrl.currencySymbol}',
                label: 'stats_care_total'.tr,
                valueColor: Colors.orange,
              ),
              const SizedBox(height: 16),

              // ── Расходы по категориям ──
              Text(
                'stats_care_by_category'.tr,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              // Доля каждой категории
              ..._categories
                  .where((c) => (stats[c] ?? 0) > 0)
                  .map((cat) {
                    final amount = stats[cat] ?? 0;
                    final pct = total > 0 ? amount / total : 0.0;
                    final (icon, color) = ExpenseCategoryIcon.dataFor(cat);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(icon, size: 16, color: color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'cat_${cat}_full'.tr,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              Text(
                                '${amount.toStringAsFixed(0)} ${settingsCtrl.currencySymbol}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                    ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${(pct * 100).toStringAsFixed(0)}%',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: pct.toDouble(),
                            backgroundColor: color.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation(color),
                            borderRadius: BorderRadius.circular(4),
                            minHeight: 6,
                          ),
                        ],
                      ),
                    );
                  }),

              // ── Pie Chart ──
              if (stats.isNotEmpty && total > 0) ...[
                const SizedBox(height: 24),
                Text(
                  'stats_care_by_category'.tr,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _CareExpensePieChart(stats: stats, total: total),
              ],

              // ── Monthly bar chart ──
              if (monthly.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'stats_care_monthly'.tr,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _MonthlyBarChart(
                  monthly: monthly,
                  valueKey: 'total_amount',
                  color: Colors.orange,
                  suffix: ' ${settingsCtrl.currencySymbol}',
                ),
              ],

              const SizedBox(height: 32),
            ],
          );
        },
      );
    });
  }
}

// ─────────────────────── Pie Chart for care ──

class _CareExpensePieChart extends StatelessWidget {
  final Map<String, double> stats;
  final double total;

  const _CareExpensePieChart({required this.stats, required this.total});

  static const _categories = [
    'service', 'oil_change', 'wash', 'tires', 'tax', 'parts', 'other',
  ];

  @override
  Widget build(BuildContext context) {
    final sections = _categories
        .where((c) => (stats[c] ?? 0) > 0)
        .map((cat) {
          final amount = stats[cat] ?? 0;
          final pct = total > 0 ? amount / total : 0.0;
          final (_, color) = ExpenseCategoryIcon.dataFor(cat);
          return PieChartSectionData(
            value: amount,
            color: color,
            title: '${(pct * 100).toStringAsFixed(0)}%',
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          );
        })
        .toList();

    return SizedBox(
      height: 180,
      child: PieChart(
        PieChartData(
          sections: sections,
          centerSpaceRadius: 36,
          sectionsSpace: 2,
        ),
      ),
    );
  }
}

// ─────────────────────────── Monthly Bar Chart ──

class _MonthlyBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> monthly;
  final String valueKey;
  final Color color;
  final String suffix;

  const _MonthlyBarChart({
    required this.monthly,
    required this.valueKey,
    required this.color,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final values = monthly
        .map((m) => (m[valueKey] as num?)?.toDouble() ?? 0.0)
        .toList();

    if (values.every((v) => v == 0)) return const SizedBox.shrink();

    final maxY = values.reduce((a, b) => a > b ? a : b) * 1.2;

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barGroups: values.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value,
                  color: color,
                  width: 18,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (val, _) {
                  final idx = val.toInt();
                  if (idx < 0 || idx >= monthly.length) {
                    return const SizedBox.shrink();
                  }
                  final month = monthly[idx]['month'] as String;
                  final parts = month.split('-');
                  if (parts.length < 2) return const SizedBox.shrink();
                  final label = '${parts[1]}.${parts[0].substring(2)}';
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 9, color: cs.onSurfaceVariant)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                getTitlesWidget: (val, _) => Text(
                  val.toStringAsFixed(0),
                  style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                ),
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: cs.outlineVariant.withValues(alpha: 0.24),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => cs.surfaceContainerHighest,
              getTooltipItem: (group, _, rod, __) {
                final m = monthly[group.x]['month'] as String;
                return BarTooltipItem(
                  '$m\n',
                  TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                  children: [
                    TextSpan(
                      text: '${rod.toY.toStringAsFixed(1)}$suffix',
                      style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

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
            _FuelStatsView(
                vehicleId: vehicle.id!, vehicleName: vehicle.name),
            _CareStatsView(
                vehicleId: vehicle.id!, vehicleName: vehicle.name),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────── Fuel Stats ──

class _FuelStatsView extends StatefulWidget {
  final int vehicleId;
  final String vehicleName;

  const _FuelStatsView(
      {required this.vehicleId, required this.vehicleName});

  @override
  State<_FuelStatsView> createState() => _FuelStatsViewState();
}

class _FuelStatsViewState extends State<_FuelStatsView> {
  _ChartType _chartType = _ChartType.bar;

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
      future: entryCtrl.getMonthlyStats(widget.vehicleId),
      builder: (context, snap) {
        final monthly = snap.data ?? [];

        return ListView(
          padding:
              const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // ── Сводные карточки ──
            Text(
              '${'stats_summary_prefix'.tr}${widget.vehicleName}',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),

            Builder(builder: (context) {
              String volumeText = '';
              if (stats['total_volume'] != null &&
                  stats['total_volume']! > 0) {
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
                childAspectRatio: 1.05,
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
              _ChartHeader(
                title:
                    '${'stats_monthly_consumption'.tr} (${settingsCtrl.volumeUnit.value}/100)',
                chartType: _chartType,
                onTypeChanged: (t) => setState(() => _chartType = t),
              ),
              const SizedBox(height: 12),
              _FlexibleMonthlyChart(
                monthly: monthly,
                valueKey: 'avg_consumption',
                color: AppTheme.chartPrimary,
                suffix: ' ${settingsCtrl.volumeUnit.value}',
                chartType: _chartType,
              ),

              // ── График стоимости ──
              if (monthly.any((m) =>
                  (m['total_cost'] as num?) != null &&
                  (m['total_cost'] as num) > 0)) ...[
                const SizedBox(height: 24),
                Text(
                  '${'stats_monthly_costs'.tr} (${settingsCtrl.currencySymbol})',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _FlexibleMonthlyChart(
                  monthly: monthly,
                  valueKey: 'total_cost',
                  color: AppTheme.efficiencyMid,
                  suffix: ' ${settingsCtrl.currencySymbol}',
                  chartType: _chartType,
                ),
              ],

              // ── График объёма ──
              if (monthly.any((m) =>
                  (m['total_volume'] as num?) != null &&
                  (m['total_volume'] as num) > 0)) ...[
                const SizedBox(height: 24),
                Text(
                  'stats_total_volume'.tr,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _FlexibleMonthlyChart(
                  monthly: monthly,
                  valueKey: 'total_volume',
                  color: Colors.indigo,
                  suffix: ' ${settingsCtrl.volumeUnit.value}',
                  chartType: _chartType,
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

class _CareStatsView extends StatefulWidget {
  final int vehicleId;
  final String vehicleName;

  const _CareStatsView(
      {required this.vehicleId, required this.vehicleName});

  @override
  State<_CareStatsView> createState() => _CareStatsViewState();
}

class _CareStatsViewState extends State<_CareStatsView> {
  _ChartType _chartType = _ChartType.bar;

  static const _categories = [
    'service',
    'oil_change',
    'wash',
    'tires',
    'tax',
    'parts',
    'other',
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
        future: expenseCtrl.getMonthlyExpenses(widget.vehicleId),
        builder: (context, snap) {
          final monthly = snap.data ?? [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // ── Общая сумма ──
              Text(
                '${'stats_summary_prefix'.tr}${widget.vehicleName}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              StatsCard(
                icon: Icons.account_balance_wallet_rounded,
                value:
                    '${total.toStringAsFixed(0)} ${settingsCtrl.currencySymbol}',
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
                    final (icon, color) =
                        ExpenseCategoryIcon.dataFor(cat);
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall,
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
                            backgroundColor: color.withAlpha(30),
                            valueColor: AlwaysStoppedAnimation(color),
                            borderRadius: BorderRadius.circular(4),
                            minHeight: 6,
                          ),
                        ],
                      ),
                    );
                  }),

              // ── Pie / Donut Chart ──
              if (stats.isNotEmpty && total > 0) ...[
                const SizedBox(height: 24),
                Text(
                  'stats_chart_distribution'.tr,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _CareExpensePieChart(stats: stats, total: total),
              ],

              // ── Monthly bar/line chart ──
              if (monthly.isNotEmpty) ...[
                const SizedBox(height: 24),
                _ChartHeader(
                  title: 'stats_care_monthly'.tr,
                  chartType: _chartType,
                  onTypeChanged: (t) => setState(() => _chartType = t),
                ),
                const SizedBox(height: 12),
                _FlexibleMonthlyChart(
                  monthly: monthly,
                  valueKey: 'total_amount',
                  color: Colors.orange,
                  suffix: ' ${settingsCtrl.currencySymbol}',
                  chartType: _chartType,
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

// ─────────────────────── Chart Type Enum ──

enum _ChartType { bar, line, pie }

// ─────────────────────── Chart Type Header with Switcher ──

class _ChartHeader extends StatelessWidget {
  final String title;
  final _ChartType chartType;
  final ValueChanged<_ChartType> onTypeChanged;

  const _ChartHeader({
    required this.title,
    required this.chartType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        // Переключатель типа графика
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ChartTypeButton(
                icon: Icons.bar_chart_rounded,
                selected: chartType == _ChartType.bar,
                onTap: () => onTypeChanged(_ChartType.bar),
                cs: cs,
                tooltip: 'chart_bar'.tr,
              ),
              _ChartTypeButton(
                icon: Icons.show_chart_rounded,
                selected: chartType == _ChartType.line,
                onTap: () => onTypeChanged(_ChartType.line),
                cs: cs,
                tooltip: 'chart_line'.tr,
              ),
              _ChartTypeButton(
                icon: Icons.donut_large_rounded,
                selected: chartType == _ChartType.pie,
                onTap: () => onTypeChanged(_ChartType.pie),
                cs: cs,
                tooltip: 'chart_pie'.tr,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChartTypeButton extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;
  final String tooltip;

  const _ChartTypeButton({
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.cs,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: selected ? cs.onPrimary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────── Flexible Monthly Chart ──

class _FlexibleMonthlyChart extends StatelessWidget {
  final List<Map<String, dynamic>> monthly;
  final String valueKey;
  final Color color;
  final String suffix;
  final _ChartType chartType;

  const _FlexibleMonthlyChart({
    required this.monthly,
    required this.valueKey,
    required this.color,
    required this.suffix,
    required this.chartType,
  });

  @override
  Widget build(BuildContext context) {
    if (chartType == _ChartType.pie) {
      return _MonthlyPieChart(
          monthly: monthly, valueKey: valueKey, color: color, suffix: suffix);
    }
    if (chartType == _ChartType.line) {
      return _MonthlyLineChart(
          monthly: monthly, valueKey: valueKey, color: color, suffix: suffix);
    }
    return _MonthlyBarChart(
        monthly: monthly, valueKey: valueKey, color: color, suffix: suffix);
  }
}

// ─────────────────────────── Pie Chart for care ──

class _CareExpensePieChart extends StatefulWidget {
  final Map<String, double> stats;
  final double total;

  const _CareExpensePieChart({required this.stats, required this.total});

  static const _categories = [
    'service', 'oil_change', 'wash', 'tires', 'tax', 'parts', 'other',
  ];

  @override
  State<_CareExpensePieChart> createState() => _CareExpensePieChartState();
}

class _CareExpensePieChartState extends State<_CareExpensePieChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final activeCats = _CareExpensePieChart._categories
        .where((c) => (widget.stats[c] ?? 0) > 0)
        .toList();

    final sections = activeCats.asMap().entries.map((entry) {
      final i = entry.key;
      final cat = entry.value;
      final amount = widget.stats[cat] ?? 0;
      final pct = widget.total > 0 ? amount / widget.total : 0.0;
      final (_, color) = ExpenseCategoryIcon.dataFor(cat);
      final isTouched = _touchedIndex == i;

      return PieChartSectionData(
        value: amount,
        color: color,
        title: isTouched ? '${(pct * 100).toStringAsFixed(0)}%' : '',
        radius: isTouched ? 70 : 60,
        titleStyle: TextStyle(
          fontSize: isTouched ? 14 : 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    }).toList();

    // Legend
    final legend = activeCats.map((cat) {
      final amount = widget.stats[cat] ?? 0;
      final pct =
          widget.total > 0 ? (amount / widget.total * 100) : 0.0;
      final (_, color) = ExpenseCategoryIcon.dataFor(cat);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(
            'cat_$cat'.tr,
            style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 2),
          Text(
            '${pct.toStringAsFixed(0)}%',
            style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 10),
        ],
      );
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response == null ||
                        response.touchedSection == null) {
                      _touchedIndex = null;
                      return;
                    }
                    _touchedIndex = response
                        .touchedSection!.touchedSectionIndex;
                  });
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: legend,
        ),
      ],
    );
  }
}

// ─────────────────────── Monthly Pie Chart ──

class _MonthlyPieChart extends StatefulWidget {
  final List<Map<String, dynamic>> monthly;
  final String valueKey;
  final Color color;
  final String suffix;

  const _MonthlyPieChart({
    required this.monthly,
    required this.valueKey,
    required this.color,
    required this.suffix,
  });

  @override
  State<_MonthlyPieChart> createState() => _MonthlyPieChartState();
}

class _MonthlyPieChartState extends State<_MonthlyPieChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final values = widget.monthly
        .map((m) => (m[widget.valueKey] as num?)?.toDouble() ?? 0.0)
        .toList();
    final total = values.fold<double>(0, (a, b) => a + b);

    if (total == 0) return const SizedBox.shrink();

    // Generate colors based on base color
    final colors = List.generate(
      widget.monthly.length,
      (i) => HSLColor.fromColor(widget.color)
          .withHue((HSLColor.fromColor(widget.color).hue +
                  i * 30) %
              360)
          .toColor(),
    );

    final sections = widget.monthly.asMap().entries.map((entry) {
      final i = entry.key;
      final m = entry.value;
      final val = (m[widget.valueKey] as num?)?.toDouble() ?? 0.0;
      if (val == 0) return null;
      final pct = total > 0 ? val / total : 0.0;
      final isTouched = _touchedIndex == i;

      return PieChartSectionData(
        value: val,
        color: colors[i % colors.length],
        title: isTouched
            ? '${(pct * 100).toStringAsFixed(0)}%'
            : '',
        radius: isTouched ? 70 : 58,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    }).whereType<PieChartSectionData>().toList();

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response == null ||
                        response.touchedSection == null) {
                      _touchedIndex = null;
                      return;
                    }
                    _touchedIndex = response
                        .touchedSection!.touchedSectionIndex;
                  });
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: widget.monthly.asMap().entries.map((entry) {
            final i = entry.key;
            final m = entry.value;
            final val =
                (m[widget.valueKey] as num?)?.toDouble() ?? 0.0;
            if (val == 0) return const SizedBox.shrink();
            final month = m['month'] as String;
            final parts = month.split('-');
            final label = parts.length >= 2
                ? '${parts[1]}.${parts[0].substring(2)}'
                : month;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors[i % colors.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: TextStyle(
                      fontSize: 10, color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: 8),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────── Monthly Line Chart ──

class _MonthlyLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> monthly;
  final String valueKey;
  final Color color;
  final String suffix;

  const _MonthlyLineChart({
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
    final spots = values.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value);
    }).toList();

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          maxY: maxY,
          minY: 0,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: color,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 4,
                  color: color,
                  strokeWidth: 2,
                  strokeColor: cs.surface,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    color.withAlpha(60),
                    color.withAlpha(0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
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
                  final label =
                      '${parts[1]}.${parts[0].substring(2)}';
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 9,
                            color: cs.onSurfaceVariant)),
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
                  style: TextStyle(
                      fontSize: 9, color: cs.onSurfaceVariant),
                ),
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: cs.outlineVariant.withAlpha(60),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => cs.surfaceContainerHighest,
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${s.y.toStringAsFixed(1)}$suffix',
                        TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w700),
                      ))
                  .toList(),
            ),
          ),
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
                  gradient: LinearGradient(
                    colors: [color.withAlpha(180), color],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 18,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(5),
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
                  final label =
                      '${parts[1]}.${parts[0].substring(2)}';
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 9,
                            color: cs.onSurfaceVariant)),
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
                  style: TextStyle(
                      fontSize: 9, color: cs.onSurfaceVariant),
                ),
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: cs.outlineVariant.withAlpha(60),
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
                  TextStyle(
                      fontSize: 10, color: cs.onSurfaceVariant),
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

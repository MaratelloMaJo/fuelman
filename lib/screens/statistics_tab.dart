import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/fuel_entry_controller.dart';
import '../controllers/vehicle_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/stats_card.dart';
import '../controllers/settings_controller.dart';

/// Вкладка детальной статистики.
///
/// Содержит:
///   — Карточки сводной статистики
///   — BarChart расхода по месяцам
///   — BarChart стоимости по месяцам
class StatisticsTab extends StatelessWidget {
  const StatisticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final vehicleCtrl = Get.find<VehicleController>();
    final entryCtrl = Get.find<FuelEntryController>();
    final settingsCtrl = Get.find<SettingsController>();

    return Scaffold(
      appBar: AppBar(
        title: Text('statistics_title'.tr),
        centerTitle: true,
      ),
      body: Obx(() {
        final vehicle = vehicleCtrl.selectedVehicle.value;
        final stats = entryCtrl.stats;
        final totalEntries = stats['total_entries']?.toInt() ?? 0;

        if (vehicle == null) {
          return EmptyState(
            icon: Icons.bar_chart_rounded,
            title: 'stats_no_data_title'.tr,
            subtitle: 'select_vehicle_hint'.tr,
          );
        }

        if (totalEntries == 0) {
          return EmptyState(
            icon: Icons.bar_chart_rounded,
            title: 'stats_no_entries_title'.tr,
            subtitle: 'stats_no_entries_subtitle'.tr,
          );
        }

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: entryCtrl.getMonthlyStats(vehicle.id!),
          builder: (context, snap) {
            final monthly = snap.data ?? [];

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Сводные карточки ──
                Text(
                  '${'stats_summary_prefix'.tr}${vehicle.name}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                  Builder(builder: (context) {
                    String volumeText = '';
                    if (stats['total_volume'] != null && stats['total_volume']! > 0) {
                      volumeText += '${stats['total_volume']!.toStringAsFixed(1)} ${settingsCtrl.volumeUnit.value}';
                    }
                    if (stats['total_ev_volume'] != null && stats['total_ev_volume']! > 0) {
                      if (volumeText.isNotEmpty) volumeText += '\n';
                      volumeText += '${stats['total_ev_volume']!.toStringAsFixed(1)} kWh';
                    }
                    if (volumeText.isEmpty) volumeText = 'no_data'.tr;

                    String avgText = '';
                    if (stats['avg_consumption'] != null && stats['avg_consumption']! > 0) {
                      avgText += '${stats['avg_consumption']!.toStringAsFixed(1)} ${settingsCtrl.volumeUnit.value}';
                    }
                    if (stats['avg_ev_consumption'] != null && stats['avg_ev_consumption']! > 0) {
                      if (avgText.isNotEmpty) avgText += '\n';
                      avgText += '${stats['avg_ev_consumption']!.toStringAsFixed(1)} kWh';
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
                        ),
                        StatsCard(
                          icon: Icons.show_chart_rounded,
                          value: avgText,
                          label: 'avg_consumption'.tr,
                        ),
                        StatsCard(
                          icon: Icons.format_list_numbered_rounded,
                          value: totalEntries.toString(),
                          label: 'stats_total_entries'.tr,
                        ),
                      ],
                    );
                  }),

                // ── Monthly charts ──
                if (monthly.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    '${'stats_monthly_consumption'.tr} (${settingsCtrl.volumeUnit.value}/100)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _MonthlyBarChart(
                    monthly: monthly,
                    valueKey: 'avg_consumption',
                    color: AppTheme.chartPrimary,
                    suffix: ' ${settingsCtrl.volumeUnit.value}',
                  ),

                  if (monthly.any((m) => (m['total_cost'] as num?) != null &&
                      (m['total_cost'] as num) > 0)) ...[
                    const SizedBox(height: 24),
                    Text(
                      '${'stats_monthly_costs'.tr} (${settingsCtrl.currencySymbol})',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _MonthlyBarChart(
                      monthly: monthly,
                      valueKey: 'total_cost',
                      color: AppTheme.efficiencyMid,
                      suffix: ' ${settingsCtrl.currencySymbol}',
                    ),
                  ],
                ],

                const SizedBox(height: 32),
              ],
            );
          },
        );
      }),
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

    if (values.every((v) => v == 0)) {
      return const SizedBox.shrink();
    }

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
                  final label =
                      '${parts[1]}.${parts[0].substring(2)}';
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
                  val.toStringAsFixed(1),
                  style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                ),
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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

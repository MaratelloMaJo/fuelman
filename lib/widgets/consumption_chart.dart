import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/fuel_entry.dart';
import '../theme/app_theme.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';

/// Переключаемый график расхода/стоимости.
///
/// [ChartMode.consumption] — LineChart расхода (л/100 км) по времени.
/// [ChartMode.cost]        — BarChart стоимости каждой заправки (₽).
class ConsumptionChart extends StatefulWidget {
  /// Записи с рассчитанным расходом (только isFullTank + не первая).
  final List<FuelEntry> entries;

  const ConsumptionChart({super.key, required this.entries});

  @override
  State<ConsumptionChart> createState() => _ConsumptionChartState();
}

enum _ChartMode { consumption, cost }

class _ConsumptionChartState extends State<ConsumptionChart>
    with SingleTickerProviderStateMixin {
  _ChartMode _mode = _ChartMode.consumption;
  late final AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _switchMode(_ChartMode mode) {
    if (_mode == mode) return;
    _animCtrl.reverse().then((_) {
      setState(() => _mode = mode);
      _animCtrl.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasCostData =
        widget.entries.any((e) => e.pricePerLiter != null);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Заголовок + переключатель ──
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _mode == _ChartMode.consumption
                          ? 'Расход топлива'
                          : 'Стоимость заправок',
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                  ),
                  if (hasCostData)
                    SegmentedButton<_ChartMode>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: const [
                        ButtonSegment(
                          value: _ChartMode.consumption,
                          icon: Icon(Icons.show_chart_rounded, size: 16),
                          tooltip: 'Расход',
                        ),
                        ButtonSegment(
                          value: _ChartMode.cost,
                          icon: Icon(Icons.bar_chart_rounded, size: 16),
                          tooltip: 'Стоимость',
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (s) => _switchMode(s.first),
                    ),
                ],
              ),
            ),
            // ── График ──
            SizedBox(
              height: 200,
              child: widget.entries.isEmpty
                  ? Center(
                      child: Text(
                        'Недостаточно данных\n(нужно ≥ 2 полных заправки)',
                        style: TextStyle(color: cs.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : FadeTransition(
                      opacity: _fadeAnim,
                      child: _mode == _ChartMode.consumption
                          ? _buildLineChart(context)
                          : _buildBarChart(context),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────── Line Chart ──

  Widget _buildLineChart(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('dd.MM');

    final spots = widget.entries.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.consumption!);
    }).toList();

    // Диапазон Y с небольшим отступом.
    final ys = spots.map((s) => s.y).toList();
    final minY = (ys.reduce((a, b) => a < b ? a : b) - 1).clamp(0.0, double.infinity);
    final maxY = ys.reduce((a, b) => a > b ? a : b) + 1;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: cs.primary,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, pct, bar, index) => FlDotCirclePainter(
                radius: 4,
                color: cs.primary,
                strokeWidth: 2,
                strokeColor: cs.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  cs.primary.withAlpha(60),
                  cs.primary.withAlpha(0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: (val, meta) => Text(
                val.toStringAsFixed(1),
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (spots.length / 4).ceilToDouble().clamp(1, double.infinity),
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= widget.entries.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    dateFmt.format(widget.entries[idx].date),
                    style:
                        TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                  ),
                );
              },
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
            color: cs.outlineVariant.withAlpha(60),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => cs.surfaceContainerHighest,
            getTooltipItems: (spots) => spots.map((s) {
              final entry = widget.entries[s.spotIndex];
              final dateFmtFull = DateFormat('dd.MM.yyyy');
              return LineTooltipItem(
                '${dateFmtFull.format(entry.date)}\n',
                TextStyle(
                    fontSize: 10,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.normal),
                children: [
                  TextSpan(
                    text: '${s.y.toStringAsFixed(1)} ${Get.find<SettingsController>().volumeUnit.value}/100',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.primary,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────── Bar Chart ──

  Widget _buildBarChart(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('dd.MM');

    // Берём все записи (не только с расходом) у которых есть стоимость.
    final costEntries =
        widget.entries.where((e) => e.totalCost != null).toList();

    if (costEntries.isEmpty) {
      return Center(
        child: Text(
          'Нет данных о стоимости.\nДобавьте цену за литр в записях.',
          style: TextStyle(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      );
    }

    return BarChart(
      BarChartData(
        barGroups: costEntries.asMap().entries.map((e) {
          final cost = e.value.totalCost!;
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: cost,
                gradient: LinearGradient(
                  colors: [AppTheme.chartSecondary, AppTheme.chartPrimary],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 16,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (val, meta) => Text(
                '${val.toStringAsFixed(0)} ${Get.find<SettingsController>().currencySymbol}',
                style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= costEntries.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    dateFmt.format(costEntries[idx].date),
                    style:
                        TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                  ),
                );
              },
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
            color: cs.outlineVariant.withAlpha(60),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => cs.surfaceContainerHighest,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final entry = costEntries[group.x];
              return BarTooltipItem(
                '${DateFormat('dd.MM.yyyy').format(entry.date)}\n',
                TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
                children: [
                  TextSpan(
                    text: '${rod.toY.toStringAsFixed(0)} ${Get.find<SettingsController>().currencySymbol}',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.chartPrimary,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

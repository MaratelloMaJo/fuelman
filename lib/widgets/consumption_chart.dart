import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/fuel_entry.dart';
import '../theme/app_theme.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../controllers/fuel_entry_controller.dart';

/// Переключаемый график расхода/стоимости.
///
/// [ChartMode.consumption] — LineChart расхода (л/100 км) по времени
///   с горизонтальной линией среднего и подсветкой аномальных точек.
/// [ChartMode.cost] — BarChart стоимости каждой заправки.
class ConsumptionChart extends StatefulWidget {
  /// Записи с рассчитанным расходом.
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
    final hasCostData = widget.entries.any((e) => e.pricePerLiter != null);

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
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (hasCostData)
                    SegmentedButton<_ChartMode>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
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

            // ── Легенда (только для графика расхода) ──
            if (_mode == _ChartMode.consumption && widget.entries.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Row(
                  children: [
                    _LegendDot(color: cs.primary, label: 'Расход'),
                    const SizedBox(width: 12),
                    _LegendDot(
                        color: cs.primary.withAlpha(120),
                        label: 'Среднее',
                        dashed: true),
                    const SizedBox(width: 12),
                    _LegendDot(
                        color: Colors.orange, label: 'Аномалия'),
                  ],
                ),
              ),

            // ── График ──
            SizedBox(
              height: 200,
              child: widget.entries.isEmpty
                  ? Center(
                      child: Text(
                        'Недостаточно данных\n(нужно ≥ 2 заправок)',
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
    final entryCtrl = Get.find<FuelEntryController>();

    // Строим spots — аномальные и обычные раздельно
    final List<FlSpot> normalSpots = [];
    final List<FlSpot> anomalySpots = [];

    for (int i = 0; i < widget.entries.length; i++) {
      final e = widget.entries[i];
      final spot = FlSpot(i.toDouble(), e.consumption!);
      if (entryCtrl.isEntryAnomalous(e.id)) {
        anomalySpots.add(spot);
      } else {
        normalSpots.add(spot);
      }
    }

    // Средний расход (без аномалий)
    final normalValues = normalSpots.map((s) => s.y).toList();
    final double? avgY = normalValues.isNotEmpty
        ? normalValues.reduce((a, b) => a + b) / normalValues.length
        : null;

    // Диапазон Y
    final allY = widget.entries.map((e) => e.consumption!).toList();
    final minY =
        (allY.reduce((a, b) => a < b ? a : b) - 1).clamp(0.0, double.infinity);
    final maxY = allY.reduce((a, b) => a > b ? a : b) + 2;

    // Все записи как один LineChartBarData (для рисования линии между всеми точками)
    final allSpots = widget.entries.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.consumption!);
    }).toList();

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          // Основная линия
          LineChartBarData(
            spots: allSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: cs.primary,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, pct, bar, index) {
                final e = widget.entries[index];
                final isAnomaly = entryCtrl.isEntryAnomalous(e.id);
                return FlDotCirclePainter(
                  radius: isAnomaly ? 5 : 4,
                  color: isAnomaly ? Colors.orange : cs.primary,
                  strokeWidth: isAnomaly ? 2.5 : 2,
                  strokeColor: isAnomaly ? Colors.orange.withAlpha(80) : cs.surface,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  cs.primary.withAlpha(50),
                  cs.primary.withAlpha(0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Линия среднего
          if (avgY != null)
            LineChartBarData(
              spots: [
                FlSpot(0, avgY),
                FlSpot((widget.entries.length - 1).toDouble(), avgY),
              ],
              isCurved: false,
              color: cs.primary.withAlpha(130),
              barWidth: 1.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              dashArray: [6, 4],
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
              interval: (widget.entries.length / 4)
                  .ceilToDouble()
                  .clamp(1, double.infinity),
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx < 0 || idx >= widget.entries.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    dateFmt.format(widget.entries[idx].date),
                    style: TextStyle(
                        fontSize: 9, color: cs.onSurfaceVariant),
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
              // Игнорируем тулип от линии среднего (второй LineBar)
              if (s.barIndex == 1) {
                return LineTooltipItem(
                  'Среднее: ${s.y.toStringAsFixed(1)}',
                  TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                      fontStyle: FontStyle.italic),
                );
              }
              final entry = widget.entries[s.spotIndex];
              final dateFmtFull = DateFormat('dd.MM.yyyy');
              final isAnomaly = Get.find<FuelEntryController>()
                  .isEntryAnomalous(entry.id);
              return LineTooltipItem(
                '${dateFmtFull.format(entry.date)}\n',
                TextStyle(
                    fontSize: 10,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.normal),
                children: [
                  TextSpan(
                    text:
                        '${s.y.toStringAsFixed(1)} ${Get.find<SettingsController>().volumeUnit.value}/100',
                    style: TextStyle(
                        fontSize: 12,
                        color: isAnomaly ? Colors.orange : cs.primary,
                        fontWeight: FontWeight.w700),
                  ),
                  if (isAnomaly)
                    TextSpan(
                      text: '\n⚠ Аномалия',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange,
                          fontWeight: FontWeight.normal),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
        // Горизонтальная линия avg (дополнительная разметка)
        extraLinesData: avgY != null
            ? ExtraLinesData(horizontalLines: [
                HorizontalLine(
                  y: avgY,
                  color: cs.primary.withAlpha(0), // невидимая — нарисована через LineBarsData
                  strokeWidth: 0,
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    padding: const EdgeInsets.only(right: 4, bottom: 2),
                    style: TextStyle(
                      fontSize: 9,
                      color: cs.primary.withAlpha(180),
                      fontStyle: FontStyle.italic,
                    ),
                    labelResolver: (_) =>
                        'avg ${avgY.toStringAsFixed(1)}',
                  ),
                ),
              ])
            : null,
      ),
    );
  }

  // ─────────────────────────────────── Bar Chart ──

  Widget _buildBarChart(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('dd.MM');

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
                    style: TextStyle(
                        fontSize: 9, color: cs.onSurfaceVariant),
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
                    text:
                        '${rod.toY.toStringAsFixed(0)} ${Get.find<SettingsController>().currencySymbol}',
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

// ─────────────────────────── Legend Dot ──

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;

  const _LegendDot({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 2,
          decoration: BoxDecoration(
            color: dashed ? Colors.transparent : color,
            border: dashed ? Border(bottom: BorderSide(color: color, width: 2)) : null,
          ),
          child: dashed
              ? null
              : null,
        ),
        if (!dashed) ...[
          const SizedBox(width: 2),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ],
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

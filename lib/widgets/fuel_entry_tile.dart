import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/fuel_entry.dart';
import '../controllers/settings_controller.dart';
import '../controllers/fuel_entry_controller.dart';
import 'efficiency_badge.dart';
import 'package:get/get.dart';

/// Элемент списка записей о заправке.
///
/// Улучшения:
///   — Показывает пройденное расстояние (∆ km)
///   — Маркирует аномальный расход
///   — Swipe-to-delete через [Dismissible]
class FuelEntryTile extends StatelessWidget {
  final FuelEntry entry;
  final double? avgConsumption;
  final double? prevOdometer; // одометр предыдущей записи (для ∆ км)
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const FuelEntryTile({
    super.key,
    required this.entry,
    this.avgConsumption,
    this.prevOdometer,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('dd MMM yyyy', 'ru');
    final entryCtrl = Get.find<FuelEntryController>();
    final isAnomalous = entryCtrl.isEntryAnomalous(entry.id);

    // Рассчитываем ∆ пробег
    final distanceKm = (prevOdometer != null && prevOdometer! > 0)
        ? (entry.odometer - prevOdometer!)
        : null;

    final Widget tile = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      clipBehavior: Clip.antiAlias,
      // Лёгкая подсветка аномальной записи
      color: isAnomalous
          ? Colors.orange.withAlpha(12)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isAnomalous
            ? BorderSide(color: Colors.orange.withAlpha(100), width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Строка 1: дата + тип + бейдж ──
              Row(
                children: [
                  Icon(
                    entry.entryType == 'charge'
                        ? Icons.electrical_services_rounded
                        : (entry.isFullTank
                            ? Icons.local_gas_station_rounded
                            : Icons.ev_station_rounded),
                    size: 16,
                    color: entry.isFullTank ? cs.primary : cs.secondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateFmt.format(entry.date),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: entry.isFullTank
                          ? cs.primaryContainer
                          : cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      entry.isFullTank ? 'Полный' : 'Частичный',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: entry.isFullTank
                            ? cs.onPrimaryContainer
                            : cs.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (entry.consumption != null)
                    EfficiencyBadge(
                      consumption: entry.consumption!,
                      avgConsumption: avgConsumption,
                      isAnomalous: isAnomalous,
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Строка 2: метрики ──
              IntrinsicHeight(
                child: Row(
                  children: [
                    _Metric(
                      label: 'Одометр',
                      value: '${entry.odometer.toStringAsFixed(0)} км',
                      icon: Icons.speed_rounded,
                    ),
                    _Divider(),
                    _Metric(
                      label: 'Объём',
                      value:
                          '${entry.volume.toStringAsFixed(2)} ${entry.volumeUnit}',
                      icon: entry.entryType == 'charge'
                          ? Icons.electrical_services_rounded
                          : Icons.water_drop_rounded,
                    ),
                    if (entry.pricePerLiter != null) ...[
                      _Divider(),
                      _Metric(
                        label: 'Цена/ед',
                        value:
                            '${entry.pricePerLiter!.toStringAsFixed(1)} ${Get.find<SettingsController>().getSymbolForCurrency(entry.currency)}',
                        icon: Icons.sell_rounded,
                      ),
                    ],
                    if (entry.consumption != null) ...[
                      _Divider(),
                      _Metric(
                        label: 'Расход',
                        value:
                            '${entry.consumption!.toStringAsFixed(1)} ${entry.volumeUnit}/100',
                        icon: isAnomalous
                            ? Icons.warning_amber_rounded
                            : Icons.show_chart_rounded,
                        highlight: true,
                        anomaly: isAnomalous,
                      ),
                    ],
                  ],
                ),
              ),

              // ── Строка 3: стоимость + ∆ пробег ──
              if (entry.totalCost != null || distanceKm != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (entry.totalCost != null)
                      Text(
                        'Стоимость: ${entry.totalCost!.toStringAsFixed(0)} ${Get.find<SettingsController>().getSymbolForCurrency(entry.currency)}',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                      ),
                    const Spacer(),
                    if (distanceKm != null && distanceKm > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.route_rounded,
                              size: 12, color: cs.onSurfaceVariant),
                          const SizedBox(width: 3),
                          Text(
                            '∆ ${distanceKm.toStringAsFixed(0)} км',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],

              // ── Баннер аномалии ──
              if (isAnomalous) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 12, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      'anomaly_note'.tr,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.orange),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (onDelete == null) return tile;

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_rounded, color: cs.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Удалить запись?'),
            content: const Text(
              'После удаления расход будет пересчитан. Это действие нельзя отменить.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete?.call(),
      child: tile,
    );
  }
}

// ─────────────────────────── Metric Widget ──

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool highlight;
  final bool anomaly;

  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
    this.anomaly = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = anomaly
        ? Colors.orange
        : (highlight ? cs.primary : cs.onSurface);

    return Expanded(
      child: Column(
        children: [
          Icon(icon,
              size: 14,
              color: anomaly ? Colors.orange : cs.onSurfaceVariant),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: VerticalDivider(
        color: Theme.of(context).colorScheme.outlineVariant,
        width: 16,
      ),
    );
  }
}

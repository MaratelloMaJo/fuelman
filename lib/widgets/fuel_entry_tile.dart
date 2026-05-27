import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/fuel_entry.dart';
import 'efficiency_badge.dart';

/// Элемент списка записей о заправке.
///
/// Показывает дату, одометр, объём, цену, расход и бейдж эффективности.
/// Поддерживает swipe-to-delete через [Dismissible].
class FuelEntryTile extends StatelessWidget {
  final FuelEntry entry;
  final double? avgConsumption;
  final VoidCallback? onDelete;

  const FuelEntryTile({
    super.key,
    required this.entry,
    this.avgConsumption,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('dd MMM yyyy', 'ru');

    final Widget tile = Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Строка 1: дата + тип + бейдж ──
            Row(
              children: [
                Icon(
                  entry.isFullTank
                      ? Icons.local_gas_station_rounded
                      : Icons.ev_station_rounded,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: entry.isFullTank
                        ? cs.primaryContainer
                        : cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    entry.isFullTank ? 'Полный' : 'Дозаправка',
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
                    value: '${entry.volume.toStringAsFixed(2)} л',
                    icon: Icons.water_drop_rounded,
                  ),
                  if (entry.pricePerLiter != null) ...[
                    _Divider(),
                    _Metric(
                      label: 'Цена/л',
                      value: '${entry.pricePerLiter!.toStringAsFixed(1)} ₽',
                      icon: Icons.sell_rounded,
                    ),
                  ],
                  if (entry.consumption != null) ...[
                    _Divider(),
                    _Metric(
                      label: 'Расход',
                      value:
                          '${entry.consumption!.toStringAsFixed(1)} л/100',
                      icon: Icons.show_chart_rounded,
                      highlight: true,
                    ),
                  ],
                ],
              ),
            ),
            if (entry.totalCost != null) ...[
              const SizedBox(height: 6),
              Text(
                'Стоимость заправки: ${entry.totalCost!.toStringAsFixed(0)} ₽',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
          ],
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

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: highlight ? cs.primary : cs.onSurface,
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

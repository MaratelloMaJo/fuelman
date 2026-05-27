import 'package:flutter/material.dart';

import '../models/vehicle.dart';

/// Карточка автомобиля для экрана выбора и управления.
class VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const VehicleCard({
    super.key,
    required this.vehicle,
    required this.isSelected,
    required this.onTap,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: isSelected ? cs.primaryContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? BorderSide(color: cs.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Иконка автомобиля
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isSelected ? cs.primary : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _iconForType(vehicle.iconType),
                  color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.name,
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? cs.onPrimaryContainer
                                    : cs.onSurface,
                              ),
                    ),
                    Text(
                      vehicle.model,
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isSelected
                                    ? cs.onPrimaryContainer.withAlpha(180)
                                    : cs.onSurfaceVariant,
                              ),
                    ),
                    if (vehicle.fuelGoal != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Цель: ${vehicle.fuelGoal!.toStringAsFixed(1)} л/100 км',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: cs.primary,
                                ),
                      ),
                    ],
                    if (vehicle.reminderDays != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.notifications_outlined,
                              size: 12, color: cs.secondary),
                          const SizedBox(width: 4),
                          Text(
                            'Напоминание: ${vehicle.reminderDays} дн.',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: cs.secondary),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (onEdit != null || onDelete != null)
                PopupMenuButton<String>(
                  itemBuilder: (_) => [
                    if (onEdit != null)
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Изменить'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Удалить'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                  ],
                  onSelected: (val) {
                    if (val == 'edit') onEdit?.call();
                    if (val == 'delete') onDelete?.call();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  static IconData _iconForType(String type) {
    switch (type) {
      case 'suv':
        return Icons.directions_car_filled_rounded;
      case 'truck':
        return Icons.local_shipping_rounded;
      case 'moto':
        return Icons.two_wheeler_rounded;
      case 'electric':
        return Icons.electric_car_rounded;
      default:
        return Icons.directions_car_rounded; // sedan
    }
  }
}

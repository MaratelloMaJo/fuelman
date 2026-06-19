import 'package:flutter/material.dart';

import 'package:get/get.dart';

/// Прогресс-бар для отображения достижения цели по расходу топлива.
///
/// Показывает текущий средний расход относительно установленной цели.
/// Если среднее превышает цель — прогресс заполнен на 100% и становится красным.
class GoalProgressBar extends StatelessWidget {
  final double current;  // Текущий средний расход (л/100 км)
  final double goal;     // Целевой расход (л/100 км)

  const GoalProgressBar({
    super.key,
    required this.current,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Прогресс: насколько мы НИЖЕ цели (1.0 = равно цели, 0.0 = нет расхода).
    // Меньше расход — лучше, поэтому прогресс = goal/current (инвертируем).
    final ratio = (goal / current).clamp(0.0, 1.0);
    final isOverGoal = current > goal;

    final barColor = isOverGoal
        ? Theme.of(context).colorScheme.error
        : Color.lerp(Colors.green, cs.primary, 1 - ratio)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'goal_consumption_title'.tr,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
                Text(
                  '${current.toStringAsFixed(1)} / ${goal.toStringAsFixed(1)} л/100 км',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isOverGoal ? cs.error : cs.onSurface,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            if (isOverGoal) ...[
              const SizedBox(height: 6),
              Text(
                '${'goal_exceeded'.tr} ${(current - goal).toStringAsFixed(1)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.error,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

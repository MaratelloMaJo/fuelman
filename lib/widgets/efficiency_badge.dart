import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Бейдж эффективности расхода топлива.
///
/// Уровни:
///   • зелёный  — расход ниже avg на 10% и более → «Отлично»
///   • серый    — в пределах ±10% от avg → «Норма»
///   • красный  — расход выше avg на 10% → «Высокий»
///   • оранжевый ⚠ — расход аномальный (вне физических пределов) → «Аномалия»
class EfficiencyBadge extends StatelessWidget {
  final double consumption;
  final double? avgConsumption;
  final bool isAnomalous;

  const EfficiencyBadge({
    super.key,
    required this.consumption,
    this.avgConsumption,
    this.isAnomalous = false,
  });

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _resolve();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData, String) _resolve() {
    // Аномальный расход — приоритет
    if (isAnomalous) {
      return (
        Colors.orange,
        Icons.warning_amber_rounded,
        'Аномалия',
      );
    }

    if (avgConsumption == null) {
      return (Colors.grey, Icons.remove, 'N/A');
    }
    final diff = (consumption - avgConsumption!) / avgConsumption!;
    if (diff <= -0.10) {
      return (AppTheme.efficiencyGood, Icons.arrow_downward_rounded, 'Отлично');
    } else if (diff >= 0.10) {
      return (AppTheme.efficiencyBad, Icons.arrow_upward_rounded, 'Высокий');
    } else {
      return (AppTheme.efficiencyMid, Icons.remove_rounded, 'Норма');
    }
  }
}

import 'package:flutter/material.dart';

/// Иконка и цвет для категории расхода.
class ExpenseCategoryIcon extends StatelessWidget {
  final String category;
  final double size;
  final bool showBackground;

  const ExpenseCategoryIcon({
    super.key,
    required this.category,
    this.size = 24,
    this.showBackground = false,
  });

  static const _data = <String, (IconData, Color)>{
    'service':    (Icons.build_rounded,           Color(0xFF1E88E5)),
    'oil_change': (Icons.opacity_rounded,          Color(0xFF00897B)),
    'wash':       (Icons.local_car_wash_rounded,   Color(0xFF00ACC1)),
    'tires':      (Icons.tire_repair_rounded,      Color(0xFF7B1FA2)),
    'tax':        (Icons.account_balance_rounded,  Color(0xFFF4511E)),
    'parts':      (Icons.settings_rounded,         Color(0xFF6D4C41)),
    'other':      (Icons.more_horiz_rounded,       Color(0xFF757575)),
  };

  static (IconData, Color) dataFor(String category) {
    return _data[category] ?? (Icons.more_horiz_rounded, const Color(0xFF757575));
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = dataFor(category);

    if (showBackground) {
      return Container(
        width: size + 16,
        height: size + 16,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: size),
      );
    }

    return Icon(icon, color: color, size: size);
  }
}

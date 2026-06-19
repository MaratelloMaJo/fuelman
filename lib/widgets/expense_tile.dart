import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/car_expense.dart';
import '../controllers/settings_controller.dart';
import 'expense_category_icon.dart';

/// Плитка записи расхода на уход за автомобилем.
class ExpenseTile extends StatelessWidget {
  final CarExpense expense;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ExpenseTile({
    super.key,
    required this.expense,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settings = Get.find<SettingsController>();
    final locale = settings.language.value == 'kk' ? 'ru' : settings.language.value;
    final dateFmt = DateFormat('dd MMM yyyy', locale);
    final (_, categoryColor) = ExpenseCategoryIcon.dataFor(expense.category);

    return Dismissible(
      key: Key('expense_${expense.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_rounded, color: cs.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('delete'.tr),
            content: Text(expense.title),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('cancel'.tr),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: cs.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('delete'.tr),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => onDelete?.call(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Иконка категории
                ExpenseCategoryIcon(
                  category: expense.category,
                  size: 22,
                  showBackground: true,
                ),
                const SizedBox(width: 12),

                // Информация
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            dateFmt.format(expense.date),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                          ),
                          if (expense.placeName != null) ...[
                            Text(
                              ' · ${expense.placeName}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (expense.odometer != null) ...[
                            Text(
                              ' · ${expense.odometer!.toStringAsFixed(0)} км',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ],
                      ),
                      // GPS чип
                      if (expense.hasLocation)
                        GestureDetector(
                          onTap: () => _openMap(expense.latitude!, expense.longitude!),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 12,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'gps_open_map'.tr,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Сумма
                Text(
                  '${expense.amount.toStringAsFixed(0)} ${expense.currency}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: categoryColor,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openMap(double lat, double lon) async {
    final uri = Uri.parse('geo:$lat,$lon?q=$lat,$lon');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      final webUri = Uri.parse('https://maps.google.com/?q=$lat,$lon');
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }
}

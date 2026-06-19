import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/car_expense_controller.dart';
import '../controllers/vehicle_controller.dart';
import '../controllers/settings_controller.dart';
import '../models/car_expense.dart';
import '../services/location_service.dart';
import '../widgets/expense_category_icon.dart';

/// Экран добавления/редактирования записи об уходе за автомобилем.
class AddExpenseScreen extends StatefulWidget {
  final CarExpense? editExpense;
  final String? initialCategory;

  const AddExpenseScreen({super.key, this.editExpense, this.initialCategory});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _placeCtrl = TextEditingController();
  final _odometerCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  String _category = 'service';
  String _currency = 'RUB';
  bool _isSaving = false;
  bool _isGettingLocation = false;

  double? _latitude;
  double? _longitude;

  final _expenseCtrl = Get.find<CarExpenseController>();
  final _vehicleCtrl = Get.find<VehicleController>();
  final _settingsCtrl = Get.find<SettingsController>();

  bool get _isEditing => widget.editExpense != null;

  @override
  void initState() {
    super.initState();
    _currency = _settingsCtrl.currency.value;

    if (_isEditing) {
      final e = widget.editExpense!;
      _category = e.category;
      _titleCtrl.text = e.title;
      _amountCtrl.text = e.amount.toStringAsFixed(2);
      _currency = e.currency;
      _date = e.date;
      if (e.placeName != null) _placeCtrl.text = e.placeName!;
      if (e.odometer != null) _odometerCtrl.text = e.odometer!.toStringAsFixed(0);
      if (e.notes != null) _notesCtrl.text = e.notes!;
      _latitude = e.latitude;
      _longitude = e.longitude;
    } else if (widget.initialCategory != null) {
      _category = widget.initialCategory!;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _placeCtrl.dispose();
    _odometerCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _getLocation() async {
    setState(() => _isGettingLocation = true);
    final loc = await LocationService.instance.getCurrentLocation();
    setState(() {
      _isGettingLocation = false;
      if (loc != null) {
        _latitude = loc.latitude;
        _longitude = loc.longitude;
        Get.snackbar('gps_saved'.tr, '${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}',
            snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2));
      } else {
        Get.snackbar('gps_error'.tr, 'GPS недоступен или запрещён',
            snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2));
      }
    });
  }

  void _clearLocation() {
    setState(() {
      _latitude = null;
      _longitude = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final vehicle = _vehicleCtrl.selectedVehicle.value;
    if (vehicle == null) return;

    setState(() => _isSaving = true);

    final expense = CarExpense(
      id: widget.editExpense?.id,
      vehicleId: vehicle.id!,
      date: _date,
      category: _category,
      title: _titleCtrl.text.trim(),
      amount: double.parse(_amountCtrl.text.replaceAll(',', '.')),
      currency: _currency,
      odometer: _odometerCtrl.text.isEmpty
          ? null
          : double.tryParse(_odometerCtrl.text.replaceAll(',', '.')),
      latitude: _latitude,
      longitude: _longitude,
      placeName: _placeCtrl.text.trim().isEmpty ? null : _placeCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    if (_isEditing) {
      await _expenseCtrl.updateExpense(expense);
    } else {
      await _expenseCtrl.addExpense(expense);
    }

    setState(() => _isSaving = false);

    if (mounted) {
      Get.back();
      Get.snackbar(
        _isEditing ? 'expense_updated'.tr : 'expense_added'.tr,
        expense.title,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final locale = _settingsCtrl.language.value == 'kk' ? 'ru' : _settingsCtrl.language.value;
    final dateFmt = DateFormat('dd MMMM yyyy', locale);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'edit_expense_title'.tr : 'new_expense_title'.tr),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Выбор категории ──
              Text(
                'cat_service'.tr,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 10),
              _CategoryPicker(
                selected: _category,
                onChanged: (c) => setState(() => _category = c),
              ),
              const SizedBox(height: 24),

              // ── Название ──
              Text('expense_title_label'.tr,
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  prefixIcon: ExpenseCategoryIcon(category: _category, size: 20),
                  hintText: 'expense_title_hint'.tr,
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'expense_title_required'.tr : null,
              ),
              const SizedBox(height: 20),

              // ── Дата ──
              Text('date_label'.tr,
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                    suffixIcon: Icon(Icons.arrow_drop_down_rounded),
                  ),
                  child: Text(dateFmt.format(_date)),
                ),
              ),
              const SizedBox(height: 20),

              // ── Сумма ──
              Text('expense_amount_label'.tr,
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))
                ],
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.payments_rounded),
                  hintText: '500.0',
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _currency,
                        isDense: true,
                        items: ['RUB', 'KZT', 'USD', 'EUR']
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _currency = v);
                        },
                      ),
                    ),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'expense_amount_required'.tr;
                  final val = double.tryParse(v.replaceAll(',', '.'));
                  if (val == null || val <= 0) return 'expense_amount_invalid'.tr;
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── Место ──
              Text('expense_place_label'.tr,
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _placeCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.store_rounded),
                  hintText: 'expense_place_hint'.tr,
                ),
              ),
              const SizedBox(height: 20),

              // ── Одометр (необязательно) ──
              Text('odometer_label'.tr,
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _odometerCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d]'))],
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.speed_rounded),
                  hintText: '50000',
                  suffixText: 'odometer_suffix'.tr,
                  helperText: 'Необязательно',
                  helperStyle: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 20),

              // ── GPS ──
              _GpsSection(
                latitude: _latitude,
                longitude: _longitude,
                isGetting: _isGettingLocation,
                onGetLocation: _getLocation,
                onClearLocation: _clearLocation,
              ),
              const SizedBox(height: 20),

              // ── Заметки ──
              Text('expense_notes_label'.tr,
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.notes_rounded),
                  hintText: 'expense_notes_hint'.tr,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 32),

              // ── Кнопка ──
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_isSaving ? 'saving'.tr : 'save_expense'.tr),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  );
}
}

// ─────────────────────────── Category Picker ──

class _CategoryPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _CategoryPicker({required this.selected, required this.onChanged});

  static const _categories = [
    'service', 'oil_change', 'wash', 'tires', 'tax', 'parts', 'other',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 0.9,
      children: _categories.map((cat) {
        final isActive = cat == selected;
        final (icon, color) = ExpenseCategoryIcon.dataFor(cat);
        return GestureDetector(
          onTap: () => onChanged(cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: isActive
                  ? color.withValues(alpha: 0.15)
                  : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: isActive
                  ? Border.all(color: color, width: 2)
                  : Border.all(color: Colors.transparent, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    color: isActive ? color : cs.onSurfaceVariant, size: 24),
                const SizedBox(height: 4),
                Text(
                  'cat_$cat'.tr,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: isActive ? color : cs.onSurfaceVariant,
                    fontWeight:
                        isActive ? FontWeight.w700 : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────── GPS Section ──

class _GpsSection extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final bool isGetting;
  final VoidCallback onGetLocation;
  final VoidCallback onClearLocation;

  const _GpsSection({
    required this.latitude,
    required this.longitude,
    required this.isGetting,
    required this.onGetLocation,
    required this.onClearLocation,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasLocation = latitude != null && longitude != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('gps_location_label'.tr,
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        if (hasLocation)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on_rounded, color: cs.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClearLocation,
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: cs.onSurfaceVariant),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: isGetting ? null : onGetLocation,
            icon: isGetting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location_rounded, size: 18),
            label: Text(isGetting ? 'gps_getting'.tr : 'gps_button'.tr),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/vehicle_controller.dart';
import '../models/vehicle.dart';
import '../services/notification_service.dart';

/// Экран добавления или редактирования автомобиля.
///
/// [editVehicle] — передаётся при редактировании (null при добавлении).
class AddVehicleScreen extends StatefulWidget {
  final Vehicle? editVehicle;
  const AddVehicleScreen({super.key, this.editVehicle});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _goalCtrl = TextEditingController();
  final _evGoalCtrl = TextEditingController();
  final _reminderCtrl = TextEditingController();

  String _bodyType = 'sedan';
  String _engineType = 'gas';
  String? _hybridType;
  String? _fuelSubtype;
  bool _isSaving = false;
  bool _reminderEnabled = false;

  // Дополнительные поля (необязательные)
  final _licensePlateCtrl = TextEditingController();
  final _engineVolumeCtrl = TextEditingController();
  final _horsePowerCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();

  final _vehicleCtrl = Get.find<VehicleController>();

  bool get _isEditing => widget.editVehicle != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final v = widget.editVehicle!;
      _nameCtrl.text = v.name;
      _modelCtrl.text = v.model;
      _bodyType = v.bodyType;
      _engineType = v.engineType;
      _hybridType = v.hybridType;
      _fuelSubtype = v.fuelSubtype;
      if (v.fuelGoal != null) _goalCtrl.text = v.fuelGoal!.toStringAsFixed(1);
      if (v.evGoal != null) _evGoalCtrl.text = v.evGoal!.toStringAsFixed(1);
      if (v.reminderDays != null) {
        _reminderEnabled = true;
        _reminderCtrl.text = v.reminderDays!.toString();
      }
      if (v.licensePlate != null) _licensePlateCtrl.text = v.licensePlate!;
      if (v.engineVolume != null) {
        _engineVolumeCtrl.text = v.engineVolume!.toStringAsFixed(1);
      }
      if (v.horsePower != null) _horsePowerCtrl.text = v.horsePower!.toString();
      if (v.year != null) _yearCtrl.text = v.year!.toString();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _modelCtrl.dispose();
    _goalCtrl.dispose();
    _evGoalCtrl.dispose();
    _reminderCtrl.dispose();
    _licensePlateCtrl.dispose();
    _engineVolumeCtrl.dispose();
    _horsePowerCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    if (_reminderEnabled) {
      await NotificationService.instance.requestPermission();
    }

    final vehicle = Vehicle(
      id: widget.editVehicle?.id,
      name: _nameCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      bodyType: _bodyType,
      engineType: _engineType,
      hybridType: _engineType == 'hybrid' ? _hybridType : null,
      fuelSubtype: _fuelSubtype,
      fuelGoal: _goalCtrl.text.isEmpty
          ? null
          : double.tryParse(_goalCtrl.text.replaceAll(',', '.')),
      evGoal: _evGoalCtrl.text.isEmpty
          ? null
          : double.tryParse(_evGoalCtrl.text.replaceAll(',', '.')),
      reminderDays: _reminderEnabled && _reminderCtrl.text.isNotEmpty
          ? int.tryParse(_reminderCtrl.text)
          : null,
      licensePlate: _licensePlateCtrl.text.trim().isEmpty
          ? null
          : _licensePlateCtrl.text.trim().toUpperCase(),
      engineVolume: _engineVolumeCtrl.text.isEmpty
          ? null
          : double.tryParse(_engineVolumeCtrl.text.replaceAll(',', '.')),
      horsePower: _horsePowerCtrl.text.isEmpty
          ? null
          : int.tryParse(_horsePowerCtrl.text),
      year: _yearCtrl.text.isEmpty ? null : int.tryParse(_yearCtrl.text),
    );

    if (_isEditing) {
      await _vehicleCtrl.updateVehicle(vehicle);
    } else {
      await _vehicleCtrl.addVehicle(vehicle);
    }

    setState(() => _isSaving = false);
    if (mounted) {
      Get.back();
      Get.snackbar(
        _isEditing ? 'vehicle_updated'.tr : 'vehicle_added'.tr,
        vehicle.name,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(_isEditing ? 'edit_vehicle_title'.tr : 'new_vehicle_title'.tr),
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
                // ── Тип кузова ──
                _SectionLabel('body_type_label'.tr),
                const SizedBox(height: 10),
                _BodyTypePicker(
                  selected: _bodyType,
                  onChanged: (t) => setState(() => _bodyType = t),
                ),
                const SizedBox(height: 24),

                // ── Тип двигателя ──
                _SectionLabel('engine_type_label'.tr),
                const SizedBox(height: 10),
                _EngineTypePicker(
                  selected: _engineType,
                  onChanged: (t) => setState(() {
                    _engineType = t;
                    // Сброс подтипа гибрида при смене двигателя
                    if (t != 'hybrid') _hybridType = null;
                    // Установить дефолт для гибрида
                    if (t == 'hybrid') _hybridType ??= 'PHEV';

                    // Сброс подтипа топлива если электро или водород
                    if (t == 'electric' || t == 'hydrogen') {
                      _fuelSubtype = null;
                    } else if (t == 'diesel') {
                      _fuelSubtype = 'dt';
                    } else {
                      _fuelSubtype = null;
                    }
                  }),
                ),
                const SizedBox(height: 12),

                // ── Подтип гибрида ──
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 250),
                  crossFadeState: _engineType == 'hybrid'
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 4),
                      _SectionLabel('hybrid_type_label'.tr),
                      const SizedBox(height: 10),
                      _HybridTypePicker(
                        selected: _hybridType ?? 'PHEV',
                        onChanged: (t) => setState(() => _hybridType = t),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                  secondChild: const SizedBox.shrink(),
                ),

                // ── Марка топлива ──
                if (_engineType == 'gas' ||
                    _engineType == 'diesel' ||
                    _engineType == 'hybrid') ...[
                  _SectionLabel('fuel_subtype_label'.tr),
                  const SizedBox(height: 10),
                  _FuelSubtypePicker(
                    selected: _fuelSubtype,
                    engineType: _engineType,
                    onChanged: (t) => setState(() => _fuelSubtype = t),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Название ──
                _SectionLabel('vehicle_name_label'.tr),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.label_rounded),
                    hintText: 'vehicle_name_hint'.tr,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'vehicle_name_required'.tr
                      : null,
                ),
                const SizedBox(height: 20),

                // ── Марка и модель ──
                _SectionLabel('brand_model_label'.tr),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _modelCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.directions_car_rounded),
                    hintText: 'brand_model_hint'.tr,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'brand_model_required'.tr
                      : null,
                ),
                const SizedBox(height: 20),

                // ── Цели по расходу ──
                if (_engineType != 'electric') ...[
                  _SectionLabel('fuel_goal_label'.tr),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _goalCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))
                    ],
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.local_gas_station_rounded),
                      hintText: 'fuel_goal_hint'.tr,
                      suffixText: 'fuel_goal_suffix'.tr,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      final val = double.tryParse(v.replaceAll(',', '.'));
                      if (val == null || val <= 0) return 'goal_positive'.tr;
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                if (_engineType == 'electric' ||
                    _engineType == 'hybrid' &&
                        (_hybridType == 'PHEV' ||
                            _hybridType == 'BEV_REX')) ...[
                  _SectionLabel('ev_goal_label'.tr),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _evGoalCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))
                    ],
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.bolt_rounded),
                      hintText: 'ev_goal_hint'.tr,
                      suffixText: 'ev_goal_suffix'.tr,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      final val = double.tryParse(v.replaceAll(',', '.'));
                      if (val == null || val <= 0) return 'goal_positive'.tr;
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Напоминание ──
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _reminderEnabled,
                        onChanged: (v) => setState(() => _reminderEnabled = v),
                        title: Text('reminder_label'.tr),
                        subtitle: Text('reminder_subtitle'.tr),
                        secondary: const Icon(Icons.notifications_outlined),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 200),
                        crossFadeState: _reminderEnabled
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                        firstChild: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: TextFormField(
                            controller: _reminderCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.timer_outlined),
                              hintText: 'reminder_days_hint'.tr,
                              suffixText: 'reminder_days_suffix'.tr,
                              helperText: 'reminder_helper'.tr,
                            ),
                            validator: (v) {
                              if (!_reminderEnabled) return null;
                              if (v == null || v.isEmpty) {
                                return 'reminder_days_required'.tr;
                              }
                              final val = int.tryParse(v);
                              if (val == null || val <= 0) {
                                return 'reminder_days_invalid'.tr;
                              }
                              return null;
                            },
                          ),
                        ),
                        secondChild: const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                // ── Опциональные данные авто ──
                _SectionLabel('vehicle_details_section'.tr),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _licensePlateCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.badge_rounded),
                    hintText: 'license_plate_hint'.tr,
                    labelText: 'license_plate_label'.tr,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _engineVolumeCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))
                        ],
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.speed_rounded),
                          hintText: 'engine_volume_hint'.tr,
                          labelText: 'engine_volume_label'.tr,
                          suffixText: 'engine_volume_suffix'.tr,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _horsePowerCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.electric_bolt_rounded),
                          hintText: 'horse_power_hint'.tr,
                          labelText: 'horse_power_label'.tr,
                          suffixText: 'horse_power_suffix'.tr,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _yearCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.calendar_month_rounded),
                    hintText: 'vehicle_year_hint'.tr,
                    labelText: 'vehicle_year_label'.tr,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    final val = int.tryParse(v);
                    if (val == null ||
                        val < 1900 ||
                        val > DateTime.now().year + 1) {
                      return 'Введите корректный год';
                    }
                    return null;
                  },
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
                  label: Text(_isSaving
                      ? 'saving'.tr
                      : (_isEditing
                          ? 'save_vehicle_edit'.tr
                          : 'save_vehicle'.tr)),
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

// ─────────────────────────────────── Section label ──

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

// ─────────────────────────────────── Body type picker ──

class _BodyTypePicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _BodyTypePicker({required this.selected, required this.onChanged});

  static const _types = <String, (IconData, String)>{
    'sedan': (Icons.directions_car_rounded, 'body_sedan'),
    'hatchback': (Icons.directions_car_filled_rounded, 'body_hatchback'),
    'suv': (Icons.airport_shuttle_rounded, 'body_suv'),
    'crossover': (Icons.drive_eta_rounded, 'body_crossover'),
    'truck': (Icons.local_shipping_rounded, 'body_truck'),
    'van': (Icons.airport_shuttle_rounded, 'body_van'),
    'moto': (Icons.two_wheeler_rounded, 'body_moto'),
    'other': (Icons.commute_rounded, 'body_other'),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // 4 per row
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 0.95,
      children: _types.entries.map((e) {
        final isActive = e.key == selected;
        return GestureDetector(
          onTap: () => onChanged(e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color:
                  isActive ? cs.primaryContainer : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: isActive
                  ? Border.all(color: cs.primary, width: 2)
                  : Border.all(color: Colors.transparent, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  e.value.$1,
                  color: isActive ? cs.primary : cs.onSurfaceVariant,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  e.value.$2.tr,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: isActive ? cs.primary : cs.onSurfaceVariant,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
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

// ─────────────────────────────────── Engine type picker ──

class _EngineTypePicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _EngineTypePicker({required this.selected, required this.onChanged});

  static const _engines = <String, (IconData, String, Color)>{
    'gas': (Icons.local_gas_station_rounded, 'engine_gas', Color(0xFFE53935)),
    'diesel': (Icons.opacity_rounded, 'engine_diesel', Color(0xFF616161)),
    'hybrid': (Icons.electric_bolt_rounded, 'engine_hybrid', Color(0xFF00897B)),
    'electric': (
      Icons.ev_station_rounded,
      'engine_electric',
      Color(0xFF1E88E5)
    ),
    'hydrogen': (
      Icons.bubble_chart_rounded,
      'engine_hydrogen',
      Color(0xFF8E24AA)
    ),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _engines.entries.map((e) {
        final isActive = e.key == selected;
        final accent = e.value.$3;
        return GestureDetector(
          onTap: () => onChanged(e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? accent.withValues(alpha: 0.15)
                  : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: isActive
                  ? Border.all(color: accent, width: 2)
                  : Border.all(color: Colors.transparent, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(e.value.$1,
                    size: 18, color: isActive ? accent : cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  e.value.$2.tr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                    color: isActive ? accent : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────── Hybrid type picker ──

class _HybridTypePicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _HybridTypePicker({required this.selected, required this.onChanged});

  static const _hybrids = <String, String>{
    'PHEV': 'hybrid_PHEV_desc',
    'HEV': 'hybrid_HEV_desc',
    'MHEV': 'hybrid_MHEV_desc',
    'BEV_REX': 'hybrid_BEV_REX_desc',
    'FCEV': 'hybrid_FCEV_desc',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _hybrids.entries.map((e) {
        final isActive = e.key == selected;
        return GestureDetector(
          onTap: () => onChanged(e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:
                  isActive ? cs.secondaryContainer : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: isActive
                  ? Border.all(color: cs.secondary, width: 2)
                  : Border.all(color: Colors.transparent, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'hybrid_${e.key}'.tr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isActive ? cs.secondary : cs.onSurfaceVariant,
                  ),
                ),
                Text(
                  e.value.tr,
                  style: TextStyle(
                    fontSize: 10,
                    color: isActive
                        ? cs.onSecondaryContainer
                        : cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────── Fuel Subtype Picker ──

class _FuelSubtypePicker extends StatelessWidget {
  final String? selected;
  final String engineType;
  final ValueChanged<String> onChanged;

  const _FuelSubtypePicker({
      required this.selected,
      required this.engineType,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final options = <String>[];
    if (engineType == 'gas' || engineType == 'hybrid') {
      options.addAll(['92', '95', '98', '100', 'lpg', 'cng']);
    } else if (engineType == 'diesel') {
      options.add('dt');
    }

    if (options.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((e) {
        final isActive = e == selected;
        return GestureDetector(
          onTap: () => onChanged(e),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color:
                  isActive ? cs.primaryContainer : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: isActive
                  ? Border.all(color: cs.primary, width: 2)
                  : Border.all(color: Colors.transparent, width: 2),
            ),
            child: Text(
              'fuel_$e'.tr,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                color: isActive ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

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
  final _reminderCtrl = TextEditingController();

  String _iconType = 'sedan';
  bool _isSaving = false;
  bool _reminderEnabled = false;

  final _vehicleCtrl = Get.find<VehicleController>();

  bool get _isEditing => widget.editVehicle != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final v = widget.editVehicle!;
      _nameCtrl.text = v.name;
      _modelCtrl.text = v.model;
      _iconType = v.iconType;
      if (v.fuelGoal != null) _goalCtrl.text = v.fuelGoal!.toStringAsFixed(1);
      if (v.reminderDays != null) {
        _reminderEnabled = true;
        _reminderCtrl.text = v.reminderDays!.toString();
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _modelCtrl.dispose();
    _goalCtrl.dispose();
    _reminderCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    // Если включили напоминания — запрашиваем разрешение.
    if (_reminderEnabled) {
      await NotificationService.instance.requestPermission();
    }

    final vehicle = Vehicle(
      id: widget.editVehicle?.id,
      name: _nameCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      iconType: _iconType,
      fuelGoal: _goalCtrl.text.isEmpty
          ? null
          : double.tryParse(_goalCtrl.text.replaceAll(',', '.')),
      reminderDays: _reminderEnabled && _reminderCtrl.text.isNotEmpty
          ? int.tryParse(_reminderCtrl.text)
          : null,
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
        _isEditing ? '✅ Автомобиль обновлён' : '✅ Автомобиль добавлен',
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
        title: Text(_isEditing ? 'Изменить автомобиль' : 'Новый автомобиль'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Иконка ──
              Text('Тип автомобиля',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 10),
              _IconPicker(
                selected: _iconType,
                onChanged: (t) => setState(() => _iconType = t),
              ),
              const SizedBox(height: 20),

              // ── Название ──
              Text('Название (ваше)', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.label_rounded),
                  hintText: 'Например: Моя Vesta',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Введите название' : null,
              ),
              const SizedBox(height: 20),

              // ── Модель ──
              Text('Марка и модель', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _modelCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.directions_car_rounded),
                  hintText: 'Например: Lada Vesta 1.6',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Введите модель' : null,
              ),
              const SizedBox(height: 20),

              // ── Целевой расход (необязательно) ──
              Text('Целевой расход — необязательно',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _goalCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))
                ],
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.flag_rounded),
                  hintText: 'Например: 8.0',
                  suffixText: 'л/100 км',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  final val = double.tryParse(v.replaceAll(',', '.'));
                  if (val == null || val <= 0) return 'Должно быть > 0';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── Напоминание (необязательно) ──
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _reminderEnabled,
                      onChanged: (v) => setState(() => _reminderEnabled = v),
                      title: const Text('Напоминание о записи'),
                      subtitle: const Text(
                          'Уведомить, если не было записей N дней'),
                      secondary:
                          const Icon(Icons.notifications_outlined),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    if (_reminderEnabled)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: TextFormField(
                          controller: _reminderCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.timer_outlined),
                            hintText: 'Например: 14',
                            suffixText: 'дней',
                            helperText:
                                'Напоминание при открытии приложения',
                          ),
                          validator: (v) {
                            if (!_reminderEnabled) return null;
                            if (v == null || v.isEmpty) return 'Введите количество дней';
                            final val = int.tryParse(v);
                            if (val == null || val <= 0) return 'Должно быть > 0';
                            return null;
                          },
                        ),
                      ),
                  ],
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
                label: Text(_isSaving
                    ? 'Сохранение…'
                    : (_isEditing ? 'Сохранить изменения' : 'Добавить автомобиль')),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────── Icon picker ──

class _IconPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _IconPicker({required this.selected, required this.onChanged});

  static const _types = <String, (IconData, String)>{
    'sedan': (Icons.directions_car_rounded, 'Легковая'),
    'suv': (Icons.directions_car_filled_rounded, 'SUV'),
    'truck': (Icons.local_shipping_rounded, 'Грузовик'),
    'moto': (Icons.two_wheeler_rounded, 'Мото'),
    'electric': (Icons.electric_car_rounded, 'Электро'),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _types.entries.map((e) {
        final isActive = e.key == selected;
        return GestureDetector(
          onTap: () => onChanged(e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 62,
            height: 70,
            decoration: BoxDecoration(
              color: isActive ? cs.primaryContainer : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: isActive
                  ? Border.all(color: cs.primary, width: 2)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  e.value.$1,
                  color: isActive ? cs.primary : cs.onSurfaceVariant,
                  size: 26,
                ),
                const SizedBox(height: 4),
                Text(
                  e.value.$2,
                  style: TextStyle(
                    fontSize: 9,
                    color: isActive ? cs.primary : cs.onSurfaceVariant,
                    fontWeight:
                        isActive ? FontWeight.w700 : FontWeight.normal,
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

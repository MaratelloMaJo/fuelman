import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/fuel_entry_controller.dart';
import '../controllers/vehicle_controller.dart';
import '../models/fuel_entry.dart';

/// Экран добавления новой записи о заправке.
///
/// Валидация:
///   — Одометр должен быть > последнего значения одометра.
///   — Объём > 0.
///   — Цена за литр необязательна, но если указана — должна быть > 0.
class AddEntryScreen extends StatefulWidget {
  const AddEntryScreen({super.key});

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _odometerCtrl = TextEditingController();
  final _volumeCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  bool _isFullTank = true;
  bool _isSaving = false;

  final _entryCtrl = Get.find<FuelEntryController>();
  final _vehicleCtrl = Get.find<VehicleController>();

  double? get _lastOdometer => _entryCtrl.lastOdometer;

  @override
  void dispose() {
    _odometerCtrl.dispose();
    _volumeCtrl.dispose();
    _priceCtrl.dispose();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final vehicle = _vehicleCtrl.selectedVehicle.value;
    if (vehicle == null) return;

    setState(() => _isSaving = true);

    final entry = FuelEntry(
      vehicleId: vehicle.id!,
      date: _date,
      odometer: double.parse(_odometerCtrl.text.replaceAll(',', '.')),
      volume: double.parse(_volumeCtrl.text.replaceAll(',', '.')),
      isFullTank: _isFullTank,
      pricePerLiter: _priceCtrl.text.isEmpty
          ? null
          : double.tryParse(_priceCtrl.text.replaceAll(',', '.')),
    );

    await _entryCtrl.addEntry(entry);
    setState(() => _isSaving = false);

    if (mounted) {
      Get.back();
      Get.snackbar(
        '✅ Запись добавлена',
        _isFullTank ? 'Расход будет пересчитан' : 'Дозаправка записана',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('dd MMMM yyyy', 'ru');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая заправка'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Автомобиль (только информация) ──
              Obx(() {
                final v = _vehicleCtrl.selectedVehicle.value;
                if (v == null) return const SizedBox.shrink();
                return Card(
                  color: cs.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.directions_car_rounded,
                            color: cs.onPrimaryContainer),
                        const SizedBox(width: 12),
                        Text(
                          '${v.name} — ${v.model}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),

              // ── Дата ──
              Text('Дата заправки',
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

              // ── Одометр ──
              Text('Показания одометра (км)',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _odometerCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))
                ],
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.speed_rounded),
                  hintText: _lastOdometer != null
                      ? 'Последний: ${_lastOdometer!.toStringAsFixed(0)} км'
                      : 'Например: 50000',
                  suffixText: 'км',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Введите показания';
                  final val =
                      double.tryParse(v.replaceAll(',', '.'));
                  if (val == null) return 'Некорректное число';
                  if (_lastOdometer != null && val <= _lastOdometer!) {
                    return 'Должно быть больше ${_lastOdometer!.toStringAsFixed(0)} км';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── Объём ──
              Text('Объём топлива (л)',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _volumeCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))
                ],
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.water_drop_rounded),
                  hintText: 'Например: 45.5',
                  suffixText: 'л',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Введите объём';
                  final val = double.tryParse(v.replaceAll(',', '.'));
                  if (val == null || val <= 0) return 'Должно быть > 0';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── Цена за литр (необязательно) ──
              Text('Цена за литр — необязательно',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))
                ],
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.sell_rounded),
                  hintText: 'Например: 60.5',
                  suffixText: '₽/л',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return null; // необязательно
                  final val = double.tryParse(v.replaceAll(',', '.'));
                  if (val == null || val <= 0) return 'Должно быть > 0';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // ── Тип заправки ──
              Card(
                child: SwitchListTile(
                  value: _isFullTank,
                  onChanged: (v) => setState(() => _isFullTank = v),
                  title: const Text('Полный бак'),
                  subtitle: Text(
                    _isFullTank
                        ? 'Расход будет рассчитан (Full-to-Full)'
                        : 'Дозаправка: расход не рассчитывается',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  secondary: Icon(
                    _isFullTank
                        ? Icons.local_gas_station_rounded
                        : Icons.ev_station_rounded,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Кнопка сохранения ──
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_isSaving ? 'Сохранение…' : 'Сохранить запись'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

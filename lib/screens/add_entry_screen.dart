import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/fuel_entry_controller.dart';
import '../controllers/vehicle_controller.dart';
import '../controllers/settings_controller.dart';
import '../models/fuel_entry.dart';
import '../models/vehicle.dart';

/// Экран добавления записи о заправке или зарядке.
///
/// Умно адаптируется под тип автомобиля:
///   — газ/дизель: только топливо
///   — электро: только зарядка
///   — PHEV/BEV+REx: выбор топливо / зарядка
///   — HEV/MHEV: только топливо (самозаряжающийся)
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

  String _entryType = 'fuel';
  String _volumeUnit = 'L';
  String _currency = 'RUB';

  final _entryCtrl = Get.find<FuelEntryController>();
  final _vehicleCtrl = Get.find<VehicleController>();
  final _settingsCtrl = Get.find<SettingsController>();

  @override
  void initState() {
    super.initState();
    _volumeUnit = _settingsCtrl.volumeUnit.value;
    _currency = _settingsCtrl.currency.value;

    final vehicle = _vehicleCtrl.selectedVehicle.value;
    _initEntryType(vehicle);
  }

  /// Устанавливает начальный тип записи на основе типа авто.
  void _initEntryType(Vehicle? vehicle) {
    if (vehicle == null) return;

    if (vehicle.isFullyElectric) {
      _entryType = 'charge';
      _volumeUnit = 'kWh';
    } else if (vehicle.isSelfChargingHybrid) {
      // HEV/MHEV — только топливо, зарядки нет
      _entryType = 'fuel';
      _volumeUnit = _settingsCtrl.volumeUnit.value;
    } else {
      _entryType = 'fuel';
    }
  }

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
      entryType: _entryType,
      volumeUnit: _volumeUnit,
      currency: _currency,
    );

    await _entryCtrl.addEntry(entry);
    setState(() => _isSaving = false);

    if (mounted) {
      Get.back();
      final isCharge = _entryType == 'charge';
      Get.snackbar(
        'entry_added'.tr,
        isCharge
            ? 'entry_charge_added'.tr
            : (_isFullTank ? 'entry_full_recalc'.tr : 'entry_partial'.tr),
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
        title: Text(_entryType == 'charge' ? 'new_charge_title'.tr : 'new_entry_title'.tr),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Obx(() {
            final vehicle = _vehicleCtrl.selectedVehicle.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Карточка выбранного авто ──
                if (vehicle != null)
                  _VehicleInfoCard(vehicle: vehicle, cs: cs),
                const SizedBox(height: 16),

                // ── Переключатель топливо/зарядка (только если поддерживается) ──
                if (vehicle != null &&
                    vehicle.canCharge &&
                    vehicle.canRefuel &&
                    !vehicle.isSelfChargingHybrid) ...[
                  _EntryTypePicker(
                    selected: _entryType,
                    onChanged: (t) => setState(() {
                      _entryType = t;
                      _volumeUnit = t == 'charge'
                          ? 'kWh'
                          : _settingsCtrl.volumeUnit.value;
                    }),
                  ),
                  const SizedBox(height: 16),
                ],

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

                // ── Одометр ──
                Text('odometer_label'.tr,
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _odometerCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))
                  ],
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.speed_rounded),
                    hintText: _lastOdometer != null
                        ? '${'odometer_label'.tr}: ${_lastOdometer!.toStringAsFixed(0)}'
                        : '50000',
                    suffixText: 'odometer_suffix'.tr,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'odometer_required'.tr;
                    final val = double.tryParse(v.replaceAll(',', '.'));
                    if (val == null) return 'odometer_invalid'.tr;
                    if (_lastOdometer != null && val <= _lastOdometer!) {
                      return '${'odometer_too_low'.tr} ${_lastOdometer!.toStringAsFixed(0)} ${'odometer_suffix'.tr}';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ── Объём ──
                Text(
                  _entryType == 'charge' ? 'volume_label_charge'.tr : 'volume_label_fuel'.tr,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _volumeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))
                  ],
                  decoration: InputDecoration(
                    prefixIcon: Icon(_entryType == 'charge'
                        ? Icons.bolt_rounded
                        : Icons.water_drop_rounded),
                    hintText: _entryType == 'charge' ? '45.0' : '40.0',
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _volumeUnit,
                          isDense: true,
                          items: (_entryType == 'charge'
                              ? ['kWh']
                              : ['L', 'gal'])
                              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: _entryType == 'charge'
                              ? null
                              : (v) {
                                  if (v != null) setState(() => _volumeUnit = v);
                                },
                        ),
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'volume_required'.tr;
                    final val = double.tryParse(v.replaceAll(',', '.'));
                    if (val == null || val <= 0) return 'volume_invalid'.tr;
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ── Цена за единицу ──
                Text('price_label'.tr,
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))
                  ],
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.sell_rounded),
                    hintText: _entryType == 'charge' ? '15.0' : '60.0',
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
                    if (v == null || v.isEmpty) return null;
                    final val = double.tryParse(v.replaceAll(',', '.'));
                    if (val == null || val <= 0) return 'price_invalid'.tr;
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ── Полный бак / Полная зарядка ──
                Card(
                  child: SwitchListTile(
                    value: _isFullTank,
                    onChanged: (v) => setState(() => _isFullTank = v),
                    title: Text(_entryType == 'charge' ? 'full_charge'.tr : 'full_tank'.tr),
                    subtitle: Text(
                      _isFullTank
                          ? 'full_tank_subtitle'.tr
                          : 'partial_subtitle'.tr,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    secondary: Icon(
                      _isFullTank
                          ? (_entryType == 'charge'
                              ? Icons.battery_full_rounded
                              : Icons.local_gas_station_rounded)
                          : Icons.battery_4_bar_rounded,
                      color: _isFullTank ? cs.primary : cs.onSurfaceVariant,
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
                  label: Text(_isSaving ? 'saving'.tr : 'save_entry'.tr),
                ),
                const SizedBox(height: 16),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ─────────────────────────── Vehicle info card ──

class _VehicleInfoCard extends StatelessWidget {
  final Vehicle vehicle;
  final ColorScheme cs;

  const _VehicleInfoCard({required this.vehicle, required this.cs});

  @override
  Widget build(BuildContext context) {
    // Показываем подтип гибрида если есть
    final subtitle = vehicle.hybridType != null
        ? 'hybrid_${vehicle.hybridType}'.tr
        : null;

    return Card(
      color: cs.primaryContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(_engineIcon(vehicle.engineType),
                color: cs.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${vehicle.name} — ${vehicle.model}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onPrimaryContainer.withValues(alpha: 0.75),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _engineIcon(String type) {
    switch (type) {
      case 'electric':
        return Icons.ev_station_rounded;
      case 'hybrid':
        return Icons.electric_bolt_rounded;
      case 'diesel':
        return Icons.opacity_rounded;
      case 'hydrogen':
        return Icons.bubble_chart_rounded;
      default:
        return Icons.local_gas_station_rounded;
    }
  }
}

// ─────────────────────────── Entry type picker (fuel / charge) ──

class _EntryTypePicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _EntryTypePicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _Tab(
            icon: Icons.local_gas_station_rounded,
            label: 'entry_type_fuel'.tr,
            isActive: selected == 'fuel',
            activeColor: const Color(0xFFE53935),
            onTap: () => onChanged('fuel'),
          ),
          _Tab(
            icon: Icons.bolt_rounded,
            label: 'entry_type_charge'.tr,
            isActive: selected == 'charge',
            activeColor: const Color(0xFF1E88E5),
            onTap: () => onChanged('charge'),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _Tab({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(color: activeColor, width: 1.5)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: isActive ? activeColor : cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                  color: isActive ? activeColor : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

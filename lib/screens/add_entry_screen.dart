import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/fuel_entry_controller.dart';
import '../controllers/vehicle_controller.dart';
import '../controllers/settings_controller.dart';
import '../models/fuel_entry.dart';
import '../models/vehicle.dart';
import '../services/location_service.dart';

/// Экран добавления/редактирования записи о заправке или зарядке.
///
/// Улучшения:
///   — Живой предпросмотр предполагаемого расхода
///   — Предупреждения при аномальных данных (малое/большое расстояние, нереальный объём)
///   — Диалог подтверждения при аномальном расходе
///   — Адаптация под тип автомобиля (газ/дизель/электро/гибрид)
class AddEntryScreen extends StatefulWidget {
  final FuelEntry? editEntry;
  const AddEntryScreen({super.key, this.editEntry});

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _odometerCtrl = TextEditingController();
  final _volumeCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _totalPriceCtrl = TextEditingController();

  final _odometerFocus = FocusNode();
  final _volumeFocus = FocusNode();
  final _priceFocus = FocusNode();
  final _totalPriceFocus = FocusNode();

  DateTime _date = DateTime.now();
  bool _isFullTank = true;
  bool _isSaving = false;

  String _entryType = 'fuel';
  String _volumeUnit = 'L';
  String _currency = 'RUB';

  /// Предварительный расход для предпросмотра.
  double? _previewConsumption;

  /// Текущее предупреждение об аномалии.
  AnomalyWarning? _warning;

  bool _isCalculating = false;

  // GPS
  double? _latitude;
  double? _longitude;
  bool _isGettingLocation = false;

  // Название станции
  final _stationNameCtrl = TextEditingController();

  final _entryCtrl = Get.find<FuelEntryController>();
  final _vehicleCtrl = Get.find<VehicleController>();
  final _settingsCtrl = Get.find<SettingsController>();

  @override
  void initState() {
    super.initState();
    if (widget.editEntry != null) {
      _volumeUnit = widget.editEntry!.volumeUnit;
      _currency = widget.editEntry!.currency;
      _date = widget.editEntry!.date;
      _isFullTank = widget.editEntry!.isFullTank;
      _entryType = widget.editEntry!.entryType;
      _latitude = widget.editEntry!.latitude;
      _longitude = widget.editEntry!.longitude;
      if (widget.editEntry!.stationName != null) {
        _stationNameCtrl.text = widget.editEntry!.stationName!;
      }

      _odometerCtrl.text = widget.editEntry!.odometer.toStringAsFixed(1);
      _volumeCtrl.text = widget.editEntry!.volume.toStringAsFixed(2);
      if (widget.editEntry!.pricePerLiter != null) {
        _priceCtrl.text = widget.editEntry!.pricePerLiter!.toStringAsFixed(2);
      }
      if (widget.editEntry!.totalCost != null) {
        _totalPriceCtrl.text =
            widget.editEntry!.totalCost!.toStringAsFixed(2);
      }
    } else {
      _volumeUnit = _settingsCtrl.volumeUnit.value;
      _currency = _settingsCtrl.currency.value;
    }

    if (widget.editEntry == null) {
      final vehicle = _vehicleCtrl.selectedVehicle.value;
      _initEntryType(vehicle);
    }

    _volumeCtrl.addListener(_onVolumeChanged);
    _priceCtrl.addListener(_onPriceChanged);
    _totalPriceCtrl.addListener(_onTotalPriceChanged);
    _odometerCtrl.addListener(_onOdometerChanged);
  }

  void _initEntryType(Vehicle? vehicle) {
    if (vehicle == null) return;
    if (vehicle.isFullyElectric) {
      _entryType = 'charge';
      _volumeUnit = 'kWh';
    } else if (vehicle.isSelfChargingHybrid) {
      _entryType = 'fuel';
      _volumeUnit = _settingsCtrl.volumeUnit.value;
    } else {
      _entryType = 'fuel';
    }
  }

  double? get _lastOdometer {
    if (widget.editEntry != null) return null;
    return _entryCtrl.lastOdometer;
  }

  // ─────────────────────────── Live Calculation ──

  void _onOdometerChanged() => _updatePreview();
  void _onVolumeChanged() {
    if (_isCalculating || !_volumeFocus.hasFocus) return;
    _recalcTotalOrPrice(fromVolume: true);
    _updatePreview();
  }

  void _onPriceChanged() {
    if (_isCalculating || !_priceFocus.hasFocus) return;
    _recalcTotalOrPrice(fromPrice: true);
  }

  void _onTotalPriceChanged() {
    if (_isCalculating || !_totalPriceFocus.hasFocus) return;
    final t = double.tryParse(_totalPriceCtrl.text.replaceAll(',', '.')) ?? 0;
    final p = double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0;
    final v = double.tryParse(_volumeCtrl.text.replaceAll(',', '.')) ?? 0;

    if (t > 0 && p > 0) {
      _isCalculating = true;
      _volumeCtrl.text = (t / p).toStringAsFixed(2);
      _isCalculating = false;
    } else if (t > 0 && v > 0) {
      _isCalculating = true;
      _priceCtrl.text = (t / v).toStringAsFixed(2);
      _isCalculating = false;
    }
    _updatePreview();
  }

  void _recalcTotalOrPrice({bool fromVolume = false, bool fromPrice = false}) {
    final v = double.tryParse(_volumeCtrl.text.replaceAll(',', '.')) ?? 0;
    final p = double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0;
    final t = double.tryParse(_totalPriceCtrl.text.replaceAll(',', '.')) ?? 0;

    if (fromVolume) {
      if (p > 0) {
        _isCalculating = true;
        _totalPriceCtrl.text = (v * p).toStringAsFixed(2);
        _isCalculating = false;
      } else if (t > 0 && v > 0) {
        _isCalculating = true;
        _priceCtrl.text = (t / v).toStringAsFixed(2);
        _isCalculating = false;
      }
    } else if (fromPrice) {
      if (v > 0) {
        _isCalculating = true;
        _totalPriceCtrl.text = (v * p).toStringAsFixed(2);
        _isCalculating = false;
      } else if (t > 0 && p > 0) {
        _isCalculating = true;
        _volumeCtrl.text = (t / p).toStringAsFixed(2);
        _isCalculating = false;
      }
    }
  }

  /// Обновляет предпросмотр расхода и предупреждение.
  void _updatePreview() {
    final odometer =
        double.tryParse(_odometerCtrl.text.replaceAll(',', '.'));
    final volume =
        double.tryParse(_volumeCtrl.text.replaceAll(',', '.'));
    final prev = _lastOdometer;

    if (odometer == null || volume == null || volume <= 0) {
      setState(() {
        _previewConsumption = null;
        _warning = null;
      });
      return;
    }

    // Предупреждение
    final warning = _entryCtrl.checkAnomalyWarning(
      odometer: odometer,
      volume: volume,
      prevOdometer: prev,
      entryType: _entryType,
    );

    // Предпросмотр расхода (только если есть предыдущий одометр)
    double? preview;
    if (prev != null) {
      final tailPartials = _entryCtrl.getTailPartials(_entryType);
      preview = _entryCtrl.previewConsumption(
        odometer: odometer,
        volume: volume,
        prevOdometer: prev,
        isFullTank: _isFullTank,
        tailPartials: tailPartials,
      );
    }

    setState(() {
      _previewConsumption = preview;
      _warning = warning;
    });
  }

  @override
  void dispose() {
    _volumeCtrl.removeListener(_onVolumeChanged);
    _priceCtrl.removeListener(_onPriceChanged);
    _totalPriceCtrl.removeListener(_onTotalPriceChanged);
    _odometerCtrl.removeListener(_onOdometerChanged);

    _odometerCtrl.dispose();
    _volumeCtrl.dispose();
    _priceCtrl.dispose();
    _totalPriceCtrl.dispose();
    _stationNameCtrl.dispose();
    _odometerFocus.dispose();
    _volumeFocus.dispose();
    _priceFocus.dispose();
    _totalPriceFocus.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _isGettingLocation = true);
    final loc = await LocationService.instance.getCurrentLocation();
    setState(() {
      _isGettingLocation = false;
      if (loc != null) {
        _latitude = loc.latitude;
        _longitude = loc.longitude;
        Get.snackbar('gps_saved'.tr,
            '${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 2));
      } else {
        Get.snackbar('gps_error'.tr, '',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 2));
      }
    });
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

  // ─────────────────────────────────── Save ──

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final vehicle = _vehicleCtrl.selectedVehicle.value;
    if (vehicle == null) return;

    // Если есть аномалия — спрашиваем пользователя
    if (_warning != null) {
      final proceed = await _showAnomalyDialog(_warning!);
      if (!proceed) return;
    }

    setState(() => _isSaving = true);

    final entry = FuelEntry(
      id: widget.editEntry?.id,
      vehicleId: vehicle.id!,
      date: _date,
      odometer: double.parse(_odometerCtrl.text.replaceAll(',', '.')),
      volume: double.parse(_volumeCtrl.text.replaceAll(',', '.')),
      isFullTank: _isFullTank,
      pricePerLiter: _priceCtrl.text.isEmpty
          ? null
          : double.tryParse(_priceCtrl.text.replaceAll(',', '.')),
      storedTotalCost: _totalPriceCtrl.text.isEmpty
          ? null
          : double.tryParse(_totalPriceCtrl.text.replaceAll(',', '.')),
      entryType: _entryType,
      volumeUnit: _volumeUnit,
      currency: _currency,
      latitude: _latitude,
      longitude: _longitude,
      stationName: _stationNameCtrl.text.trim().isEmpty
          ? null
          : _stationNameCtrl.text.trim(),
    );

    if (widget.editEntry != null) {
      await _entryCtrl.updateEntry(entry);
    } else {
      await _entryCtrl.addEntry(entry);
    }

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

  // ─────────────────────────── Anomaly Dialog ──

  Future<bool> _showAnomalyDialog(AnomalyWarning warning) async {
    final cs = Theme.of(context).colorScheme;

    // Сообщение и тип диалога зависят от предупреждения
    final bool isBlocker = warning == AnomalyWarning.odometerDecreased;
    final (title, body, icon) = _warningDetails(warning);

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            icon: Icon(icon,
                color: isBlocker ? cs.error : Colors.orange, size: 36),
            title: Text(title,
                style:
                    TextStyle(color: isBlocker ? cs.error : Colors.orange)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(body),
                if (!isBlocker && _previewConsumption != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.orange.withAlpha(80), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_gas_station_rounded,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          '${_previewConsumption!.toStringAsFixed(1)} ${_volumeUnit == 'kWh' ? 'кВт·ч' : _volumeUnit}/100 км',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'anomaly_will_be_marked'.tr,
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('cancel'.tr),
              ),
              if (!isBlocker)
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('save_anyway'.tr),
                ),
              if (isBlocker)
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('ok'.tr),
                ),
            ],
          ),
        ) ??
        false;
  }

  (String, String, IconData) _warningDetails(AnomalyWarning w) {
    switch (w) {
      case AnomalyWarning.odometerDecreased:
        return (
          'warn_odo_decreased_title'.tr,
          'warn_odo_decreased_body'.tr,
          Icons.error_rounded,
        );
      case AnomalyWarning.distanceTooSmall:
        return (
          'warn_dist_small_title'.tr,
          'warn_dist_small_body'.tr,
          Icons.warning_amber_rounded,
        );
      case AnomalyWarning.distanceTooLarge:
        return (
          'warn_dist_large_title'.tr,
          'warn_dist_large_body'.tr,
          Icons.warning_amber_rounded,
        );
      case AnomalyWarning.volumeTooLarge:
        return (
          'warn_vol_large_title'.tr,
          'warn_vol_large_body'.tr,
          Icons.warning_amber_rounded,
        );
      case AnomalyWarning.consumptionAnomalous:
        return (
          'warn_consumption_title'.tr,
          'warn_consumption_body'.tr,
          Icons.warning_amber_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final locale = _settingsCtrl.language.value == 'kk'
        ? 'ru'
        : _settingsCtrl.language.value;
    final dateFmt = DateFormat('dd MMMM yyyy', locale);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editEntry != null
            ? 'Редактировать запись'
            : (_entryType == 'charge'
                ? 'new_charge_title'.tr
                : 'new_entry_title'.tr)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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

                // ── Переключатель топливо/зарядка ──
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
                      _updatePreview();
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
                  focusNode: _odometerFocus,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))
                  ],
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.speed_rounded),
                    hintText: _lastOdometer != null
                        ? '${'odometer_label'.tr}: ${_lastOdometer!.toStringAsFixed(0)}'
                        : '50000',
                    suffixText: 'odometer_suffix'.tr,
                    helperText: _lastOdometer != null
                        ? '${'prev_odometer_hint'.tr}: ${_lastOdometer!.toStringAsFixed(0)} км'
                        : null,
                    helperStyle:
                        TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
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
                  _entryType == 'charge'
                      ? 'volume_label_charge'.tr
                      : 'volume_label_fuel'.tr,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _volumeCtrl,
                  focusNode: _volumeFocus,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
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
                              .map((u) =>
                                  DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: _entryType == 'charge'
                              ? null
                              : (v) {
                                  if (v != null) {
                                    setState(() => _volumeUnit = v);
                                    _updatePreview();
                                  }
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
                  focusNode: _priceFocus,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
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
                              .map((c) =>
                                  DropdownMenuItem(value: c, child: Text(c)))
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
                const SizedBox(height: 20),

                // ── Общая стоимость ──
                Text('total_price_label'.tr,
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _totalPriceCtrl,
                  focusNode: _totalPriceFocus,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))
                  ],
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.attach_money_rounded),
                    hintText: '1000.0',
                    suffixText: _currency,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return null;
                    final val = double.tryParse(v.replaceAll(',', '.'));
                    if (val == null || val <= 0) return 'price_invalid'.tr;
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ── Название станции / места зарядки ──
                Text('station_name_label'.tr,
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _stationNameCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.local_gas_station_rounded),
                    hintText: 'station_name_hint'.tr,
                  ),
                ),
                const SizedBox(height: 16),

                // ── GPS ──
                _FuelGpsSection(
                  latitude: _latitude,
                  longitude: _longitude,
                  isGetting: _isGettingLocation,
                  onGetLocation: _getLocation,
                  onClear: () => setState(() { _latitude = null; _longitude = null; }),
                ),
                const SizedBox(height: 16),

                // ── Полный бак / Полная зарядка ──
                Card(
                  child: SwitchListTile(
                    value: _isFullTank,
                    onChanged: (v) => setState(() {
                      _isFullTank = v;
                      _updatePreview();
                    }),
                    title: Text(_entryType == 'charge'
                        ? 'full_charge'.tr
                        : 'full_tank'.tr),
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
                const SizedBox(height: 16),

                // ── Карточка предпросмотра расхода ──
                _ConsumptionPreviewCard(
                  previewConsumption: _previewConsumption,
                  warning: _warning,
                  entryType: _entryType,
                  volumeUnit: _volumeUnit,
                  prevOdometer: _lastOdometer,
                  currentOdometer:
                      double.tryParse(_odometerCtrl.text.replaceAll(',', '.')),
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
    ),
  );
}
}

// ─────────────────────── Fuel GPS Section ──

class _FuelGpsSection extends StatelessWidget {
  final double? latitude;
  final double? longitude;
  final bool isGetting;
  final VoidCallback onGetLocation;
  final VoidCallback onClear;

  const _FuelGpsSection({
    required this.latitude,
    required this.longitude,
    required this.isGetting,
    required this.onGetLocation,
    required this.onClear,
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
                  child: GestureDetector(
                    onTap: () async {
                      final uri = Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } else {
                        final webUri = Uri.parse('https://maps.google.com/?q=$latitude,$longitude');
                        await launchUrl(webUri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Text(
                      '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClear,
                  icon: Icon(Icons.close_rounded, size: 18, color: cs.onSurfaceVariant),
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
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location_rounded, size: 18),
            label: Text(isGetting ? 'gps_getting'.tr : 'gps_button'.tr),
          ),
      ],
    );
  }
}
// ─────────────────────── Consumption Preview Card ──

class _ConsumptionPreviewCard extends StatelessWidget {
  final double? previewConsumption;
  final AnomalyWarning? warning;
  final String entryType;
  final String volumeUnit;
  final double? prevOdometer;
  final double? currentOdometer;

  const _ConsumptionPreviewCard({
    required this.previewConsumption,
    required this.warning,
    required this.entryType,
    required this.volumeUnit,
    required this.prevOdometer,
    required this.currentOdometer,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Расстояние
    double? distance;
    if (prevOdometer != null && currentOdometer != null) {
      distance = currentOdometer! - prevOdometer!;
    }

    // Если нет ни предпросмотра, ни предупреждения, ни предыдущего — не показываем
    if (prevOdometer == null && warning == null) return const SizedBox.shrink();
    if (previewConsumption == null && warning == null && distance == null) {
      return const SizedBox.shrink();
    }

    Color cardColor;
    Color borderColor;
    IconData icon;
    String statusText;

    if (warning == AnomalyWarning.odometerDecreased) {
      cardColor = cs.errorContainer;
      borderColor = cs.error;
      icon = Icons.error_rounded;
      statusText = 'warn_odo_decreased_title'.tr;
    } else if (warning == AnomalyWarning.distanceTooSmall) {
      cardColor = Colors.orange.withAlpha(20);
      borderColor = Colors.orange;
      icon = Icons.warning_amber_rounded;
      statusText = 'warn_dist_small_short'.tr;
    } else if (warning == AnomalyWarning.distanceTooLarge) {
      cardColor = Colors.orange.withAlpha(20);
      borderColor = Colors.orange;
      icon = Icons.warning_amber_rounded;
      statusText = 'warn_dist_large_short'.tr;
    } else if (warning == AnomalyWarning.volumeTooLarge) {
      cardColor = Colors.orange.withAlpha(20);
      borderColor = Colors.orange;
      icon = Icons.warning_amber_rounded;
      statusText = 'warn_vol_large_short'.tr;
    } else if (warning == AnomalyWarning.consumptionAnomalous) {
      cardColor = Colors.orange.withAlpha(20);
      borderColor = Colors.orange;
      icon = Icons.warning_amber_rounded;
      statusText = 'warn_consumption_short'.tr;
    } else if (previewConsumption != null) {
      // Нормальный предпросмотр
      cardColor = cs.primaryContainer.withAlpha(80);
      borderColor = cs.primary.withAlpha(80);
      icon = entryType == 'charge'
          ? Icons.bolt_rounded
          : Icons.local_gas_station_rounded;
      statusText = 'preview_consumption_label'.tr;
    } else {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: warning != null ? borderColor : cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    color: warning != null ? borderColor : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (previewConsumption != null &&
                    warning != AnomalyWarning.odometerDecreased &&
                    warning != AnomalyWarning.distanceTooSmall)
                  Text(
                    '${previewConsumption!.toStringAsFixed(1)} ${volumeUnit == 'kWh' ? 'кВт·ч' : volumeUnit}/100 км',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: warning != null ? borderColor : cs.primary,
                    ),
                  ),
                if (distance != null && distance > 0)
                  Text(
                    '${'distance_traveled'.tr}: ${distance.toStringAsFixed(0)} км',
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
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
    final subtitle =
        vehicle.hybridType != null ? 'hybrid_${vehicle.hybridType}'.tr : null;

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
                        color:
                            cs.onPrimaryContainer.withValues(alpha: 0.75),
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

// ─────────────────────────── Entry type picker ──

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
            color: isActive
                ? activeColor.withValues(alpha: 0.15)
                : Colors.transparent,
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
                  fontWeight:
                      isActive ? FontWeight.w700 : FontWeight.normal,
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

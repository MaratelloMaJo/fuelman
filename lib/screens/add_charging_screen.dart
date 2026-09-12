import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../controllers/charging_entry_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/vehicle_controller.dart';
import '../models/charging_entry.dart';

/// Экран добавления или редактирования сессии зарядки EV/PHEV.
///
/// Поддерживаемые режимы:
///   — Добавление: [editEntry] == null
///   — Редактирование: [editEntry] содержит существующую запись
///
/// Минимально-обязательные поля:
///   — Показания одометра
///   — Количество кВт·ч
///
/// Опциональные поля:
///   — EV-одометр (BYD DM-i, Chazor и подобные с раздельной телеметрией)
///   — SOC начало / конец
///   — Тип зарядки (AC/DC), стандарт разъёма
///   — Мощность зарядки, температура, название станции
class AddChargingScreen extends StatefulWidget {
  final ChargingEntry? editEntry;

  const AddChargingScreen({super.key, this.editEntry});

  @override
  State<AddChargingScreen> createState() => _AddChargingScreenState();
}

class _AddChargingScreenState extends State<AddChargingScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Поля формы ──
  final _odometerCtrl = TextEditingController();
  final _evOdometerCtrl = TextEditingController();
  final _kwhCtrl = TextEditingController();
  final _tariffCtrl = TextEditingController();
  final _totalCostCtrl = TextEditingController();
  final _powerCtrl = TextEditingController();
  final _temperatureCtrl = TextEditingController();
  final _stationCtrl = TextEditingController();
  final _socStartCtrl = TextEditingController();
  final _socEndCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  ChargerType _chargerType = ChargerType.acSlow;
  ChargerStandard _chargerStandard = ChargerStandard.homeSocket;
  String _currency = 'RUB';
  bool _isSaving = false;

  /// true — стоимость вычисляется автоматически из тарифа и объёма.
  /// false — пользователь ввёл итоговую стоимость вручную.
  bool _useTariff = true;

  final _chargingCtrl = Get.find<ChargingEntryController>();
  final _vehicleCtrl = Get.find<VehicleController>();
  final _settingsCtrl = Get.find<SettingsController>();

  bool get _isEditing => widget.editEntry != null;

  @override
  void initState() {
    super.initState();
    _currency = _settingsCtrl.currency.value;

    if (_isEditing) {
      final e = widget.editEntry!;
      _odometerCtrl.text = e.odometer.toStringAsFixed(0);
      if (e.evOdometer != null) {
        _evOdometerCtrl.text = e.evOdometer!.toStringAsFixed(0);
      }
      _kwhCtrl.text = e.kwhAdded.toStringAsFixed(2);
      _totalCostCtrl.text = e.totalCost.toStringAsFixed(2);
      if (e.powerKw != null) _powerCtrl.text = e.powerKw!.toStringAsFixed(1);
      if (e.temperatureCelsius != null) {
        _temperatureCtrl.text = e.temperatureCelsius!.toStringAsFixed(0);
      }
      if (e.stationName != null) _stationCtrl.text = e.stationName!;
      if (e.startSocPercent != null) {
        _socStartCtrl.text = e.startSocPercent!.toStringAsFixed(0);
      }
      if (e.endSocPercent != null) {
        _socEndCtrl.text = e.endSocPercent!.toStringAsFixed(0);
      }
      _date = e.date;
      _chargerType = e.chargerType;
      _chargerStandard = e.chargerStandard;
      _useTariff = false;
    }

    // Авто-расчёт стоимости при вводе тарифа
    _tariffCtrl.addListener(_recalcCostFromTariff);
    _kwhCtrl.addListener(_recalcCostFromTariff);
  }

  void _recalcCostFromTariff() {
    if (!_useTariff) return;
    final tariff = double.tryParse(_tariffCtrl.text.replaceAll(',', '.'));
    final kwh = double.tryParse(_kwhCtrl.text.replaceAll(',', '.'));
    if (tariff != null && kwh != null && tariff > 0 && kwh > 0) {
      _totalCostCtrl.text = (tariff * kwh).toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _odometerCtrl.dispose();
    _evOdometerCtrl.dispose();
    _kwhCtrl.dispose();
    _tariffCtrl.dispose();
    _totalCostCtrl.dispose();
    _powerCtrl.dispose();
    _temperatureCtrl.dispose();
    _stationCtrl.dispose();
    _socStartCtrl.dispose();
    _socEndCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────── UI ──

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'edit_charging_title'.tr : 'new_charging_title'.tr,
        ),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'delete'.tr,
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Дата ──
            _SectionHeader(label: 'date_label'.tr, icon: Icons.calendar_today),
            const SizedBox(height: 8),
            _DatePickerRow(
              date: _date,
              onChanged: (d) => setState(() => _date = d),
            ),
            const SizedBox(height: 20),

            // ── Одометры ──
            _SectionHeader(
                label: 'odometer_label'.tr, icon: Icons.speed_outlined),
            const SizedBox(height: 8),
            _buildOdometerField(),
            const SizedBox(height: 12),
            _buildEvOdometerField(cs),

            const SizedBox(height: 20),

            // ── Энергия и стоимость ──
            _SectionHeader(
                label: 'kwh_added'.tr, icon: Icons.electric_bolt_outlined),
            const SizedBox(height: 8),
            _buildKwhField(),
            const SizedBox(height: 12),
            _buildTariffRow(cs),
            const SizedBox(height: 12),
            _buildTotalCostField(),

            const SizedBox(height: 20),

            // ── SOC ──
            _SectionHeader(
                label: 'soc_start'.tr.split(',').first,
                icon: Icons.battery_charging_full_outlined),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildSocStartField()),
                const SizedBox(width: 12),
                Expanded(child: _buildSocEndField()),
              ],
            ),

            const SizedBox(height: 20),

            // ── Тип и стандарт зарядки ──
            _SectionHeader(
                label: 'charger_type_label'.tr,
                icon: Icons.electrical_services_outlined),
            const SizedBox(height: 8),
            _buildChargerTypeToggle(cs),
            const SizedBox(height: 12),
            _buildChargerStandardDropdown(theme),

            const SizedBox(height: 20),

            // ── Дополнительно ──
            _SectionHeader(
                label: 'charger_power_kw'.tr, icon: Icons.settings_outlined),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildPowerField()),
                const SizedBox(width: 12),
                Expanded(child: _buildTemperatureField()),
              ],
            ),
            const SizedBox(height: 12),
            _buildStationField(),

            const SizedBox(height: 32),

            // ── Кнопка сохранения ──
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isSaving ? 'saving'.tr : 'save_entry'.tr,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────── Field Builders ──

  Widget _buildOdometerField() {
    return TextFormField(
      controller: _odometerCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: 'odometer_label'.tr,
        suffixText: 'odometer_suffix'.tr,
        hintText: '100000',
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'odometer_required'.tr;
        final val = double.tryParse(v);
        if (val == null || val < 0) return 'odometer_invalid'.tr;
        return null;
      },
    );
  }

  Widget _buildEvOdometerField(ColorScheme cs) {
    return TextFormField(
      controller: _evOdometerCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: 'ev_odometer_label'.tr,
        hintText: 'ev_odometer_hint'.tr,
        suffixText: 'ev_odometer_suffix'.tr,
        prefixIcon: Icon(Icons.electric_car_outlined, color: cs.primary),
        helperText: 'ev_odometer_hint'.tr,
      ),
      // EV-одометр необязателен
      validator: (v) {
        if (v == null || v.trim().isEmpty) return null;
        final val = double.tryParse(v);
        if (val == null || val < 0) return 'odometer_invalid'.tr;
        return null;
      },
    );
  }

  Widget _buildKwhField() {
    return TextFormField(
      controller: _kwhCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      decoration: InputDecoration(
        labelText: 'kwh_added'.tr,
        hintText: 'kwh_added_hint'.tr,
        suffixText: 'кВт·ч',
        prefixIcon: const Icon(Icons.bolt_outlined),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'kwh_added_required'.tr;
        final val = double.tryParse(v.replaceAll(',', '.'));
        if (val == null || val <= 0) return 'kwh_added_invalid'.tr;
        return null;
      },
    );
  }

  Widget _buildTariffRow(ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _tariffCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: 'tariff_per_kwh'.tr,
              hintText: 'tariff_hint'.tr,
              prefixIcon: Icon(Icons.price_change_outlined, color: cs.tertiary),
            ),
            onChanged: (_) {
              if (!_useTariff) {
                setState(() => _useTariff = true);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: () {
            setState(() => _useTariff = !_useTariff);
            if (_useTariff) _recalcCostFromTariff();
          },
          icon: Icon(
            _useTariff ? Icons.calculate_outlined : Icons.edit_note_outlined,
          ),
          tooltip: _useTariff ? 'Ввести сумму вручную' : 'Автовычисление',
        ),
      ],
    );
  }

  Widget _buildTotalCostField() {
    return TextFormField(
      controller: _totalCostCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      readOnly: _useTariff && _tariffCtrl.text.isNotEmpty,
      decoration: InputDecoration(
        labelText: 'total_price_label'.tr,
        suffixText: _currency,
        prefixIcon: Icon(
          Icons.payments_outlined,
          color: _useTariff ? Colors.grey : null,
        ),
        helperText: _useTariff ? 'Авто-расчёт из тарифа' : null,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return null; // Необязательно
        final val = double.tryParse(v.replaceAll(',', '.'));
        if (val == null || val < 0) return 'price_invalid'.tr;
        return null;
      },
    );
  }

  Widget _buildSocStartField() {
    return TextFormField(
      controller: _socStartCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: 'soc_start'.tr,
        suffixText: 'soc_percent'.tr,
        hintText: '15',
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return null;
        final val = int.tryParse(v);
        if (val == null || val < 0 || val > 100) return 'soc_invalid'.tr;
        return null;
      },
    );
  }

  Widget _buildSocEndField() {
    return TextFormField(
      controller: _socEndCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: 'soc_end'.tr,
        suffixText: 'soc_percent'.tr,
        hintText: '80',
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return null;
        final val = int.tryParse(v);
        if (val == null || val < 0 || val > 100) return 'soc_invalid'.tr;

        // Кросс-валидация: endSoc > startSoc
        final startVal = int.tryParse(_socStartCtrl.text);
        if (startVal != null && val <= startVal) {
          return 'soc_end_less_than_start'.tr;
        }
        return null;
      },
    );
  }

  Widget _buildChargerTypeToggle(ColorScheme cs) {
    return SegmentedButton<ChargerType>(
      segments: [
        ButtonSegment(
          value: ChargerType.acSlow,
          label: Text('charger_type_ac'.tr),
          icon: const Icon(Icons.power_outlined),
        ),
        ButtonSegment(
          value: ChargerType.dcFast,
          label: Text('charger_type_dc'.tr),
          icon: const Icon(Icons.flash_on_outlined),
        ),
      ],
      selected: {_chargerType},
      onSelectionChanged: (s) {
        setState(() {
          _chargerType = s.first;
          // Сбрасываем стандарт при смене типа на дефолтный для данного типа
          if (_chargerType == ChargerType.acSlow &&
              (_chargerStandard == ChargerStandard.ccs2)) {
            _chargerStandard = ChargerStandard.type2;
          } else if (_chargerType == ChargerType.dcFast &&
              _chargerStandard == ChargerStandard.homeSocket) {
            _chargerStandard = ChargerStandard.ccs2;
          }
        });
      },
    );
  }

  Widget _buildChargerStandardDropdown(ThemeData theme) {
    // Фильтруем стандарты по типу зарядки
    final acStandards = [
      ChargerStandard.homeSocket,
      ChargerStandard.type2,
      ChargerStandard.gbtAc,
    ];
    final dcStandards = [
      ChargerStandard.ccs2,
      ChargerStandard.gbtDc,
      ChargerStandard.type2, // Некоторые DC-зарядки Type 2
    ];
    final standards =
        _chargerType == ChargerType.acSlow ? acStandards : dcStandards;

    // Убеждаемся что текущий выбор допустим
    if (!standards.contains(_chargerStandard)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _chargerStandard = standards.first);
      });
    }

    return DropdownButtonFormField<ChargerStandard>(
      initialValue: standards.contains(_chargerStandard)
          ? _chargerStandard
          : standards.first,
      decoration: InputDecoration(
        labelText: 'charger_standard_label'.tr,
        prefixIcon: const Icon(Icons.cable_outlined),
      ),
      items: standards
          .map((s) => DropdownMenuItem(
                value: s,
                child: Text(_standardLabel(s)),
              ))
          .toList(),
      onChanged: (s) {
        if (s != null) setState(() => _chargerStandard = s);
      },
    );
  }

  Widget _buildPowerField() {
    return TextFormField(
      controller: _powerCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      decoration: InputDecoration(
        labelText: 'charger_power_kw'.tr,
        hintText: 'charger_power_hint'.tr,
        suffixText: 'кВт',
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return null;
        final val = double.tryParse(v.replaceAll(',', '.'));
        if (val == null || val <= 0) return 'volume_invalid'.tr;
        return null;
      },
    );
  }

  Widget _buildTemperatureField() {
    return TextFormField(
      controller: _temperatureCtrl,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: false, signed: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?[0-9]*')),
      ],
      decoration: InputDecoration(
        labelText: 'temperature_celsius'.tr,
        hintText: 'temperature_hint'.tr,
        suffixText: '°C',
        prefixIcon: const Icon(Icons.thermostat_outlined),
      ),
    );
  }

  Widget _buildStationField() {
    return TextFormField(
      controller: _stationCtrl,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: 'station_name_label'.tr,
        hintText: 'Например: EVGO, Tesla SC, дом',
        prefixIcon: const Icon(Icons.ev_station_outlined),
      ),
    );
  }

  // ─────────────────────────── Helpers ──

  String _standardLabel(ChargerStandard s) {
    switch (s) {
      case ChargerStandard.homeSocket:
        return 'standard_home'.tr;
      case ChargerStandard.type2:
        return 'standard_type2'.tr;
      case ChargerStandard.ccs2:
        return 'standard_ccs2'.tr;
      case ChargerStandard.gbtAc:
        return 'standard_gbt_ac'.tr;
      case ChargerStandard.gbtDc:
        return 'standard_gbt_dc'.tr;
    }
  }

  // ─────────────────────────── Actions ──

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final vehicle = _vehicleCtrl.selectedVehicle.value;
    if (vehicle == null || vehicle.id == null) {
      Get.snackbar('no_vehicle'.tr, 'select_vehicle_hint'.tr);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final odometer = double.parse(_odometerCtrl.text.replaceAll(',', '.'));
      final evOdo = _evOdometerCtrl.text.isNotEmpty
          ? double.tryParse(_evOdometerCtrl.text.replaceAll(',', '.'))
          : null;
      final kwh = double.parse(_kwhCtrl.text.replaceAll(',', '.'));

      // Определяем итоговую стоимость
      double totalCost = 0.0;
      final rawCost = _totalCostCtrl.text.replaceAll(',', '.');
      if (rawCost.isNotEmpty) {
        totalCost = double.tryParse(rawCost) ?? 0.0;
      }

      final startSoc = _socStartCtrl.text.isNotEmpty
          ? double.tryParse(_socStartCtrl.text)
          : null;
      final endSoc = _socEndCtrl.text.isNotEmpty
          ? double.tryParse(_socEndCtrl.text)
          : null;
      final powerKw = _powerCtrl.text.isNotEmpty
          ? double.tryParse(_powerCtrl.text.replaceAll(',', '.'))
          : null;
      final tempC = _temperatureCtrl.text.isNotEmpty
          ? double.tryParse(_temperatureCtrl.text)
          : null;
      final stationName =
          _stationCtrl.text.trim().isNotEmpty ? _stationCtrl.text.trim() : null;

      final entry = ChargingEntry(
        id: widget.editEntry?.id,
        vehicleId: vehicle.id!,
        date: _date,
        odometer: odometer,
        evOdometer: evOdo,
        kwhAdded: kwh,
        startSocPercent: startSoc,
        endSocPercent: endSoc,
        totalCost: totalCost,
        chargerType: _chargerType,
        chargerStandard: _chargerStandard,
        powerKw: powerKw,
        temperatureCelsius: tempC,
        stationName: stationName,
      );

      if (_isEditing) {
        await _chargingCtrl.updateEntry(entry);
        Get.back();
        Get.snackbar(
          'charging_session_updated'.tr,
          '${kwh.toStringAsFixed(1)} кВт·ч',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        await _chargingCtrl.addEntry(entry);
        Get.back();
        Get.snackbar(
          'charging_session_added'.tr,
          '${kwh.toStringAsFixed(1)} кВт·ч',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar('Ошибка', e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _confirmDelete() {
    Get.dialog(
      AlertDialog(
        title: Text('delete'.tr),
        content: Text('delete_confirm'.tr),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text('cancel'.tr),
          ),
          FilledButton(
            onPressed: () async {
              Get.back();
              await _chargingCtrl.deleteEntry(widget.editEntry!.id!);
              Get.back();
              Get.snackbar(
                'charging_session_deleted'.tr,
                '',
                snackPosition: SnackPosition.BOTTOM,
              );
            },
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Вспомогательные виджеты ──

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: cs.primary),
        ),
      ],
    );
  }
}

class _DatePickerRow extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  const _DatePickerRow({required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final formatted =
        DateFormat('d MMM yyyy', Get.locale?.languageCode ?? 'ru').format(date);
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.calendar_month_outlined),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        child: Text(formatted),
      ),
    );
  }
}

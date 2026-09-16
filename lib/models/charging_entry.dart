/// Перечисление типа зарядного устройства.
///
/// [acSlow]  — AC медленная зарядка (бортовой зарядник).
/// [dcFast]  — DC быстрая зарядка (внешний преобразователь).
enum ChargerType {
  acSlow,
  dcFast;

  /// Безопасная сериализация в строку для SQLite.
  String toDbString() => name;

  /// Восстановление из строки. Возвращает [acSlow] при неизвестном значении.
  static ChargerType fromDbString(String? s) {
    switch (s) {
      case 'dcFast':
        return ChargerType.dcFast;
      default:
        return ChargerType.acSlow;
    }
  }
}

/// Перечисление стандарта/разъёма зарядки.
///
/// [homeSocket]  — обычная бытовая розетка (Type F / Schuko).
/// [type2]       — IEC 62196 Type 2 (европейский AC стандарт).
/// [ccs2]        — Combined Charging System 2 (DC Европа).
/// [gbtAc]       — GB/T AC (китайский стандарт, переменный ток).
/// [gbtDc]       — GB/T DC (китайский стандарт, постоянный ток; BYD, Chery и др.).
enum ChargerStandard {
  homeSocket,
  type2,
  ccs2,
  gbtAc,
  gbtDc;

  /// Безопасная сериализация в строку для SQLite.
  String toDbString() => name;

  /// Восстановление из строки. Возвращает [homeSocket] при неизвестном значении.
  static ChargerStandard fromDbString(String? s) {
    switch (s) {
      case 'type2':
        return ChargerStandard.type2;
      case 'ccs2':
        return ChargerStandard.ccs2;
      case 'gbtAc':
        return ChargerStandard.gbtAc;
      case 'gbtDc':
        return ChargerStandard.gbtDc;
      default:
        return ChargerStandard.homeSocket;
    }
  }
}

// ─────────────────────────────────────────── Charging Session ──

/// Запись о сессии зарядки электромобиля или PHEV.
///
/// Поддерживает как обычные EV (только электро), так и PHEV/HEV-гибриды
/// с раздельной телеметрией пробега (например, BYD DM-i, Chazor).
///
/// Умные геттеры:
///   * [costPerKwh]           — фактическая стоимость 1 кВт·ч сессии.
///   * [deltaEnergyStored]    — фактически запасённая энергия по SOC-дельте.
///   * [efficiencyRatio]      — КПД передачи сети (0…200 %); > 100 % или < 50 % — аномалия.
///   * [isEfficiencyAnomalous]— флаг аномального КПД.
class ChargingEntry {
  /// Первичный ключ SQLite. null для несохранённых записей.
  final int? id;

  /// Внешний ключ на [Vehicle.id].
  final int vehicleId;

  /// Дата и время начала/окончания сессии зарядки.
  final DateTime date;

  /// Показания **общего** одометра автомобиля на момент зарядки, км.
  /// Используется в Unified Timeline для расчёта combined cost/km.
  final double odometer;

  /// Показания **EV-одометра** (счётчик чистого электрического пробега).
  /// Доступен на некоторых PHEV (BYD DM-i: «EV里程»).
  /// null если автомобиль не предоставляет раздельную телеметрию.
  final double? evOdometer;

  /// Количество кВт·ч, поданных из сети в автомобиль за сессию.
  /// Это «энергия от розетки» (grid energy), а не «запасённая энергия».
  final double kwhAdded;

  /// Уровень заряда АКБ **до** начала зарядки, % (0–100).
  /// null если данные не были записаны.
  final double? startSocPercent;

  /// Уровень заряда АКБ **после** окончания зарядки, % (0–100).
  /// null если данные не были записаны.
  final double? endSocPercent;

  /// Суммарная стоимость сессии в текущей валюте.
  final double totalCost;

  /// Тип зарядного устройства: AC медленная или DC быстрая.
  final ChargerType chargerType;

  /// Стандарт разъёма/протокола зарядки.
  final ChargerStandard chargerStandard;

  /// Максимальная мощность зарядки, кВт (из паспорта зарядной точки или EVSE).
  /// null если не зафиксирована.
  final double? powerKw;

  /// Температура окружающей среды во время зарядки, °C.
  /// Используется для поправки на температурные потери АКБ.
  /// null если не зафиксирована.
  final double? temperatureCelsius;

  /// Название зарядной станции / место зарядки (необязательно).
  final String? stationName;

  const ChargingEntry({
    this.id,
    required this.vehicleId,
    required this.date,
    required this.odometer,
    this.evOdometer,
    required this.kwhAdded,
    this.startSocPercent,
    this.endSocPercent,
    required this.totalCost,
    this.chargerType = ChargerType.acSlow,
    this.chargerStandard = ChargerStandard.homeSocket,
    this.powerKw,
    this.temperatureCelsius,
    this.stationName,
  });

  // ─────────────────────────────────────────── Smart Getters ──

  /// Фактическая стоимость 1 кВт·ч данной сессии.
  ///
  /// Возвращает 0.0 если [kwhAdded] равно нулю (защита от деления на ноль).
  double get costPerKwh {
    if (kwhAdded <= 0) return 0.0;
    return totalCost / kwhAdded;
  }

  /// Фактически запасённая в АКБ энергия, рассчитанная по дельте SOC
  /// и известной полезной ёмкости батареи.
  ///
  /// Требует: [startSocPercent], [endSocPercent] и [capacityKwh] > 0.
  /// Возвращает null если данные недоступны.
  double? deltaEnergyStored(double? capacityKwh) {
    if (capacityKwh == null || capacityKwh <= 0) return null;
    if (startSocPercent == null || endSocPercent == null) return null;
    final delta = endSocPercent! - startSocPercent!;
    if (delta <= 0) return null; // Сессия не увеличила заряд — нет смысла
    return capacityKwh * delta / 100.0;
  }

  /// Коэффициент полезного действия передачи энергии из сети в АКБ, %.
  ///
  /// Формула: `(ΔE_stored / kWhAdded) × 100`
  ///
  /// Типичные значения: 85–95 % для AC, 90–97 % для DC.
  /// Значения < 50 % или > 100 % считаются аномальными.
  ///
  /// Возвращает null если данных SOC или ёмкости недостаточно,
  /// или [kwhAdded] равно нулю.
  double? efficiencyRatio(double? capacityKwh) {
    if (kwhAdded <= 0) return null;
    final stored = deltaEnergyStored(capacityKwh);
    if (stored == null) return null;
    return (stored / kwhAdded) * 100.0;
  }

  /// Флаг аномального КПД зарядки.
  ///
  /// true если КПД < 50 % (возможная ошибка данных/неисправность)
  /// или > 100 % (физически невозможно — ошибка данных).
  bool isEfficiencyAnomalous(double? capacityKwh) {
    final ratio = efficiencyRatio(capacityKwh);
    if (ratio == null) return false;
    return ratio < 50.0 || ratio > 100.0;
  }

  /// Длительность зарядки, рассчитанная через мощность.
  ///
  /// `hours = kwhAdded / powerKw`
  ///
  /// Возвращает null если [powerKw] не задан или равен нулю.
  double? get estimatedDurationHours {
    if (powerKw == null || powerKw! <= 0) return null;
    return kwhAdded / powerKw!;
  }

  // ──────────────────────────────────────────── Serialization ──

  Map<String, dynamic> toMap() => {
        'id': id,
        'vehicle_id': vehicleId,
        'date': date.toIso8601String(),
        'odometer': odometer,
        'ev_odometer': evOdometer,
        'kwh_added': kwhAdded,
        'start_soc_percent': startSocPercent,
        'end_soc_percent': endSocPercent,
        'total_cost': totalCost,
        'charger_type': chargerType.toDbString(),
        'charger_standard': chargerStandard.toDbString(),
        'power_kw': powerKw,
        'temperature_celsius': temperatureCelsius,
        'station_name': stationName,
      };

  factory ChargingEntry.fromMap(Map<String, dynamic> map) => ChargingEntry(
        id: map['id'] as int?,
        vehicleId: map['vehicle_id'] as int,
        date: DateTime.parse(map['date'] as String),
        odometer: (map['odometer'] as num).toDouble(),
        evOdometer: (map['ev_odometer'] as num?)?.toDouble(),
        kwhAdded: (map['kwh_added'] as num).toDouble(),
        startSocPercent: (map['start_soc_percent'] as num?)?.toDouble(),
        endSocPercent: (map['end_soc_percent'] as num?)?.toDouble(),
        totalCost: (map['total_cost'] as num).toDouble(),
        chargerType: ChargerType.fromDbString(map['charger_type'] as String?),
        chargerStandard:
            ChargerStandard.fromDbString(map['charger_standard'] as String?),
        powerKw: (map['power_kw'] as num?)?.toDouble(),
        temperatureCelsius: (map['temperature_celsius'] as num?)?.toDouble(),
        stationName: map['station_name'] as String?,
      );

  ChargingEntry copyWith({
    int? id,
    int? vehicleId,
    DateTime? date,
    double? odometer,
    double? evOdometer,
    bool clearEvOdometer = false,
    double? kwhAdded,
    double? startSocPercent,
    bool clearStartSoc = false,
    double? endSocPercent,
    bool clearEndSoc = false,
    double? totalCost,
    ChargerType? chargerType,
    ChargerStandard? chargerStandard,
    double? powerKw,
    bool clearPowerKw = false,
    double? temperatureCelsius,
    bool clearTemperature = false,
    String? stationName,
    bool clearStationName = false,
  }) =>
      ChargingEntry(
        id: id ?? this.id,
        vehicleId: vehicleId ?? this.vehicleId,
        date: date ?? this.date,
        odometer: odometer ?? this.odometer,
        evOdometer:
            clearEvOdometer ? null : (evOdometer ?? this.evOdometer),
        kwhAdded: kwhAdded ?? this.kwhAdded,
        startSocPercent:
            clearStartSoc ? null : (startSocPercent ?? this.startSocPercent),
        endSocPercent:
            clearEndSoc ? null : (endSocPercent ?? this.endSocPercent),
        totalCost: totalCost ?? this.totalCost,
        chargerType: chargerType ?? this.chargerType,
        chargerStandard: chargerStandard ?? this.chargerStandard,
        powerKw: clearPowerKw ? null : (powerKw ?? this.powerKw),
        temperatureCelsius: clearTemperature
            ? null
            : (temperatureCelsius ?? this.temperatureCelsius),
        stationName:
            clearStationName ? null : (stationName ?? this.stationName),
      );

  @override
  String toString() =>
      'ChargingEntry(id=$id, vehicleId=$vehicleId, date=$date, '
      'kwh=$kwhAdded, cost=$totalCost)';
}

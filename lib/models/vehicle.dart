/// Модель автомобиля.
///
/// [bodyType]            — тип кузова: sedan | hatchback | suv | crossover | truck | van | moto | other
/// [engineType]          — тип двигателя: gas | diesel | hybrid | electric | hydrogen
/// [hybridType]          — подтип гибрида (только если engineType == 'hybrid'):
///                         PHEV | HEV | MHEV | BEV_REX | FCEV
/// [evGoal]              — целевой расход кВт·ч/100 км (для электро/гибридов)
/// [fuelGoal]            — целевой расход л/100 км (nullable = не задан)
/// [reminderDays]        — уведомлять, если последняя запись старше N дней
/// [licensePlate]        — государственный номер (необязательно)
/// [engineVolume]        — объём двигателя в литрах (необязательно)
/// [horsePower]          — лошадиные силы (необязательно)
/// [year]                — год выпуска (необязательно)
/// [batteryCapacityKwh]  — полная ёмкость тяговой АКБ, кВт·ч (EV/PHEV; необязательно)
/// [usableCapacityKwh]   — полезная (доступная) ёмкость АКБ, кВт·ч (необязательно)
class Vehicle {
  final int? id;
  final String name;
  final String model;

  /// Тип кузова (визуальный). Не зависит от типа двигателя.
  final String bodyType;

  /// Тип силовой установки.
  final String engineType;

  /// Подтип гибрида. null для не-гибридов.
  final String? hybridType;

  /// Подтип топлива (марка): '92', '95', '98', '100', 'dt', 'lpg', 'cng', 'other'.
  final String? fuelSubtype;

  /// Целевой расход топлива л/100 км (null = не задан).
  final double? fuelGoal;

  /// Целевой расход электроэнергии кВт·ч/100 км (null = не задан).
  final double? evGoal;

  final int? reminderDays;

  /// Государственный номер автомобиля (необязательно).
  final String? licensePlate;

  /// Объём двигателя в литрах (необязательно).
  final double? engineVolume;

  /// Мощность двигателя в лошадиных силах (необязательно).
  final int? horsePower;

  /// Год выпуска автомобиля (необязательно).
  final int? year;

  /// Полная ёмкость тяговой АКБ в кВт·ч (только EV/PHEV/HEV).
  /// null для ДВС-автомобилей.
  final double? batteryCapacityKwh;

  /// Полезная (доступная пользователю) ёмкость АКБ в кВт·ч.
  /// Обычно 85–95 % от [batteryCapacityKwh].
  /// null если не задана или автомобиль без АКБ.
  final double? usableCapacityKwh;

  /// Объём топливного бака в литрах.
  /// null если не задан или для чистых электромобилей.
  final double? tankCapacity;

  const Vehicle({
    this.id,
    required this.name,
    required this.model,
    this.bodyType = 'sedan',
    this.engineType = 'gas',
    this.hybridType,
    this.fuelSubtype,
    this.fuelGoal,
    this.evGoal,
    this.reminderDays,
    this.licensePlate,
    this.engineVolume,
    this.horsePower,
    this.year,
    this.batteryCapacityKwh,
    this.usableCapacityKwh,
    this.tankCapacity,
  });

  // ─────────────────────────────────────────────────── Derived ──

  /// Минимальная и максимальная емкость бака (л).
  static const double minTankCapacity = 1.0;
  static const double maxTankCapacity = 2000.0;

  /// Минимальная и максимальная емкость АКБ (кВт·ч).
  static const double minBatteryCapacity = 1.0;
  static const double maxBatteryCapacity = 1000.0;

  /// Обязателен ли топливный бак для автомобиля:
  /// Бензин, Дизель, Гибрид (все типы), Газ (LPG/CNG).
  bool get requiresTank => isTankRequiredFor(
        engineType: engineType,
        fuelSubtype: fuelSubtype,
      );

  /// Обязателен ли тяговый аккумулятор для автомобиля:
  /// Электромобиль (EV) и Подключаемый гибрид (PHEV, BEV_REX).
  bool get requiresBattery => isBatteryRequiredFor(
        engineType: engineType,
        hybridType: hybridType,
      );

  /// Проверка обязательности бака по типу двигателя и марке топлива.
  static bool isTankRequiredFor({
    required String engineType,
    String? fuelSubtype,
  }) {
    return engineType == 'gas' ||
        engineType == 'diesel' ||
        engineType == 'hybrid' ||
        fuelSubtype == 'lpg' ||
        fuelSubtype == 'cng';
  }

  /// Проверка обязательности тяговой батареи по типу двигателя и гибрида.
  static bool isBatteryRequiredFor({
    required String engineType,
    String? hybridType,
  }) {
    return engineType == 'electric' ||
        (engineType == 'hybrid' &&
            (hybridType == 'PHEV' || hybridType == 'BEV_REX'));
  }

  /// Валидация установленных емкостей автомобиля.
  String? validateCapacities() {
    if (requiresTank) {
      if (tankCapacity == null || tankCapacity! <= 0) {
        return 'Объем топливного бака обязателен и должен быть больше 0';
      }
    }
    if (requiresBattery) {
      if ((batteryCapacityKwh == null || batteryCapacityKwh! <= 0) &&
          (usableCapacityKwh == null || usableCapacityKwh! <= 0)) {
        return 'Емкость аккумулятора обязательна и должна быть больше 0';
      }
    }
    return null;
  }

  /// Может ли этот автомобиль заряжаться от сети (PHEV, BEV_REX, electric).
  bool get canCharge =>
      engineType == 'electric' ||
      hybridType == 'PHEV' ||
      hybridType == 'BEV_REX' ||
      hybridType == 'FCEV';

  /// Нужна ли запись о заправке топливом (не только зарядка).
  bool get canRefuel =>
      engineType != 'electric' ||
      hybridType == 'BEV_REX' ||
      hybridType == 'FCEV';

  /// Является ли полностью электрическим (без ДВС).
  bool get isFullyElectric =>
      engineType == 'electric' &&
      hybridType != 'BEV_REX' &&
      hybridType != 'FCEV';

  /// Является ли подключаемым гибридом (PHEV).
  bool get isPhev => hybridType == 'PHEV';

  /// Является ли самозаряжающимся гибридом (не pluggable).
  bool get isSelfChargingHybrid =>
      engineType == 'hybrid' && (hybridType == 'HEV' || hybridType == 'MHEV');

  /// Имеет ли автомобиль заданную ёмкость АКБ для расчётов КПД зарядки.
  bool get hasBatteryData =>
      (batteryCapacityKwh != null && batteryCapacityKwh! > 0) ||
      (usableCapacityKwh != null && usableCapacityKwh! > 0);

  /// Имеет ли автомобиль заданный объём бака для расчётов и валидации.
  bool get hasTankData => tankCapacity != null && tankCapacity! > 0;

  /// Полезная ёмкость для расчётов: предпочитаем [usableCapacityKwh],
  /// иначе берём [batteryCapacityKwh]. null если данных нет.
  double? get effectiveCapacityKwh => usableCapacityKwh ?? batteryCapacityKwh;

  // Обратная совместимость: iconType → bodyType
  String get iconType => bodyType;

  // ──────────────────────────────────────────────── Serialization ──

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'model': model,
        'icon_type': bodyType,
        'engine_type': engineType,
        'hybrid_type': hybridType,
        'fuel_subtype': fuelSubtype,
        'fuel_goal': fuelGoal,
        'ev_goal': evGoal,
        'reminder_days': reminderDays,
        'license_plate': licensePlate,
        'engine_volume': engineVolume,
        'horse_power': horsePower,
        'year': year,
        'battery_capacity_kwh': batteryCapacityKwh,
        'usable_capacity_kwh': usableCapacityKwh,
        'tank_capacity': tankCapacity,
      };

  factory Vehicle.fromMap(Map<String, dynamic> map) => Vehicle(
        id: map['id'] as int?,
        name: map['name'] as String,
        model: map['model'] as String,
        bodyType: map['icon_type'] as String? ?? 'sedan',
        engineType: map['engine_type'] as String? ?? 'gas',
        hybridType: map['hybrid_type'] as String?,
        fuelSubtype: map['fuel_subtype'] as String?,
        fuelGoal: (map['fuel_goal'] as num?)?.toDouble(),
        evGoal: (map['ev_goal'] as num?)?.toDouble(),
        reminderDays: map['reminder_days'] as int?,
        licensePlate: map['license_plate'] as String?,
        engineVolume: (map['engine_volume'] as num?)?.toDouble(),
        horsePower: map['horse_power'] as int?,
        year: map['year'] as int?,
        batteryCapacityKwh: (map['battery_capacity_kwh'] as num?)?.toDouble(),
        usableCapacityKwh: (map['usable_capacity_kwh'] as num?)?.toDouble(),
        tankCapacity: (map['tank_capacity'] as num?)?.toDouble(),
      );

  Vehicle copyWith({
    int? id,
    String? name,
    String? model,
    String? bodyType,
    String? engineType,
    String? hybridType,
    bool clearHybridType = false,
    String? fuelSubtype,
    bool clearFuelSubtype = false,
    double? fuelGoal,
    bool clearFuelGoal = false,
    double? evGoal,
    bool clearEvGoal = false,
    int? reminderDays,
    bool clearReminderDays = false,
    String? licensePlate,
    bool clearLicensePlate = false,
    double? engineVolume,
    bool clearEngineVolume = false,
    int? horsePower,
    bool clearHorsePower = false,
    int? year,
    bool clearYear = false,
    double? batteryCapacityKwh,
    bool clearBatteryCapacityKwh = false,
    double? usableCapacityKwh,
    bool clearUsableCapacityKwh = false,
    double? tankCapacity,
    bool clearTankCapacity = false,
  }) =>
      Vehicle(
        id: id ?? this.id,
        name: name ?? this.name,
        model: model ?? this.model,
        bodyType: bodyType ?? this.bodyType,
        engineType: engineType ?? this.engineType,
        hybridType: clearHybridType ? null : (hybridType ?? this.hybridType),
        fuelSubtype:
            clearFuelSubtype ? null : (fuelSubtype ?? this.fuelSubtype),
        fuelGoal: clearFuelGoal ? null : (fuelGoal ?? this.fuelGoal),
        evGoal: clearEvGoal ? null : (evGoal ?? this.evGoal),
        reminderDays:
            clearReminderDays ? null : (reminderDays ?? this.reminderDays),
        licensePlate:
            clearLicensePlate ? null : (licensePlate ?? this.licensePlate),
        engineVolume:
            clearEngineVolume ? null : (engineVolume ?? this.engineVolume),
        horsePower: clearHorsePower ? null : (horsePower ?? this.horsePower),
        year: clearYear ? null : (year ?? this.year),
        batteryCapacityKwh: clearBatteryCapacityKwh
            ? null
            : (batteryCapacityKwh ?? this.batteryCapacityKwh),
        usableCapacityKwh: clearUsableCapacityKwh
            ? null
            : (usableCapacityKwh ?? this.usableCapacityKwh),
        tankCapacity:
            clearTankCapacity ? null : (tankCapacity ?? this.tankCapacity),
      );

  @override
  String toString() => '$name ($model)';
}

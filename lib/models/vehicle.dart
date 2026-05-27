/// Модель автомобиля.
///
/// [bodyType]   — тип кузова: sedan | hatchback | suv | crossover | truck | van | moto | other
/// [engineType] — тип двигателя: gas | diesel | hybrid | electric | hydrogen
/// [hybridType] — подтип гибрида (только если engineType == 'hybrid'):
///                PHEV | HEV | MHEV | BEV_REX | FCEV
/// [evGoal]     — целевой расход кВт·ч/100 км (для электро/гибридов)
/// [fuelGoal]   — целевой расход л/100 км (nullable = не задан)
/// [reminderDays] — уведомлять, если последняя запись старше N дней
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

  /// Целевой расход топлива л/100 км (null = не задан).
  final double? fuelGoal;

  /// Целевой расход электроэнергии кВт·ч/100 км (null = не задан).
  final double? evGoal;

  final int? reminderDays;

  const Vehicle({
    this.id,
    required this.name,
    required this.model,
    this.bodyType = 'sedan',
    this.engineType = 'gas',
    this.hybridType,
    this.fuelGoal,
    this.evGoal,
    this.reminderDays,
  });

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

  /// Является ли самозаряжающимся гибридом (не pluggable).
  bool get isSelfChargingHybrid =>
      engineType == 'hybrid' &&
      (hybridType == 'HEV' || hybridType == 'MHEV');

  // Обратная совместимость: iconType → bodyType
  String get iconType => bodyType;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'model': model,
        'icon_type': bodyType,
        'engine_type': engineType,
        'hybrid_type': hybridType,
        'fuel_goal': fuelGoal,
        'ev_goal': evGoal,
        'reminder_days': reminderDays,
      };

  factory Vehicle.fromMap(Map<String, dynamic> map) => Vehicle(
        id: map['id'] as int?,
        name: map['name'] as String,
        model: map['model'] as String,
        bodyType: map['icon_type'] as String? ?? 'sedan',
        engineType: map['engine_type'] as String? ?? 'gas',
        hybridType: map['hybrid_type'] as String?,
        fuelGoal: map['fuel_goal'] as double?,
        evGoal: map['ev_goal'] as double?,
        reminderDays: map['reminder_days'] as int?,
      );

  Vehicle copyWith({
    int? id,
    String? name,
    String? model,
    String? bodyType,
    String? engineType,
    String? hybridType,
    bool clearHybridType = false,
    double? fuelGoal,
    bool clearFuelGoal = false,
    double? evGoal,
    bool clearEvGoal = false,
    int? reminderDays,
    bool clearReminderDays = false,
  }) =>
      Vehicle(
        id: id ?? this.id,
        name: name ?? this.name,
        model: model ?? this.model,
        bodyType: bodyType ?? this.bodyType,
        engineType: engineType ?? this.engineType,
        hybridType: clearHybridType ? null : (hybridType ?? this.hybridType),
        fuelGoal: clearFuelGoal ? null : (fuelGoal ?? this.fuelGoal),
        evGoal: clearEvGoal ? null : (evGoal ?? this.evGoal),
        reminderDays:
            clearReminderDays ? null : (reminderDays ?? this.reminderDays),
      );

  @override
  String toString() => '$name ($model)';
}

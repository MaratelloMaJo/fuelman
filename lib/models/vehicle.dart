/// Модель автомобиля.
///
/// [iconType] — тип иконки: sedan | suv | truck | moto | electric.
/// [fuelGoal]  — целевой расход в л/100 км (nullable = не задан).
/// [reminderDays] — уведомлять, если последняя запись старше N дней
///                  (nullable = уведомления отключены).
class Vehicle {
  final int? id;
  final String name;
  final String model;
  final String iconType;
  final double? fuelGoal;
  final int? reminderDays;

  const Vehicle({
    this.id,
    required this.name,
    required this.model,
    this.iconType = 'sedan',
    this.fuelGoal,
    this.reminderDays,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'model': model,
        'icon_type': iconType,
        'fuel_goal': fuelGoal,
        'reminder_days': reminderDays,
      };

  factory Vehicle.fromMap(Map<String, dynamic> map) => Vehicle(
        id: map['id'] as int?,
        name: map['name'] as String,
        model: map['model'] as String,
        iconType: map['icon_type'] as String? ?? 'sedan',
        fuelGoal: map['fuel_goal'] as double?,
        reminderDays: map['reminder_days'] as int?,
      );

  Vehicle copyWith({
    int? id,
    String? name,
    String? model,
    String? iconType,
    double? fuelGoal,
    bool clearFuelGoal = false,
    int? reminderDays,
    bool clearReminderDays = false,
  }) =>
      Vehicle(
        id: id ?? this.id,
        name: name ?? this.name,
        model: model ?? this.model,
        iconType: iconType ?? this.iconType,
        fuelGoal: clearFuelGoal ? null : (fuelGoal ?? this.fuelGoal),
        reminderDays:
            clearReminderDays ? null : (reminderDays ?? this.reminderDays),
      );

  @override
  String toString() => '$name ($model)';
}

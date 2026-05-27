/// Запись о заправке топлива.
///
/// [consumption] — расход в л/100 км, вычисленный алгоритмом Full-to-Full.
///   • null — если запись является дозаправкой (isFullTank == false)
///   • null — если это первая запись "полный бак" (нет предыдущей точки отсчёта)
///   • double — рассчитанное значение
class FuelEntry {
  final int? id;
  final int vehicleId;
  final DateTime date;

  /// Показания одометра на момент заправки (км).
  final double odometer;

  /// Объём заправленного топлива (литры).
  final double volume;

  /// true = залит полный бак; false = частичная дозаправка.
  final bool isFullTank;

  /// Цена за литр (необязательно, для расчёта стоимости).
  final double? pricePerLiter;

  /// Рассчитанный расход л/100 км (null для дозаправок и первой записи).
  final double? consumption;

  const FuelEntry({
    this.id,
    required this.vehicleId,
    required this.date,
    required this.odometer,
    required this.volume,
    this.isFullTank = true,
    this.pricePerLiter,
    this.consumption,
  });

  /// Полная стоимость заправки.
  double? get totalCost =>
      pricePerLiter != null ? volume * pricePerLiter! : null;

  /// Стоимость проезда 100 км.
  double? get costPer100km =>
      consumption != null && pricePerLiter != null
          ? consumption! * pricePerLiter!
          : null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'vehicle_id': vehicleId,
        'date': date.toIso8601String(),
        'odometer': odometer,
        'volume': volume,
        'is_full_tank': isFullTank ? 1 : 0,
        'price_per_liter': pricePerLiter,
        'consumption': consumption,
      };

  factory FuelEntry.fromMap(Map<String, dynamic> map) => FuelEntry(
        id: map['id'] as int?,
        vehicleId: map['vehicle_id'] as int,
        date: DateTime.parse(map['date'] as String),
        odometer: (map['odometer'] as num).toDouble(),
        volume: (map['volume'] as num).toDouble(),
        isFullTank: (map['is_full_tank'] as int) == 1,
        pricePerLiter: (map['price_per_liter'] as num?)?.toDouble(),
        consumption: (map['consumption'] as num?)?.toDouble(),
      );

  /// Создаёт копию с изменёнными полями.
  /// Используй [clearConsumption] = true чтобы явно обнулить расход.
  FuelEntry copyWith({
    int? id,
    int? vehicleId,
    DateTime? date,
    double? odometer,
    double? volume,
    bool? isFullTank,
    double? pricePerLiter,
    bool clearPricePerLiter = false,
    double? consumption,
    bool clearConsumption = false,
  }) =>
      FuelEntry(
        id: id ?? this.id,
        vehicleId: vehicleId ?? this.vehicleId,
        date: date ?? this.date,
        odometer: odometer ?? this.odometer,
        volume: volume ?? this.volume,
        isFullTank: isFullTank ?? this.isFullTank,
        pricePerLiter:
            clearPricePerLiter ? null : (pricePerLiter ?? this.pricePerLiter),
        consumption:
            clearConsumption ? null : (consumption ?? this.consumption),
      );
}

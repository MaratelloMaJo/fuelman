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

  /// Тип записи: 'fuel' (топливо) или 'charge' (зарядка).
  final String entryType;

  /// Единица измерения объёма: 'L', 'gal', 'kWh'.
  final String volumeUnit;

  /// Валюта записи: 'RUB', 'KZT', 'USD', 'EUR'.
  final String currency;

  const FuelEntry({
    this.id,
    required this.vehicleId,
    required this.date,
    required this.odometer,
    required this.volume,
    this.isFullTank = true,
    this.pricePerLiter,
    this.consumption,
    this.entryType = 'fuel',
    this.volumeUnit = 'L',
    this.currency = 'RUB',
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
        'entry_type': entryType,
        'volume_unit': volumeUnit,
        'currency': currency,
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
        entryType: map['entry_type'] as String? ?? 'fuel',
        volumeUnit: map['volume_unit'] as String? ?? 'L',
        currency: map['currency'] as String? ?? 'RUB',
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
    String? entryType,
    String? volumeUnit,
    String? currency,
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
        entryType: entryType ?? this.entryType,
        volumeUnit: volumeUnit ?? this.volumeUnit,
        currency: currency ?? this.currency,
      );
}

/// Запись о расходе на содержание автомобиля (не топливо).
///
/// [category] — тип расхода:
///   • 'service'    — ТО, ремонт
///   • 'oil_change' — замена масла
///   • 'wash'       — мойка
///   • 'tires'      — шиномонтаж / резина
///   • 'tax'        — налог, страховка, штраф
///   • 'parts'      — запчасти
///   • 'other'      — другое
class CarExpense {
  final int? id;
  final int vehicleId;
  final DateTime date;

  /// Категория расхода.
  final String category;

  /// Название/описание (например «Замена масла Shell 5W-40»).
  final String title;

  /// Сумма расхода.
  final double amount;

  /// Валюта: 'RUB', 'KZT', 'USD', 'EUR'.
  final String currency;

  /// Одометр на момент расхода (необязательно).
  final double? odometer;

  /// Широта GPS (необязательно).
  final double? latitude;

  /// Долгота GPS (необязательно).
  final double? longitude;

  /// Название места (сервиса, мойки и т.д.) (необязательно).
  final String? placeName;

  /// Заметки (необязательно).
  final String? notes;

  const CarExpense({
    this.id,
    required this.vehicleId,
    required this.date,
    required this.category,
    required this.title,
    required this.amount,
    this.currency = 'RUB',
    this.odometer,
    this.latitude,
    this.longitude,
    this.placeName,
    this.notes,
  });

  /// Есть ли GPS координаты.
  bool get hasLocation => latitude != null && longitude != null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'vehicle_id': vehicleId,
        'date': date.toIso8601String(),
        'category': category,
        'title': title,
        'amount': amount,
        'currency': currency,
        'odometer': odometer,
        'latitude': latitude,
        'longitude': longitude,
        'place_name': placeName,
        'notes': notes,
      };

  factory CarExpense.fromMap(Map<String, dynamic> map) => CarExpense(
        id: map['id'] as int?,
        vehicleId: map['vehicle_id'] as int,
        date: DateTime.parse(map['date'] as String),
        category: map['category'] as String,
        title: map['title'] as String,
        amount: (map['amount'] as num).toDouble(),
        currency: map['currency'] as String? ?? 'RUB',
        odometer: (map['odometer'] as num?)?.toDouble(),
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        placeName: map['place_name'] as String?,
        notes: map['notes'] as String?,
      );

  CarExpense copyWith({
    int? id,
    int? vehicleId,
    DateTime? date,
    String? category,
    String? title,
    double? amount,
    String? currency,
    double? odometer,
    bool clearOdometer = false,
    double? latitude,
    bool clearLatitude = false,
    double? longitude,
    bool clearLongitude = false,
    String? placeName,
    bool clearPlaceName = false,
    String? notes,
    bool clearNotes = false,
  }) =>
      CarExpense(
        id: id ?? this.id,
        vehicleId: vehicleId ?? this.vehicleId,
        date: date ?? this.date,
        category: category ?? this.category,
        title: title ?? this.title,
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        odometer: clearOdometer ? null : (odometer ?? this.odometer),
        latitude: clearLatitude ? null : (latitude ?? this.latitude),
        longitude: clearLongitude ? null : (longitude ?? this.longitude),
        placeName: clearPlaceName ? null : (placeName ?? this.placeName),
        notes: clearNotes ? null : (notes ?? this.notes),
      );
}

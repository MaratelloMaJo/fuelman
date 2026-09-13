import 'package:flutter_test/flutter_test.dart';
import 'package:fuelman/models/car_expense.dart';

void main() {
  group('CarExpense', () {
    final date = DateTime(2023, 10, 15, 12, 30);

    test('Constructor and basic getters work correctly', () {
      final expense = CarExpense(
        id: 1,
        vehicleId: 2,
        date: date,
        category: 'oil_change',
        title: 'Shell 5W-40',
        amount: 5000.0,
        currency: 'RUB',
        odometer: 100000.5,
        latitude: 55.751244,
        longitude: 37.618423,
        placeName: 'Service Station',
        notes: 'Included filter',
      );

      expect(expense.id, 1);
      expect(expense.vehicleId, 2);
      expect(expense.date, date);
      expect(expense.category, 'oil_change');
      expect(expense.title, 'Shell 5W-40');
      expect(expense.amount, 5000.0);
      expect(expense.currency, 'RUB');
      expect(expense.odometer, 100000.5);
      expect(expense.latitude, 55.751244);
      expect(expense.longitude, 37.618423);
      expect(expense.placeName, 'Service Station');
      expect(expense.notes, 'Included filter');
      expect(expense.hasLocation, isTrue);
    });

    test('hasLocation returns false if latitude or longitude is null', () {
      final expenseNoLat = CarExpense(
        vehicleId: 1,
        date: date,
        category: 'wash',
        title: 'Car Wash',
        amount: 500.0,
        longitude: 37.618423,
      );
      expect(expenseNoLat.hasLocation, isFalse);

      final expenseNoLon = CarExpense(
        vehicleId: 1,
        date: date,
        category: 'wash',
        title: 'Car Wash',
        amount: 500.0,
        latitude: 55.751244,
      );
      expect(expenseNoLon.hasLocation, isFalse);

      final expenseNoLoc = CarExpense(
        vehicleId: 1,
        date: date,
        category: 'wash',
        title: 'Car Wash',
        amount: 500.0,
      );
      expect(expenseNoLoc.hasLocation, isFalse);
    });

    test('toMap converts object correctly', () {
      final expense = CarExpense(
        id: 1,
        vehicleId: 2,
        date: date,
        category: 'service',
        title: 'Checkup',
        amount: 3000.0,
        currency: 'USD',
        odometer: 50000.0,
        latitude: 10.0,
        longitude: 20.0,
        placeName: 'My Mechanic',
        notes: 'All good',
      );

      final map = expense.toMap();

      expect(map['id'], 1);
      expect(map['vehicle_id'], 2);
      expect(map['date'], date.toIso8601String());
      expect(map['category'], 'service');
      expect(map['title'], 'Checkup');
      expect(map['amount'], 3000.0);
      expect(map['currency'], 'USD');
      expect(map['odometer'], 50000.0);
      expect(map['latitude'], 10.0);
      expect(map['longitude'], 20.0);
      expect(map['place_name'], 'My Mechanic');
      expect(map['notes'], 'All good');
    });

    test('fromMap creates object correctly from full map', () {
      final map = {
        'id': 1,
        'vehicle_id': 2,
        'date': date.toIso8601String(),
        'category': 'service',
        'title': 'Checkup',
        'amount': 3000.0,
        'currency': 'USD',
        'odometer': 50000.0,
        'latitude': 10.0,
        'longitude': 20.0,
        'place_name': 'My Mechanic',
        'notes': 'All good',
      };

      final expense = CarExpense.fromMap(map);

      expect(expense.id, 1);
      expect(expense.vehicleId, 2);
      expect(expense.date, date);
      expect(expense.category, 'service');
      expect(expense.title, 'Checkup');
      expect(expense.amount, 3000.0);
      expect(expense.currency, 'USD');
      expect(expense.odometer, 50000.0);
      expect(expense.latitude, 10.0);
      expect(expense.longitude, 20.0);
      expect(expense.placeName, 'My Mechanic');
      expect(expense.notes, 'All good');
    });

    test('fromMap handles missing optional fields and applies defaults', () {
      final map = {
        'id': null,
        'vehicle_id': 1,
        'date': date.toIso8601String(),
        'category': 'tires',
        'title': 'Winter tires',
        'amount': 20000.0,
        // currency missing, should default to RUB
        'odometer': null,
        'latitude': null,
        'longitude': null,
        'place_name': null,
        'notes': null,
      };

      final expense = CarExpense.fromMap(map);

      expect(expense.id, isNull);
      expect(expense.vehicleId, 1);
      expect(expense.date, date);
      expect(expense.category, 'tires');
      expect(expense.title, 'Winter tires');
      expect(expense.amount, 20000.0);
      expect(expense.currency, 'RUB'); // Default value
      expect(expense.odometer, isNull);
      expect(expense.latitude, isNull);
      expect(expense.longitude, isNull);
      expect(expense.placeName, isNull);
      expect(expense.notes, isNull);
    });

    test('copyWith updates fields correctly', () {
      final original = CarExpense(
        id: 1,
        vehicleId: 2,
        date: date,
        category: 'other',
        title: 'Original Title',
        amount: 100.0,
        currency: 'EUR',
        odometer: 1000.0,
        latitude: 1.0,
        longitude: 2.0,
        placeName: 'Place A',
        notes: 'Notes A',
      );

      final newDate = DateTime(2024, 1, 1);
      final updated = original.copyWith(
        id: 2,
        vehicleId: 3,
        date: newDate,
        category: 'parts',
        title: 'New Title',
        amount: 200.0,
        currency: 'USD',
        odometer: 2000.0,
        latitude: 3.0,
        longitude: 4.0,
        placeName: 'Place B',
        notes: 'Notes B',
      );

      expect(updated.id, 2);
      expect(updated.vehicleId, 3);
      expect(updated.date, newDate);
      expect(updated.category, 'parts');
      expect(updated.title, 'New Title');
      expect(updated.amount, 200.0);
      expect(updated.currency, 'USD');
      expect(updated.odometer, 2000.0);
      expect(updated.latitude, 3.0);
      expect(updated.longitude, 4.0);
      expect(updated.placeName, 'Place B');
      expect(updated.notes, 'Notes B');
    });

    test('copyWith handles clear flags correctly', () {
      final original = CarExpense(
        vehicleId: 1,
        date: date,
        category: 'other',
        title: 'Thing',
        amount: 100.0,
        odometer: 1000.0,
        latitude: 1.0,
        longitude: 2.0,
        placeName: 'Place',
        notes: 'Note',
      );

      final cleared = original.copyWith(
        clearOdometer: true,
        clearLatitude: true,
        clearLongitude: true,
        clearPlaceName: true,
        clearNotes: true,
      );

      expect(cleared.odometer, isNull);
      expect(cleared.latitude, isNull);
      expect(cleared.longitude, isNull);
      expect(cleared.placeName, isNull);
      expect(cleared.notes, isNull);

      // Basic fields shouldn't be affected
      expect(cleared.vehicleId, 1);
      expect(cleared.amount, 100.0);
    });
  });
}

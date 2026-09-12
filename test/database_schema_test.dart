import 'package:flutter_test/flutter_test.dart';
import 'package:fuelman/database/fuel_database.dart';
import 'dart:io';

void main() {
  test('Ensure PRAGMA foreign_keys = ON is set and CASCADE rules exist in schema', () {
    // Read the database file as text since we can't spin up sqflite_ffi due to pubspec issues
    final file = File('lib/database/fuel_database.dart');
    final content = file.readAsStringSync();

    // Check PRAGMA
    expect(content, contains('PRAGMA foreign_keys = ON'));

    // Check fuel_entries
    expect(content, contains('FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE'));

    // Make sure we have 3 CASCADE declarations (fuel_entries, car_expenses, charging_entries)
    final cascadeCount = 'ON DELETE CASCADE'.allMatches(content).length;
    expect(cascadeCount, greaterThanOrEqualTo(3));
  });
}

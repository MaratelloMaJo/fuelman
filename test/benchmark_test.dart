import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import '../lib/database/fuel_database.dart';
import '../lib/models/fuel_entry.dart';
import '../lib/controllers/fuel_entry_controller.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('Benchmark recalculateConsumption', () async {
    // Open an in-memory database using FFI
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 8,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE fuel_entries(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              vehicle_id INTEGER NOT NULL,
              date TEXT NOT NULL,
              odometer REAL NOT NULL,
              volume REAL NOT NULL,
              is_full_tank INTEGER NOT NULL DEFAULT 1,
              consumption REAL,
              entry_type TEXT NOT NULL DEFAULT 'fuel',
              volume_unit TEXT NOT NULL DEFAULT 'L',
              currency TEXT NOT NULL DEFAULT 'USD',
              price_per_liter REAL,
              total_cost REAL,
              station_name TEXT,
              notes TEXT,
              latitude REAL,
              longitude REAL
            )
          ''');
        },
      ),
    );

    // Swap the internal database instance
    // Oh wait, FuelDatabase creates it via getDatabasesPath.
    // We can't easily inject the mock DB unless we modify FuelDatabase.
  });
}

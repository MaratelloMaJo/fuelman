import 'dart:math';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import '../lib/database/fuel_database.dart';
import '../lib/models/fuel_entry.dart';
import '../lib/controllers/fuel_entry_controller.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dbPath = p.join(Directory.current.path, 'test_db.db');
  if (File(dbPath).existsSync()) {
    File(dbPath).deleteSync();
  }

  // Use raw open database to create a mock db and setup tables manually because FuelDatabase's init
  // uses getDatabasesPath which might fail in some dart environments.
  final db = await databaseFactory.openDatabase(dbPath,
    options: OpenDatabaseOptions(
      version: 8,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE vehicles(
            id INTEGER PRIMARY KEY AUTOINCREMENT
          )
        ''');
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

  // insert directly
  print('Inserting 1000 entries...');
  final batch = db.batch();
  for (int i = 0; i < 1000; i++) {
    batch.insert('fuel_entries', {
      'vehicle_id': 1,
      'date': DateTime.now().toIso8601String(),
      'odometer': 1000.0 + (i * 500),
      'volume': 40.0,
      'is_full_tank': 1,
      'entry_type': 'fuel',
      'volume_unit': 'L',
      'currency': 'USD',
      'total_cost': 40.0 * 1.5,
    });
  }
  await batch.commit(noResult: true);

  // Need to read back as FuelEntry
  final rows = await db.query('fuel_entries');
  final all = rows.map(FuelEntry.fromMap).toList();

  final calculated = FuelEntryController.computeEntriesWithConsumption(all);
  final toUpdate = <FuelEntry>[];
  for (final entry in calculated) {
    if (entry.id != null) {
      final original = all.firstWhere((e) => e.id == entry.id);
      if (original.consumption != entry.consumption) {
        toUpdate.add(entry);
      }
    }
  }

  print('Running baseline (N+1 approach)');
  final stopwatchBaseline = Stopwatch()..start();
  for (final entry in toUpdate) {
    await db.update('fuel_entries', entry.toMap(), where: 'id = ?', whereArgs: [entry.id]);
  }
  stopwatchBaseline.stop();
  final baselineMs = stopwatchBaseline.elapsedMilliseconds;
  print('Baseline took: ${baselineMs}ms');

  // Reset to original consumptions (which are null in our inserted rows)
  await db.update('fuel_entries', {'consumption': null});

  print('Running optimized (Batch approach)');
  final stopwatchOptimized = Stopwatch()..start();
  if (toUpdate.isNotEmpty) {
    final batchUpdate = db.batch();
    for (final entry in toUpdate) {
      batchUpdate.update('fuel_entries', entry.toMap(), where: 'id = ?', whereArgs: [entry.id]);
    }
    await batchUpdate.commit(noResult: true);
  }
  stopwatchOptimized.stop();
  final optimizedMs = stopwatchOptimized.elapsedMilliseconds;
  print('Optimized took: ${optimizedMs}ms');

  print('Improvement: ${(baselineMs / (optimizedMs == 0 ? 1 : optimizedMs)).toStringAsFixed(2)}x faster');

  await db.close();
  if (File(dbPath).existsSync()) {
    File(dbPath).deleteSync();
  }
  exit(0);
}

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

  // Initialize DB. To access internal init, we need to mock or just use the instance but we can set the factory globally.
  final db = await FuelDatabase.instance.database;

  // Insert 1000 dummy entries
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
  await batch.commit();

  print('Testing _recalculateConsumption...');
  final all = await FuelDatabase.instance.getEntries(1);
  final calculated = FuelEntryController.computeEntriesWithConsumption(all);

  // N+1 approach (current)
  final stopwatch = Stopwatch()..start();
  for (final entry in calculated) {
    if (entry.id != null) {
      final original = all.firstWhere((e) => e.id == entry.id);
      if (original.consumption != entry.consumption) {
        await FuelDatabase.instance.updateEntry(entry);
      }
    }
  }
  stopwatch.stop();
  print('N+1 approach took: ${stopwatch.elapsedMilliseconds}ms');

  // Let's close and clean up
  await db.close();
  if (File(dbPath).existsSync()) {
    File(dbPath).deleteSync();
  }
  exit(0);
}

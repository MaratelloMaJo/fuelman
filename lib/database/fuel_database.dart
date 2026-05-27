import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../models/vehicle.dart';
import '../models/fuel_entry.dart';

/// Singleton-обёртка над SQLite базой данных FuelMan.
///
/// Содержит CRUD-методы для [Vehicle] и [FuelEntry],
/// а также агрегированные запросы статистики.
class FuelDatabase {
  FuelDatabase._();
  static final FuelDatabase instance = FuelDatabase._();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'fuelman.db');

    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        // Включаем поддержку внешних ключей (CASCADE DELETE).
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE vehicles (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        name          TEXT    NOT NULL,
        model         TEXT    NOT NULL,
        icon_type     TEXT    NOT NULL DEFAULT 'sedan',
        fuel_goal     REAL,
        reminder_days INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE fuel_entries (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id     INTEGER NOT NULL,
        date           TEXT    NOT NULL,
        odometer       REAL    NOT NULL,
        volume         REAL    NOT NULL,
        is_full_tank   INTEGER NOT NULL DEFAULT 1,
        price_per_liter REAL,
        consumption    REAL,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE
      )
    ''');
  }

  // ─────────────────────────────────────────────── Vehicles ──

  Future<List<Vehicle>> getVehicles() async {
    final db = await database;
    final rows = await db.query('vehicles', orderBy: 'name ASC');
    return rows.map(Vehicle.fromMap).toList();
  }

  Future<Vehicle> insertVehicle(Vehicle vehicle) async {
    final db = await database;
    final map = Map<String, dynamic>.from(vehicle.toMap())..remove('id');
    final id = await db.insert('vehicles', map);
    return vehicle.copyWith(id: id);
  }

  Future<void> updateVehicle(Vehicle vehicle) async {
    final db = await database;
    await db.update(
      'vehicles',
      vehicle.toMap(),
      where: 'id = ?',
      whereArgs: [vehicle.id],
    );
  }

  Future<void> deleteVehicle(int id) async {
    final db = await database;
    await db.delete('vehicles', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────────── Fuel Entries ──

  /// Возвращает все записи для автомобиля, отсортированные по дате ASC
  /// (нужно для корректного алгоритма Full-to-Full).
  Future<List<FuelEntry>> getEntries(int vehicleId) async {
    final db = await database;
    final rows = await db.query(
      'fuel_entries',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'date ASC',
    );
    return rows.map(FuelEntry.fromMap).toList();
  }

  Future<FuelEntry> insertEntry(FuelEntry entry) async {
    final db = await database;
    final map = Map<String, dynamic>.from(entry.toMap())..remove('id');
    final id = await db.insert('fuel_entries', map);
    return entry.copyWith(id: id);
  }

  Future<void> updateEntry(FuelEntry entry) async {
    final db = await database;
    await db.update(
      'fuel_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> deleteEntry(int id) async {
    final db = await database;
    await db.delete('fuel_entries', where: 'id = ?', whereArgs: [id]);
  }

  // ──────────────────────────────────────────────── Stats ────

  /// Агрегированная статистика расхода и стоимости для автомобиля.
  ///
  /// Учитываются только записи с рассчитанным расходом (isFullTank + Full-to-Full).
  Future<Map<String, double?>> getStats(int vehicleId) async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT
        MIN(consumption)                               AS min_consumption,
        MAX(consumption)                               AS max_consumption,
        AVG(consumption)                               AS avg_consumption,
        SUM(volume)                                    AS total_volume,
        SUM(volume * COALESCE(price_per_liter, 0))     AS total_cost,
        COUNT(*)                                       AS total_entries,
        COUNT(CASE WHEN consumption IS NOT NULL THEN 1 END) AS calc_entries
      FROM fuel_entries
      WHERE vehicle_id = ?
    ''', [vehicleId]);

    if (result.isEmpty) return {};
    final row = result.first;
    return {
      'min_consumption': (row['min_consumption'] as num?)?.toDouble(),
      'max_consumption': (row['max_consumption'] as num?)?.toDouble(),
      'avg_consumption': (row['avg_consumption'] as num?)?.toDouble(),
      'total_volume': (row['total_volume'] as num?)?.toDouble(),
      'total_cost': (row['total_cost'] as num?)?.toDouble(),
      'total_entries': (row['total_entries'] as num?)?.toDouble(),
      'calc_entries': (row['calc_entries'] as num?)?.toDouble(),
    };
  }

  /// Статистика расхода по месяцам (для графика на экране статистики).
  Future<List<Map<String, dynamic>>> getMonthlyStats(int vehicleId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        strftime('%Y-%m', date)               AS month,
        AVG(consumption)                      AS avg_consumption,
        SUM(volume)                           AS total_volume,
        SUM(volume * COALESCE(price_per_liter, 0)) AS total_cost
      FROM fuel_entries
      WHERE vehicle_id = ? AND consumption IS NOT NULL
      GROUP BY strftime('%Y-%m', date)
      ORDER BY month ASC
    ''', [vehicleId]);
  }

  /// Дата последней записи для автомобиля (для проверки напоминаний).
  Future<DateTime?> getLastEntryDate(int vehicleId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(date) as last_date FROM fuel_entries WHERE vehicle_id = ?',
      [vehicleId],
    );
    final raw = result.first['last_date'] as String?;
    return raw != null ? DateTime.parse(raw) : null;
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}

import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import '../models/vehicle.dart';
import '../models/fuel_entry.dart';
import '../models/car_expense.dart';

/// Singleton-обёртка над SQLite базой данных FuelMan.
///
/// Содержит CRUD-методы для [Vehicle], [FuelEntry] и [CarExpense],
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
      version: 6,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE vehicles (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        name          TEXT    NOT NULL,
        model         TEXT    NOT NULL,
        icon_type     TEXT    NOT NULL DEFAULT 'sedan',
        engine_type   TEXT    NOT NULL DEFAULT 'gas',
        hybrid_type   TEXT,
        fuel_subtype  TEXT,
        fuel_goal     REAL,
        ev_goal       REAL,
        reminder_days INTEGER,
        license_plate TEXT,
        engine_volume REAL,
        horse_power   INTEGER,
        year          INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE fuel_entries (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id      INTEGER NOT NULL,
        date            TEXT    NOT NULL,
        odometer        REAL    NOT NULL,
        volume          REAL    NOT NULL,
        is_full_tank    INTEGER NOT NULL DEFAULT 1,
        price_per_liter REAL,
        total_cost      REAL,
        consumption     REAL,
        entry_type      TEXT    NOT NULL DEFAULT 'fuel',
        volume_unit     TEXT    NOT NULL DEFAULT 'L',
        currency        TEXT    NOT NULL DEFAULT 'RUB',
        latitude        REAL,
        longitude       REAL,
        station_name    TEXT,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE car_expenses (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        vehicle_id INTEGER NOT NULL,
        date       TEXT    NOT NULL,
        category   TEXT    NOT NULL,
        title      TEXT    NOT NULL,
        amount     REAL    NOT NULL,
        currency   TEXT    NOT NULL DEFAULT 'RUB',
        odometer   REAL,
        latitude   REAL,
        longitude  REAL,
        place_name TEXT,
        notes      TEXT,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE vehicles ADD COLUMN engine_type TEXT NOT NULL DEFAULT 'gas'");
      await db.execute("ALTER TABLE fuel_entries ADD COLUMN entry_type TEXT NOT NULL DEFAULT 'fuel'");
      await db.execute("ALTER TABLE fuel_entries ADD COLUMN volume_unit TEXT NOT NULL DEFAULT 'L'");
      await db.execute("ALTER TABLE fuel_entries ADD COLUMN currency TEXT NOT NULL DEFAULT 'RUB'");
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE vehicles ADD COLUMN hybrid_type TEXT');
      await db.execute('ALTER TABLE vehicles ADD COLUMN ev_goal REAL');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE fuel_entries ADD COLUMN total_cost REAL');
    }
    if (oldVersion < 5) {
      // Новые поля автомобиля
      await db.execute('ALTER TABLE vehicles ADD COLUMN license_plate TEXT');
      await db.execute('ALTER TABLE vehicles ADD COLUMN engine_volume REAL');
      await db.execute('ALTER TABLE vehicles ADD COLUMN horse_power INTEGER');
      await db.execute('ALTER TABLE vehicles ADD COLUMN year INTEGER');

      // GPS + название станции для заправок/зарядок
      await db.execute('ALTER TABLE fuel_entries ADD COLUMN latitude REAL');
      await db.execute('ALTER TABLE fuel_entries ADD COLUMN longitude REAL');
      await db.execute('ALTER TABLE fuel_entries ADD COLUMN station_name TEXT');

      // Новая таблица расходов на уход
      await db.execute('''
        CREATE TABLE IF NOT EXISTS car_expenses (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          vehicle_id INTEGER NOT NULL,
          date       TEXT    NOT NULL,
          category   TEXT    NOT NULL,
          title      TEXT    NOT NULL,
          amount     REAL    NOT NULL,
          currency   TEXT    NOT NULL DEFAULT 'RUB',
          odometer   REAL,
          latitude   REAL,
          longitude  REAL,
          place_name TEXT,
          notes      TEXT,
          FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE vehicles ADD COLUMN fuel_subtype TEXT');
    }
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

  /// Возвращает все записи для автомобиля, отсортированные по дате ASC.
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

  Future<int> getAllEntriesCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM fuel_entries');
    return Sqflite.firstIntValue(result) ?? 0;
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

  // ──────────────────────────────────────────── Car Expenses ──

  Future<List<CarExpense>> getExpenses(int vehicleId) async {
    final db = await database;
    final rows = await db.query(
      'car_expenses',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'date DESC',
    );
    return rows.map(CarExpense.fromMap).toList();
  }

  Future<CarExpense> insertExpense(CarExpense expense) async {
    final db = await database;
    final map = Map<String, dynamic>.from(expense.toMap())..remove('id');
    final id = await db.insert('car_expenses', map);
    return expense.copyWith(id: id);
  }

  Future<void> updateExpense(CarExpense expense) async {
    final db = await database;
    await db.update(
      'car_expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<void> deleteExpense(int id) async {
    final db = await database;
    await db.delete('car_expenses', where: 'id = ?', whereArgs: [id]);
  }

  /// Статистика расходов на уход по категориям.
  Future<Map<String, double>> getExpenseStatsByCategory(int vehicleId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT category, SUM(amount) as total
      FROM car_expenses
      WHERE vehicle_id = ?
      GROUP BY category
    ''', [vehicleId]);

    final Map<String, double> stats = {};
    for (final row in result) {
      stats[row['category'] as String] = (row['total'] as num).toDouble();
    }
    return stats;
  }

  /// Суммарные расходы на уход по месяцам.
  Future<List<Map<String, dynamic>>> getMonthlyExpenses(int vehicleId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        strftime('%Y-%m', date) AS month,
        SUM(amount)             AS total_amount,
        COUNT(*)                AS total_count
      FROM car_expenses
      WHERE vehicle_id = ?
      GROUP BY strftime('%Y-%m', date)
      ORDER BY month ASC
    ''', [vehicleId]);
  }

  // ──────────────────────────────────────────────── Stats ────

  /// Агрегированная статистика расхода и стоимости для автомобиля.
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

  /// Статистика расхода по месяцам.
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

  /// Дата последней записи для автомобиля.
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

  // ─────────────────────────────────────────────── Backup ──

  Future<void> exportBackup() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'fuelman.db');
    final file = File(path);
    if (await file.exists()) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/octet-stream')],
          subject: 'FuelMan_Backup.db',
        ),
      );
    }
  }

  Future<bool> importBackup() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final backupFile = File(result.files.single.path!);

        await close();

        final dbPath = await getDatabasesPath();
        final path = p.join(dbPath, 'fuelman.db');

        await backupFile.copy(path);

        _db = await _initDb();
        return true;
      }
    } catch (e) {
      // ignore
    }
    return false;
  }
}

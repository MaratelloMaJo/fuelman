import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import '../models/vehicle.dart';
import '../models/fuel_entry.dart';
import '../models/car_expense.dart';
import '../models/charging_entry.dart';

/// Singleton-обёртка над SQLite базой данных FuelMan.
///
/// История версий:
///   v1 — базовая схема vehicles + fuel_entries
///   v2 — engine_type, entry_type, volume_unit, currency
///   v3 — hybrid_type, ev_goal
///   v4 — total_cost в fuel_entries
///   v5 — license_plate, engine_volume, horse_power, year, GPS, car_expenses
///   v6 — fuel_subtype
///   v7 — battery_capacity_kwh, usable_capacity_kwh в vehicles; таблица charging_entries
///
/// Содержит CRUD-методы для [Vehicle], [FuelEntry], [CarExpense] и [ChargingEntry],
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
      version: 8,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ──────────────────────────────────────────────── Schema ──

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE vehicles (
        id                   INTEGER PRIMARY KEY AUTOINCREMENT,
        name                 TEXT    NOT NULL,
        model                TEXT    NOT NULL,
        icon_type            TEXT    NOT NULL DEFAULT 'sedan',
        engine_type          TEXT    NOT NULL DEFAULT 'gas',
        hybrid_type          TEXT,
        fuel_subtype         TEXT,
        fuel_goal            REAL,
        ev_goal              REAL,
        reminder_days        INTEGER,
        license_plate        TEXT,
        engine_volume        REAL,
        horse_power          INTEGER,
        year                 INTEGER,
        battery_capacity_kwh REAL,
        usable_capacity_kwh  REAL,
        tank_capacity        REAL
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

    await db.execute(_createChargingEntriesSQL);
  }

  /// SQL для создания таблицы charging_entries (используется и в onCreate, и в onUpgrade).
  static const String _createChargingEntriesSQL = '''
    CREATE TABLE IF NOT EXISTS charging_entries (
      id                  INTEGER PRIMARY KEY AUTOINCREMENT,
      vehicle_id          INTEGER NOT NULL,
      date                TEXT    NOT NULL,
      odometer            REAL    NOT NULL,
      ev_odometer         REAL,
      kwh_added           REAL    NOT NULL,
      start_soc_percent   REAL,
      end_soc_percent     REAL,
      total_cost          REAL    NOT NULL DEFAULT 0,
      charger_type        TEXT    NOT NULL DEFAULT 'acSlow',
      charger_standard    TEXT    NOT NULL DEFAULT 'homeSocket',
      power_kw            REAL,
      temperature_celsius REAL,
      station_name        TEXT,
      FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE
    )
  ''';

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          "ALTER TABLE vehicles ADD COLUMN engine_type TEXT NOT NULL DEFAULT 'gas'");
      await db.execute(
          "ALTER TABLE fuel_entries ADD COLUMN entry_type TEXT NOT NULL DEFAULT 'fuel'");
      await db.execute(
          "ALTER TABLE fuel_entries ADD COLUMN volume_unit TEXT NOT NULL DEFAULT 'L'");
      await db.execute(
          "ALTER TABLE fuel_entries ADD COLUMN currency TEXT NOT NULL DEFAULT 'RUB'");
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE vehicles ADD COLUMN hybrid_type TEXT');
      await db.execute('ALTER TABLE vehicles ADD COLUMN ev_goal REAL');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE fuel_entries ADD COLUMN total_cost REAL');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE vehicles ADD COLUMN license_plate TEXT');
      await db.execute('ALTER TABLE vehicles ADD COLUMN engine_volume REAL');
      await db.execute('ALTER TABLE vehicles ADD COLUMN horse_power INTEGER');
      await db.execute('ALTER TABLE vehicles ADD COLUMN year INTEGER');

      await db.execute('ALTER TABLE fuel_entries ADD COLUMN latitude REAL');
      await db.execute('ALTER TABLE fuel_entries ADD COLUMN longitude REAL');
      await db.execute('ALTER TABLE fuel_entries ADD COLUMN station_name TEXT');

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
    if (oldVersion < 7) {
      // Новые поля ёмкости АКБ для EV/PHEV (nullable → backwards-compatible)
      await db.execute(
          'ALTER TABLE vehicles ADD COLUMN battery_capacity_kwh REAL');
      await db.execute(
          'ALTER TABLE vehicles ADD COLUMN usable_capacity_kwh REAL');

      // Новая таблица сессий зарядки
      await db.execute(_createChargingEntriesSQL);
    }
    if (oldVersion < 8) {
      await db.execute('ALTER TABLE vehicles ADD COLUMN tank_capacity REAL');
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

  Future<void> updateEntriesBatch(List<FuelEntry> entries) async {
    final db = await database;
    final batch = db.batch();
    for (final entry in entries) {
      batch.update(
        'fuel_entries',
        entry.toMap(),
        where: 'id = ?',
        whereArgs: [entry.id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteEntry(int id) async {
    final db = await database;
    await db.delete('fuel_entries', where: 'id = ?', whereArgs: [id]);
  }

  // ─────────────────────────────────────── Charging Entries ──

  /// Возвращает все сессии зарядки для автомобиля, отсортированные по дате ASC.
  Future<List<ChargingEntry>> getChargingEntriesByVehicleId(
      int vehicleId) async {
    final db = await database;
    final rows = await db.query(
      'charging_entries',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'date ASC',
    );
    return rows.map(ChargingEntry.fromMap).toList();
  }

  /// Сохраняет новую сессию зарядки. Возвращает запись с присвоенным [id].
  Future<ChargingEntry> insertChargingEntry(ChargingEntry entry) async {
    final db = await database;
    final map = Map<String, dynamic>.from(entry.toMap())..remove('id');
    final id = await db.insert('charging_entries', map);
    return entry.copyWith(id: id);
  }

  /// Обновляет существующую сессию зарядки.
  /// [entry.id] должен быть ненулевым.
  Future<void> updateChargingEntry(ChargingEntry entry) async {
    assert(entry.id != null, 'ChargingEntry.id must not be null for update');
    final db = await database;
    await db.update(
      'charging_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  /// Удаляет сессию зарядки по [id].
  Future<void> deleteChargingEntry(int id) async {
    final db = await database;
    await db.delete('charging_entries', where: 'id = ?', whereArgs: [id]);
  }

  /// Суммарная статистика зарядок для автомобиля.
  ///
  /// Возвращает: `total_kwh`, `total_cost`, `session_count`.
  Future<Map<String, double>> getChargingStats(int vehicleId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        COALESCE(SUM(kwh_added),   0) AS total_kwh,
        COALESCE(SUM(total_cost),  0) AS total_cost,
        COUNT(*)                       AS session_count
      FROM charging_entries
      WHERE vehicle_id = ?
    ''', [vehicleId]);

    if (result.isEmpty) {
      return {'total_kwh': 0.0, 'total_cost': 0.0, 'session_count': 0.0};
    }
    final row = result.first;
    return {
      'total_kwh': (row['total_kwh'] as num).toDouble(),
      'total_cost': (row['total_cost'] as num).toDouble(),
      'session_count': (row['session_count'] as num).toDouble(),
    };
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

  /// Дата последней записи (заправка или зарядка) для автомобиля.
  Future<DateTime?> getLastEntryDate(int vehicleId) async {
    final db = await database;

    // Проверяем оба источника и берём более позднюю дату
    final fuelResult = await db.rawQuery(
      'SELECT MAX(date) as last_date FROM fuel_entries WHERE vehicle_id = ?',
      [vehicleId],
    );
    final chargeResult = await db.rawQuery(
      'SELECT MAX(date) as last_date FROM charging_entries WHERE vehicle_id = ?',
      [vehicleId],
    );

    final fuelRaw = fuelResult.first['last_date'] as String?;
    final chargeRaw = chargeResult.first['last_date'] as String?;

    final fuelDate = fuelRaw != null ? DateTime.tryParse(fuelRaw) : null;
    final chargeDate = chargeRaw != null ? DateTime.tryParse(chargeRaw) : null;

    if (fuelDate == null && chargeDate == null) return null;
    if (fuelDate == null) return chargeDate;
    if (chargeDate == null) return fuelDate;
    return fuelDate.isAfter(chargeDate) ? fuelDate : chargeDate;
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

      if (result.isNotEmpty && result.first.path != null) {
        final backupFile = File(result.first.path!);

        await close();

        final dbPath = await getDatabasesPath();
        final path = p.join(dbPath, 'fuelman.db');

        await backupFile.copy(path);

        _db = await _initDb();
        return true;
      }
    } catch (_) {
      // ignore
    }
    return false;
  }
}

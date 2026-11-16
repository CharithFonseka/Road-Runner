// Road Runner — SQLite Database Helper
// Owner: Nadeesha
// SRS reference: Section 8.5

import 'package:sqflite/sqflite.dart';

/// Manages the SQLite database lifecycle, schema initialization, and connections.
class AppDatabase {
  static const String databaseName = 'road_runner.db';
  static const int databaseVersion = 6;

  // Table names
  static const String tableRuns = 'runs';
  static const String tableRunPoints = 'run_points';
  static const String tableRunPauses = 'run_pauses';
  static const String tablePlaceCache = 'place_cache';
  static const String tableRunBadges = 'run_badges';
  static const String tablePlannedRoutes = 'planned_routes';
  static const String tablePlannedRoutePoints = 'planned_route_points';

  // Runs table columns
  static const String colRunId = 'id';
  static const String colStartedAtUtcMs = 'started_at_utc_ms';
  static const String colEndedAtUtcMs = 'ended_at_utc_ms';
  static const String colMovingMs = 'moving_ms';
  static const String colDistanceM = 'distance_m';
  static const String colAvgPaceSecPerKm = 'avg_pace_sec_per_km';
  static const String colMaxSpeedMps = 'max_speed_mps';
  static const String colStatus = 'status';
  static const String colRunName = 'run_name';
  static const String colPlaceName = 'place_name';
  static const String colWeatherTempC = 'weather_temp_c';
  static const String colWeatherWindKmh = 'weather_wind_kmh';
  static const String colWeatherCode = 'weather_code';
  static const String colLocalStartDay = 'local_start_day';

  // Run points table columns
  static const String colPointRunId = 'run_id';
  static const String colPointSeq = 'seq';
  static const String colPointTUtcMs = 't_utc_ms';
  static const String colPointLat = 'lat';
  static const String colPointLon = 'lon';
  static const String colPointAccM = 'acc_m';
  static const String colPointSpeedMps = 'speed_mps';
  static const String colPointAltM = 'alt_m';
  static const String colPointAccepted = 'accepted';

  // Run pauses table columns
  static const String colPauseRunId = 'run_id';
  static const String colPauseStartMs = 'start_ms';
  static const String colPauseEndMs = 'end_ms';

  // Index name
  static const String idxRunPointsRunIdSeq = 'idx_run_points_run_id_seq';

  static final AppDatabase instance = AppDatabase._internal();

  Database? _database;

  AppDatabase._internal();

  /// Creates an [AppDatabase] with an optional injected database (useful for testing).
  AppDatabase({Database? database}) {
    _database = database;
  }

  /// Returns the singleton [Database] instance, opening it if necessary.
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await open();
    return _database!;
  }

  /// Opens the database at [path], or at the default databases directory.
  Future<Database> open({String? path}) async {
    final String databasesDirectory = await getDatabasesPath();
    final String dbPath =
        path ??
        (databasesDirectory.endsWith('/') || databasesDirectory.endsWith('\\')
            ? '$databasesDirectory$databaseName'
            : '$databasesDirectory/$databaseName');

    return await openDatabase(
      dbPath,
      version: databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Enforces SQLite foreign key constraints.
  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  /// Creates the database schema for a new installation.
  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableRuns (
        $colRunId TEXT PRIMARY KEY,
        $colStartedAtUtcMs INTEGER NOT NULL,
        $colEndedAtUtcMs INTEGER NOT NULL,
        $colMovingMs INTEGER NOT NULL,
        $colDistanceM REAL NOT NULL,
        $colAvgPaceSecPerKm REAL,
        $colMaxSpeedMps REAL,
        $colStatus TEXT NOT NULL,
        $colRunName TEXT,
        $colPlaceName TEXT,
        $colWeatherTempC REAL,
        $colWeatherWindKmh REAL,
        $colWeatherCode INTEGER,
        $colLocalStartDay TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE $tableRunPoints (
        $colPointRunId TEXT NOT NULL,
        $colPointSeq INTEGER NOT NULL,
        $colPointTUtcMs INTEGER NOT NULL,
        $colPointLat REAL NOT NULL,
        $colPointLon REAL NOT NULL,
        $colPointAccM REAL NOT NULL,
        $colPointSpeedMps REAL,
        $colPointAltM REAL,
        $colPointAccepted INTEGER NOT NULL,
        FOREIGN KEY ($colPointRunId) REFERENCES $tableRuns ($colRunId) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE INDEX $idxRunPointsRunIdSeq ON $tableRunPoints (
        $colPointRunId,
        $colPointSeq
      );
    ''');

    await db.execute('''
      CREATE TABLE $tableRunPauses (
        $colPauseRunId TEXT NOT NULL,
        $colPauseStartMs INTEGER NOT NULL,
        $colPauseEndMs INTEGER NOT NULL,
        FOREIGN KEY ($colPauseRunId) REFERENCES $tableRuns ($colRunId) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE $tablePlaceCache (
        lat_bucket INTEGER NOT NULL,
        lon_bucket INTEGER NOT NULL,
        place_name TEXT NOT NULL,
        PRIMARY KEY (lat_bucket, lon_bucket)
      );
    ''');

    await db.execute('''
      CREATE TABLE $tableRunBadges (
        run_id TEXT NOT NULL,
        badge_type TEXT NOT NULL,
        awarded_at_utc_ms INTEGER NOT NULL,
        PRIMARY KEY (run_id, badge_type),
        FOREIGN KEY (run_id) REFERENCES $tableRuns ($colRunId) ON DELETE CASCADE
      );
    ''');
    await _createPlannedRouteTables(db);
  }

  static Future<void> _createPlannedRouteTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tablePlannedRoutes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at_utc_ms INTEGER NOT NULL
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tablePlannedRoutePoints (
        route_id TEXT NOT NULL,
        seq INTEGER NOT NULL,
        lat REAL NOT NULL,
        lon REAL NOT NULL,
        PRIMARY KEY (route_id, seq),
        FOREIGN KEY (route_id) REFERENCES $tablePlannedRoutes (id) ON DELETE CASCADE
      );
    ''');
  }

  /// Handles schema migrations for future database versions.
  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableRunPauses (
          $colPauseRunId TEXT NOT NULL,
          $colPauseStartMs INTEGER NOT NULL,
          $colPauseEndMs INTEGER NOT NULL,
          FOREIGN KEY ($colPauseRunId) REFERENCES $tableRuns ($colRunId) ON DELETE CASCADE
        );
      ''');
    }

    if (oldVersion < 3) {
      for (final sql in [
        'ALTER TABLE $tableRuns ADD COLUMN $colRunName TEXT',
        'ALTER TABLE $tableRuns ADD COLUMN $colPlaceName TEXT',
        'ALTER TABLE $tableRuns ADD COLUMN $colWeatherTempC REAL',
        'ALTER TABLE $tableRuns ADD COLUMN $colWeatherWindKmh REAL',
        'ALTER TABLE $tableRuns ADD COLUMN $colWeatherCode INTEGER',
        'ALTER TABLE $tableRuns ADD COLUMN $colLocalStartDay TEXT',
      ]) {
        await db.execute(sql);
      }
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tablePlaceCache (
          lat_bucket INTEGER NOT NULL,
          lon_bucket INTEGER NOT NULL,
          place_name TEXT NOT NULL,
          PRIMARY KEY (lat_bucket, lon_bucket)
        );
      ''');
    }

    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableRunBadges (
          run_id TEXT NOT NULL,
          badge_type TEXT NOT NULL,
          awarded_at_utc_ms INTEGER NOT NULL,
          PRIMARY KEY (run_id, badge_type),
          FOREIGN KEY (run_id) REFERENCES $tableRuns ($colRunId) ON DELETE CASCADE
        );
      ''');
    }
    if (oldVersion < 6) {
      // Early route-planner builds used v4 with different run and place-cache
      // columns. Keep their saved runs and cached places when moving to the
      // combined schema from main.
      await _migrateEarlyRoutePreview(db);
      await _createPlannedRouteTables(db);
    }
  }

  static Future<void> _migrateEarlyRoutePreview(Database db) async {
    final runColumns = (await db.rawQuery('PRAGMA table_info($tableRuns)'))
        .map((row) => row['name'] as String)
        .toSet();
    if (runColumns.contains('name') && !runColumns.contains(colRunName)) {
      await db.execute('ALTER TABLE $tableRuns ADD COLUMN $colRunName TEXT');
      await db.execute('UPDATE $tableRuns SET $colRunName = name');
    }
    if (!runColumns.contains(colLocalStartDay)) {
      await db.execute(
        'ALTER TABLE $tableRuns ADD COLUMN $colLocalStartDay TEXT',
      );
    }

    final cacheColumns = (await db.rawQuery(
      'PRAGMA table_info($tablePlaceCache)',
    )).map((row) => row['name'] as String).toSet();
    if (!cacheColumns.contains('coordinate_key')) return;
    final legacyPlaces = await db.query(tablePlaceCache);
    await db.execute(
      'ALTER TABLE $tablePlaceCache RENAME TO place_cache_legacy',
    );
    await db.execute('''
      CREATE TABLE $tablePlaceCache (
        lat_bucket INTEGER NOT NULL,
        lon_bucket INTEGER NOT NULL,
        place_name TEXT NOT NULL,
        PRIMARY KEY (lat_bucket, lon_bucket)
      );
    ''');
    for (final row in legacyPlaces) {
      final coordinates = (row['coordinate_key'] as String).split(',');
      if (coordinates.length != 2) continue;
      final lat = double.tryParse(coordinates[0]);
      final lon = double.tryParse(coordinates[1]);
      if (lat == null || lon == null) continue;
      await db.insert(tablePlaceCache, {
        'lat_bucket': placeBucket(lat),
        'lon_bucket': placeBucket(lon),
        'place_name': row['place_name'],
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await db.execute('DROP TABLE place_cache_legacy');
  }

  /// Closes the underlying database connection.
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

/// Computes a discrete coordinate bucket grouping start coordinates within ~110m.
int placeBucket(double coordinate) => (coordinate * 1000).round();

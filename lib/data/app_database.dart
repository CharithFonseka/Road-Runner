// Road Runner — SQLite Database Helper
// Owner: Nadeesha
// SRS reference: Section 8.5

import 'package:sqflite/sqflite.dart';

/// Manages the SQLite database lifecycle, schema initialization, and connections.
class AppDatabase {
  static const String databaseName = 'road_runner.db';
  static const int databaseVersion = 1;

  // Table names
  static const String tableRuns = 'runs';
  static const String tableRunPoints = 'run_points';

  // Runs table columns
  static const String colRunId = 'id';
  static const String colStartedAtUtcMs = 'started_at_utc_ms';
  static const String colEndedAtUtcMs = 'ended_at_utc_ms';
  static const String colMovingMs = 'moving_ms';
  static const String colDistanceM = 'distance_m';
  static const String colAvgPaceSecPerKm = 'avg_pace_sec_per_km';
  static const String colMaxSpeedMps = 'max_speed_mps';
  static const String colStatus = 'status';

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
    final String dbPath = path ??
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

  /// Creates the initial database schema (version 1).
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
        $colStatus TEXT NOT NULL
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
  }

  /// Handles schema migrations for future database versions.
  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Schema migration logic will be added here when databaseVersion increments.
  }

  /// Closes the underlying database connection.
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

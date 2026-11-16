import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// Persists the user's weekly distance goal locally in SQLite.
abstract class GoalRepository {
  Future<double> getWeeklyGoalKm();
  Future<void> setWeeklyGoalKm(double goalKm);
}

class SqliteGoalRepository implements GoalRepository {
  SqliteGoalRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  static const String _tableName = 'user_goals';
  static const String _weeklyGoalId = 'weekly_distance';
  static const double defaultWeeklyGoalKm = 20.0;

  final AppDatabase _database;

  Future<Database> _ensureTable() async {
    final Database db = await _database.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id TEXT PRIMARY KEY,
        weekly_goal_km REAL NOT NULL,
        updated_at_utc_ms INTEGER NOT NULL
      );
    ''');
    return db;
  }

  @override
  Future<double> getWeeklyGoalKm() async {
    final Database db = await _ensureTable();
    final List<Map<String, Object?>> rows = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [_weeklyGoalId],
      limit: 1,
    );
    if (rows.isEmpty) return defaultWeeklyGoalKm;
    final double? val = (rows.first['weekly_goal_km'] as num?)?.toDouble();
    if (val == null || val <= 0) return defaultWeeklyGoalKm;
    return val;
  }

  @override
  Future<void> setWeeklyGoalKm(double goalKm) async {
    final double clamped = goalKm.clamp(1.0, 1000.0);
    final Database db = await _ensureTable();
    await db.insert(
      _tableName,
      {
        'id': _weeklyGoalId,
        'weekly_goal_km': clamped,
        'updated_at_utc_ms': DateTime.now().toUtc().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

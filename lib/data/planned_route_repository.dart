import 'package:road_runner/data/app_database.dart';
import 'package:road_runner/data/planned_route.dart';
import 'package:sqflite/sqflite.dart';

class PlannedRouteRepository {
  PlannedRouteRepository({AppDatabase? database})
    : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<void> save(PlannedRoute route) async {
    _validate(route);
    final db = await _database.database;
    await db.transaction((txn) async {
      // Replacing a route must also replace its previous points.
      await txn.delete(
        AppDatabase.tablePlannedRoutePoints,
        where: 'route_id = ?',
        whereArgs: [route.id],
      );
      await txn.insert(AppDatabase.tablePlannedRoutes, {
        'id': route.id,
        'name': route.name.trim(),
        'created_at_utc_ms': route.createdAtUtcMs,
        'activity': route.activity.name,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      final batch = txn.batch();
      for (var i = 0; i < route.points.length; i++) {
        batch.insert(AppDatabase.tablePlannedRoutePoints, {
          'route_id': route.id,
          'seq': i,
          'lat': route.points[i].lat,
          'lon': route.points[i].lon,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<PlannedRoute?> get(String id) async {
    final db = await _database.database;
    final routes = await db.query(
      AppDatabase.tablePlannedRoutes,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (routes.isEmpty) return null;
    final pointRows = await db.query(
      AppDatabase.tablePlannedRoutePoints,
      where: 'route_id = ?',
      whereArgs: [id],
      orderBy: 'seq ASC',
    );
    final row = routes.first;
    return PlannedRoute(
      id: row['id'] as String,
      name: row['name'] as String,
      createdAtUtcMs: (row['created_at_utc_ms'] as num).toInt(),
      activity: RouteActivityLabel.fromStorage(row['activity'] as String?),
      points: List.unmodifiable(
        pointRows.map(
          (point) => PlannedRoutePoint(
            lat: (point['lat'] as num).toDouble(),
            lon: (point['lon'] as num).toDouble(),
          ),
        ),
      ),
    );
  }

  Future<List<PlannedRoute>> list() async {
    final db = await _database.database;
    final rows = await db.query(
      AppDatabase.tablePlannedRoutes,
      columns: ['id'],
      orderBy: 'created_at_utc_ms DESC, id ASC',
    );
    final routes = <PlannedRoute>[];
    for (final row in rows) {
      final route = await get(row['id'] as String);
      if (route != null) routes.add(route);
    }
    return routes;
  }

  Future<void> delete(String id) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.delete(
        AppDatabase.tablePlannedRoutePoints,
        where: 'route_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        AppDatabase.tablePlannedRoutes,
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  void _validate(PlannedRoute route) {
    if (route.id.trim().isEmpty ||
        route.name.trim().isEmpty ||
        route.createdAtUtcMs <= 0 ||
        route.points.length < 2) {
      throw ArgumentError(
        'A planned route needs an ID, name, time and points.',
      );
    }
    final first = route.points.first;
    if (route.points.every(
      (point) => point.lat == first.lat && point.lon == first.lon,
    )) {
      throw ArgumentError('A planned route needs two distinct positions.');
    }
    for (final point in route.points) {
      if (!point.lat.isFinite ||
          !point.lon.isFinite ||
          point.lat.abs() > 90 ||
          point.lon.abs() > 180) {
        throw ArgumentError('Planned route contains invalid coordinates.');
      }
    }
  }
}

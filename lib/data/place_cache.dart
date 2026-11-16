// Road Runner — Persistent Place Cache
// Owner: Nadeesha
// SRS reference: Section 8.5

import 'package:road_runner/data/app_database.dart';
import 'package:road_runner/domain/stats/models.dart';
import 'package:sqflite/sqflite.dart';

class PlaceCache {
  const PlaceCache(this.database);

  final AppDatabase database;

  int _bucket(double coordinate) => placeBucket(coordinate);

  Future<String?> get(Point point) async {
    final db = await database.database;
    final rows = await db.query(
      'place_cache',
      columns: ['place_name'],
      where: 'lat_bucket = ? AND lon_bucket = ?',
      whereArgs: [_bucket(point.lat), _bucket(point.lon)],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['place_name'] as String?;
  }

  Future<void> put(Point point, String placeName) async {
    final db = await database.database;
    await db.insert('place_cache', {
      'lat_bucket': _bucket(point.lat),
      'lon_bucket': _bucket(point.lon),
      'place_name': placeName,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

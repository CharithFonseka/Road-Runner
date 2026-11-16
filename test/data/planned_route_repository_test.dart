import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/data/app_database.dart';
import 'package:road_runner/data/planned_route.dart';
import 'package:road_runner/data/planned_route_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('PlannedRouteRepository Tests', () {
    late Directory tempDir;
    late String dbPath;
    late AppDatabase appDatabase;
    late PlannedRouteRepository repository;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('road_runner_route_test_');
      dbPath = '${tempDir.path}/test_routes.db';
      appDatabase = AppDatabase();
      final db = await appDatabase.open(path: dbPath);
      appDatabase = AppDatabase(database: db);
      repository = PlannedRouteRepository(database: appDatabase);
    });

    tearDown(() async {
      await appDatabase.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('saving and reopening a route returns matching data', () async {
      const route = PlannedRoute(
        id: 'route-1',
        name: 'Morning Beach Loop',
        createdAtUtcMs: 1731600000000,
        points: [
          PlannedRoutePoint(lat: 6.9271, lon: 79.8612),
          PlannedRoutePoint(lat: 6.9280, lon: 79.8625),
        ],
      );

      await repository.save(route);
      final loaded = await repository.get('route-1');

      expect(loaded, isNotNull);
      expect(loaded!.id, equals('route-1'));
      expect(loaded.name, equals('Morning Beach Loop'));
      expect(loaded.createdAtUtcMs, equals(1731600000000));
      expect(loaded.points.length, equals(2));
      expect(loaded.points[0].lat, equals(6.9271));
      expect(loaded.points[0].lon, equals(79.8612));
      expect(loaded.points[1].lat, equals(6.9280));
      expect(loaded.points[1].lon, equals(79.8625));
    });

    test('reopening nonexistent route returns null', () async {
      final loaded = await repository.get('nonexistent');
      expect(loaded, isNull);
    });

    test('replacing an existing route updates name and points', () async {
      const initialRoute = PlannedRoute(
        id: 'route-replace',
        name: 'Initial Name',
        createdAtUtcMs: 1000,
        points: [
          PlannedRoutePoint(lat: 1.0, lon: 1.0),
          PlannedRoutePoint(lat: 2.0, lon: 2.0),
        ],
      );
      await repository.save(initialRoute);

      const updatedRoute = PlannedRoute(
        id: 'route-replace',
        name: 'Updated Name',
        createdAtUtcMs: 2000,
        points: [
          PlannedRoutePoint(lat: 3.0, lon: 3.0),
          PlannedRoutePoint(lat: 4.0, lon: 4.0),
          PlannedRoutePoint(lat: 5.0, lon: 5.0),
        ],
      );
      await repository.save(updatedRoute);

      final loaded = await repository.get('route-replace');
      expect(loaded, isNotNull);
      expect(loaded!.name, equals('Updated Name'));
      expect(loaded.createdAtUtcMs, equals(2000));
      expect(loaded.points.length, equals(3));
      expect(loaded.points[0].lat, equals(3.0));
      expect(loaded.points[1].lat, equals(4.0));
      expect(loaded.points[2].lat, equals(5.0));
    });

    test(
      'listing routes returns all routes in created_at_utc_ms DESC order',
      () async {
        const route1 = PlannedRoute(
          id: 'route-b',
          name: 'Route B',
          createdAtUtcMs: 1000,
          points: [
            PlannedRoutePoint(lat: 1.0, lon: 1.0),
            PlannedRoutePoint(lat: 2.0, lon: 2.0),
          ],
        );
        const route2 = PlannedRoute(
          id: 'route-a',
          name: 'Route A',
          createdAtUtcMs: 1000,
          points: [
            PlannedRoutePoint(lat: 1.0, lon: 1.0),
            PlannedRoutePoint(lat: 2.0, lon: 2.0),
          ],
        );
        const route3 = PlannedRoute(
          id: 'route-c',
          name: 'Route C',
          createdAtUtcMs: 2000,
          points: [
            PlannedRoutePoint(lat: 1.0, lon: 1.0),
            PlannedRoutePoint(lat: 2.0, lon: 2.0),
          ],
        );

        await repository.save(route1);
        await repository.save(route2);
        await repository.save(route3);

        final list = await repository.list();
        expect(list.length, equals(3));
        expect(list[0].id, equals('route-c'));
        expect(list[1].id, equals('route-a'));
        expect(list[2].id, equals('route-b'));
      },
    );

    test('deleting a route removes route and associated points', () async {
      const route = PlannedRoute(
        id: 'route-del',
        name: 'Delete Me',
        createdAtUtcMs: 1000,
        points: [
          PlannedRoutePoint(lat: 1.0, lon: 1.0),
          PlannedRoutePoint(lat: 2.0, lon: 2.0),
        ],
      );
      await repository.save(route);
      expect(await repository.get('route-del'), isNotNull);

      await repository.delete('route-del');
      expect(await repository.get('route-del'), isNull);

      final db = await appDatabase.database;
      final remainingPoints = await db.query(
        AppDatabase.tablePlannedRoutePoints,
        where: 'route_id = ?',
        whereArgs: ['route-del'],
      );
      expect(remainingPoints, isEmpty);
    });

    test('validation rejects invalid routes', () {
      expect(
        () => repository.save(
          const PlannedRoute(
            id: '',
            name: 'Name',
            createdAtUtcMs: 1000,
            points: [
              PlannedRoutePoint(lat: 1.0, lon: 1.0),
              PlannedRoutePoint(lat: 2.0, lon: 2.0),
            ],
          ),
        ),
        throwsArgumentError,
      );

      expect(
        () => repository.save(
          const PlannedRoute(
            id: 'r1',
            name: '',
            createdAtUtcMs: 1000,
            points: [
              PlannedRoutePoint(lat: 1.0, lon: 1.0),
              PlannedRoutePoint(lat: 2.0, lon: 2.0),
            ],
          ),
        ),
        throwsArgumentError,
      );

      expect(
        () => repository.save(
          const PlannedRoute(
            id: 'r1',
            name: 'Name',
            createdAtUtcMs: 0,
            points: [
              PlannedRoutePoint(lat: 1.0, lon: 1.0),
              PlannedRoutePoint(lat: 2.0, lon: 2.0),
            ],
          ),
        ),
        throwsArgumentError,
      );

      expect(
        () => repository.save(
          const PlannedRoute(
            id: 'r1',
            name: 'Name',
            createdAtUtcMs: 1000,
            points: [PlannedRoutePoint(lat: 1.0, lon: 1.0)],
          ),
        ),
        throwsArgumentError,
      );

      expect(
        () => repository.save(
          const PlannedRoute(
            id: 'r1',
            name: 'Name',
            createdAtUtcMs: 1000,
            points: [
              PlannedRoutePoint(lat: 1.0, lon: 1.0),
              PlannedRoutePoint(lat: 1.0, lon: 1.0),
            ],
          ),
        ),
        throwsArgumentError,
      );

      expect(
        () => repository.save(
          const PlannedRoute(
            id: 'r1',
            name: 'Name',
            createdAtUtcMs: 1000,
            points: [
              PlannedRoutePoint(lat: 95.0, lon: 1.0),
              PlannedRoutePoint(lat: 1.0, lon: 1.0),
            ],
          ),
        ),
        throwsArgumentError,
      );
    });

    test('version 3 to 6 migration preserves existing runs and creates route tables', () async {
      final migrationDbPath = '${tempDir.path}/migration_v3.db';

      // 1. Create a version 3 database with an existing run
      final v3Db = await openDatabase(
        migrationDbPath,
        version: 3,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE ${AppDatabase.tableRuns} (
              ${AppDatabase.colRunId} TEXT PRIMARY KEY,
              ${AppDatabase.colStartedAtUtcMs} INTEGER NOT NULL,
              ${AppDatabase.colEndedAtUtcMs} INTEGER NOT NULL,
              ${AppDatabase.colMovingMs} INTEGER NOT NULL,
              ${AppDatabase.colDistanceM} REAL NOT NULL,
              ${AppDatabase.colAvgPaceSecPerKm} REAL NOT NULL,
              ${AppDatabase.colMaxSpeedMps} REAL NOT NULL,
              ${AppDatabase.colStatus} TEXT NOT NULL,
              ${AppDatabase.colRunName} TEXT,
              ${AppDatabase.colPlaceName} TEXT,
              ${AppDatabase.colWeatherTempC} REAL,
              ${AppDatabase.colWeatherWindKmh} REAL,
              ${AppDatabase.colWeatherCode} INTEGER,
              ${AppDatabase.colLocalStartDay} TEXT
            );
          ''');
          await db.execute('''
            CREATE TABLE ${AppDatabase.tableRunPoints} (
              ${AppDatabase.colPointRunId} TEXT NOT NULL,
              ${AppDatabase.colPointSeq} INTEGER NOT NULL,
              ${AppDatabase.colPointTUtcMs} INTEGER NOT NULL,
              ${AppDatabase.colPointLat} REAL NOT NULL,
              ${AppDatabase.colPointLon} REAL NOT NULL,
              ${AppDatabase.colPointAccM} REAL NOT NULL,
              ${AppDatabase.colPointSpeedMps} REAL,
              ${AppDatabase.colPointAltM} REAL,
              ${AppDatabase.colPointAccepted} INTEGER NOT NULL,
              PRIMARY KEY (${AppDatabase.colPointRunId}, ${AppDatabase.colPointSeq})
            );
          ''');
        },
      );

      await v3Db.insert(AppDatabase.tableRuns, {
        AppDatabase.colRunId: 'v3-run-999',
        AppDatabase.colStartedAtUtcMs: 1730000000000,
        AppDatabase.colEndedAtUtcMs: 1730001000000,
        AppDatabase.colMovingMs: 1000000,
        AppDatabase.colDistanceM: 5000.0,
        AppDatabase.colAvgPaceSecPerKm: 300.0,
        AppDatabase.colMaxSpeedMps: 4.5,
        AppDatabase.colStatus: 'completed',
        AppDatabase.colRunName: 'Legacy Run',
      });
      await v3Db.close();

      // 2. Open via AppDatabase, which triggers _onUpgrade from 3 -> 6
      final upgradedAppDb = AppDatabase();
      final v6Db = await upgradedAppDb.open(path: migrationDbPath);

      // Verify existing run remains
      final runs = await v6Db.query(
        AppDatabase.tableRuns,
        where: '${AppDatabase.colRunId} = ?',
        whereArgs: ['v3-run-999'],
      );
      expect(runs.length, equals(1));
      expect(runs.first[AppDatabase.colRunName], equals('Legacy Run'));

      // Verify planned_routes table exists and works
      final upgradedRepo = PlannedRouteRepository(
        database: AppDatabase(database: v6Db),
      );
      const newRoute = PlannedRoute(
        id: 'new-v6-route',
        name: 'V6 Migration Route',
        createdAtUtcMs: 1731650000000,
        points: [
          PlannedRoutePoint(lat: 6.9, lon: 79.8),
          PlannedRoutePoint(lat: 7.0, lon: 79.9),
        ],
      );
      await upgradedRepo.save(newRoute);
      final loadedNewRoute = await upgradedRepo.get('new-v6-route');
      expect(loadedNewRoute, isNotNull);
      expect(loadedNewRoute!.name, equals('V6 Migration Route'));

      await v6Db.close();
    });

    test('early route preview migrates run names and cached places', () async {
      final previewPath = '${tempDir.path}/early_route_preview.db';
      final previewDb = await openDatabase(
        previewPath,
        version: 4,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE ${AppDatabase.tableRuns} (
              id TEXT PRIMARY KEY, started_at_utc_ms INTEGER NOT NULL,
              ended_at_utc_ms INTEGER NOT NULL, moving_ms INTEGER NOT NULL,
              distance_m REAL NOT NULL, status TEXT NOT NULL, name TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE ${AppDatabase.tablePlaceCache} (
              coordinate_key TEXT PRIMARY KEY, place_name TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE ${AppDatabase.tablePlannedRoutes} (
              id TEXT PRIMARY KEY, name TEXT NOT NULL,
              created_at_utc_ms INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE ${AppDatabase.tablePlannedRoutePoints} (
              route_id TEXT NOT NULL, seq INTEGER NOT NULL,
              lat REAL NOT NULL, lon REAL NOT NULL,
              PRIMARY KEY (route_id, seq)
            )
          ''');
        },
      );
      await previewDb.insert(AppDatabase.tableRuns, {
        'id': 'preview-run',
        'started_at_utc_ms': 1730000000000,
        'ended_at_utc_ms': 1730000001000,
        'moving_ms': 1000,
        'distance_m': 100.0,
        'status': 'saved',
        'name': 'Morning run in Colombo',
      });
      await previewDb.insert(AppDatabase.tablePlaceCache, {
        'coordinate_key': '6.927,79.861',
        'place_name': 'Colombo',
      });
      await previewDb.insert(AppDatabase.tablePlannedRoutes, {
        'id': 'saved-plan',
        'name': 'City loop',
        'created_at_utc_ms': 1730000000000,
      });
      await previewDb.insert(AppDatabase.tablePlannedRoutePoints, {
        'route_id': 'saved-plan',
        'seq': 0,
        'lat': 6.927,
        'lon': 79.861,
      });
      await previewDb.close();

      final upgraded = await AppDatabase().open(path: previewPath);
      final runs = await upgraded.query(AppDatabase.tableRuns);
      expect(runs.single[AppDatabase.colRunName], 'Morning run in Colombo');
      final places = await upgraded.query(AppDatabase.tablePlaceCache);
      expect(places.single['lat_bucket'], 6927);
      expect(places.single['lon_bucket'], 79861);
      expect(places.single['place_name'], 'Colombo');
      final plan = await upgraded.query(AppDatabase.tablePlannedRoutes);
      final points = await upgraded.query(AppDatabase.tablePlannedRoutePoints);
      expect(plan.single['name'], 'City loop');
      expect(points.single['lat'], 6.927);
      await upgraded.close();
    });
  });
}

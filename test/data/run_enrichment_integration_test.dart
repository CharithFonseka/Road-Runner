// Road Runner — Integration tests for RunEnrichmentService
// Owner: Nadeesha
// SRS reference: Section 8.5

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:road_runner/data/app_database.dart';
import 'package:road_runner/data/place_cache.dart';
import 'package:road_runner/data/run_enrichment_service.dart';
import 'package:road_runner/data/run_place_client.dart';
import 'package:road_runner/data/run_repository.dart';
import 'package:road_runner/data/run_weather_client.dart';
import 'package:sqflite/sqflite.dart';

// ─── Fake infrastructure (mirrors run_repository_test.dart) ──────────────────

class FakeDatabase extends Fake implements Database {
  final Map<String, List<Map<String, Object?>>> tables = {
    AppDatabase.tableRuns: [],
    AppDatabase.tableRunPoints: [],
    AppDatabase.tableRunPauses: [],
    AppDatabase.tablePlaceCache: [],
    AppDatabase.tableRunBadges: [],
  };

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async {
    final txn = FakeTransaction(this);
    return await action(txn);
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final rows = List<Map<String, Object?>>.from(tables[table] ?? []);
    var filtered = rows;

    if (where != null && whereArgs != null) {
      if (where.startsWith('id = ?')) {
        final id = whereArgs.first;
        filtered = filtered.where((r) => r['id'] == id).toList();
      } else if (where.startsWith('run_id = ?')) {
        final runId = whereArgs.first;
        filtered = filtered.where((r) => r['run_id'] == runId).toList();
      } else if (where.startsWith('lat_bucket = ? AND lon_bucket = ?')) {
        final lat = whereArgs[0];
        final lon = whereArgs[1];
        filtered = filtered
            .where((r) => r['lat_bucket'] == lat && r['lon_bucket'] == lon)
            .toList();
      }
    }

    if (orderBy != null) {
      if (orderBy.contains('started_at_utc_ms DESC')) {
        filtered.sort(
          (a, b) => ((b['started_at_utc_ms'] as num?) ?? 0).compareTo(
            (a['started_at_utc_ms'] as num?) ?? 0,
          ),
        );
      } else if (orderBy.contains('seq ASC')) {
        filtered.sort(
          (a, b) =>
              ((a['seq'] as num?) ?? 0).compareTo((b['seq'] as num?) ?? 0),
        );
      } else if (orderBy.contains('start_ms ASC')) {
        filtered.sort(
          (a, b) => ((a['start_ms'] as num?) ?? 0).compareTo(
            (b['start_ms'] as num?) ?? 0,
          ),
        );
      }
    }

    if (limit != null && filtered.length > limit) {
      filtered = filtered.take(limit).toList();
    }

    return filtered;
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final list = tables[table]!;

    if (conflictAlgorithm == ConflictAlgorithm.replace) {
      if (table == AppDatabase.tablePlaceCache) {
        list.removeWhere(
          (item) =>
              item['lat_bucket'] == values['lat_bucket'] &&
              item['lon_bucket'] == values['lon_bucket'],
        );
      } else if (table == AppDatabase.tableRunBadges) {
        list.removeWhere(
          (item) =>
              item['run_id'] == values['run_id'] &&
              item['badge_type'] == values['badge_type'],
        );
      } else {
        list.removeWhere((item) => item['id'] == values['id']);
      }
    }

    list.add(Map<String, Object?>.from(values));
    return 1;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final list = tables[table]!;
    int count = 0;
    for (int i = 0; i < list.length; i++) {
      final row = list[i];
      bool match = true;
      if (where != null && whereArgs != null) {
        if (where.startsWith('id = ?')) {
          match = row['id'] == whereArgs.first;
        } else if (where.startsWith('run_id = ?')) {
          match = row['run_id'] == whereArgs.first;
        }
      }
      if (match) {
        final updated = Map<String, Object?>.from(row);
        values.forEach((key, val) {
          updated[key] = val;
        });
        list[i] = updated;
        count++;
      }
    }
    return count;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final list = tables[table]!;
    final initialLength = list.length;

    if (where != null && whereArgs != null) {
      if (where.startsWith('id = ?')) {
        list.removeWhere((item) => item['id'] == whereArgs.first);
      } else if (where.startsWith('run_id = ?')) {
        list.removeWhere((item) => item['run_id'] == whereArgs.first);
      }
    } else {
      list.clear();
    }

    return initialLength - list.length;
  }

  @override
  Batch batch() => FakeBatch(this);
}

class FakeTransaction extends Fake implements Transaction {
  final FakeDatabase _db;
  FakeTransaction(this._db);

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    return _db.insert(table, values, conflictAlgorithm: conflictAlgorithm);
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    return _db.delete(table, where: where, whereArgs: whereArgs);
  }

  @override
  Batch batch() => FakeBatch(_db);
}

class FakeBatch extends Fake implements Batch {
  final FakeDatabase _db;
  final List<void Function()> _operations = [];
  FakeBatch(this._db);

  @override
  void insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    _operations.add(() {
      _db.insert(table, values, conflictAlgorithm: conflictAlgorithm);
    });
  }

  @override
  Future<List<Object?>> commit({
    bool? exclusive,
    bool? noResult,
    bool? continueOnError,
  }) async {
    for (final op in _operations) {
      op();
    }
    return [];
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Minimal valid JSONL run file with one accepted GPS point near (1.0, 1.0).
String _makeRunJsonl(String runId, {int startedAtUtcMs = 1731600000000}) {
  return [
    jsonEncode({'v': 1, 'runId': runId, 'startedAtUtcMs': startedAtUtcMs}),
    jsonEncode({
      'k': 'p',
      'seq': 0,
      't': startedAtUtcMs,
      'lat': 1.0,
      'lon': 1.0,
      'acc': 4.0,
      'spd': 2.78,
      'alt': 10.0,
      'ok': 1,
    }),
    jsonEncode({
      'k': 'p',
      'seq': 1,
      't': startedAtUtcMs + 300000,
      'lat': 1.0089933,
      'lon': 1.0,
      'acc': 3.5,
      'spd': 3.2,
      'alt': 12.0,
      'ok': true,
    }),
    jsonEncode({'k': 'end', 't': startedAtUtcMs + 300000}),
  ].join('\n');
}

/// A JSONL run with NO accepted GPS points (all ok=false).
String _makeRunJsonlNoPoints(
  String runId, {
  int startedAtUtcMs = 1731600000000,
}) {
  return [
    jsonEncode({'v': 1, 'runId': runId, 'startedAtUtcMs': startedAtUtcMs}),
    jsonEncode({
      'k': 'p',
      'seq': 0,
      't': startedAtUtcMs,
      'lat': 1.0,
      'lon': 1.0,
      'acc': 50.0,
      'spd': 20.0,
      'alt': 10.0,
      'ok': false,
    }),
    jsonEncode({'k': 'end', 't': startedAtUtcMs + 10000}),
  ].join('\n');
}

/// Builds a minimal Open-Meteo JSON response matching startedAtUtcMs.
http.Response _weatherResponse({int startedAtUtcMs = 1731600000000}) {
  final seconds = startedAtUtcMs ~/ 1000;
  final body = jsonEncode({
    'hourly': {
      'time': [seconds],
      'temperature_2m': [15.0],
      'wind_speed_10m': [10.0],
      'weather_code': [0],
    },
  });
  return http.Response(body, 200);
}

/// Builds a minimal Nominatim JSON response.
http.Response _placeResponse() {
  final body = jsonEncode({
    'address': {'city': 'Colombo'},
  });
  return http.Response(body, 200);
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('RunEnrichmentService integration tests (SRS §8.5)', () {
    late FakeDatabase fakeDb;
    late AppDatabase appDatabase;
    late SqliteRunRepository repository;
    late Directory tempDir;

    setUp(() {
      fakeDb = FakeDatabase();
      appDatabase = AppDatabase(database: fakeDb);
      tempDir = Directory.systemTemp.createTempSync(
        'road_runner_enrichment_test_',
      );
      repository = SqliteRunRepository(
        database: appDatabase,
        runsDirectoryPath: tempDir.path,
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    // ── 1. Offline (no internet) → fallback name set, no crash ──────────────

    test(
      '1. enrichRun sets a fallback run name offline and does not throw',
      () async {
        const runId = 'run-offline-1';
        final file = File('${tempDir.path}/$runId.jsonl')
          ..writeAsStringSync(_makeRunJsonl(runId));
        await repository.saveFromFile(runId, file.path);

        final failingClient = MockClient((_) async => http.Response('', 503));
        final service = RunEnrichmentService(
          repository: repository,
          weatherClient: RunWeatherClient(failingClient),
          placeClient: RunPlaceClient(
            client: failingClient,
            cache: PlaceCache(appDatabase),
            contactEmail: 'test@test.com',
          ),
        );

        await expectLater(service.enrichRun(runId), completes);

        final run = await repository.get(runId);
        expect(run, isNotNull);
        expect(
          run!.runName,
          isNotNull,
          reason: 'Fallback name must be set even without network',
        );
        expect(
          run.localStartDay,
          isNotNull,
          reason: 'Calendar day must be set from start timestamp',
        );
      },
    );

    // ── 2. Weather + place arrive and persist across re-read ─────────────────

    test(
      '2. enrichRun saves weather and place; re-reading run shows the values',
      () async {
        const runId = 'run-enrich-2';
        final file = File('${tempDir.path}/$runId.jsonl')
          ..writeAsStringSync(_makeRunJsonl(runId));
        await repository.saveFromFile(runId, file.path);

        final mockClient = MockClient((req) async {
          if (req.url.host.contains('open-meteo')) return _weatherResponse();
          return _placeResponse();
        });

        final service = RunEnrichmentService(
          repository: repository,
          weatherClient: RunWeatherClient(mockClient),
          placeClient: RunPlaceClient(
            client: mockClient,
            cache: PlaceCache(appDatabase),
            contactEmail: 'test@test.com',
          ),
        );

        await service.enrichRun(runId);

        final run = await repository.get(runId);
        expect(run, isNotNull);
        expect(
          run!.weatherTempC,
          isNotNull,
          reason: 'Temperature must be saved after enrichment',
        );
        expect(
          run.weatherWindKmh,
          isNotNull,
          reason: 'Wind speed must be saved after enrichment',
        );
        expect(
          run.weatherCode,
          isNotNull,
          reason: 'Weather code must be saved after enrichment',
        );
        expect(
          run.placeName,
          isNotNull,
          reason: 'Place name must be saved after enrichment',
        );
        expect(
          run.runName,
          isNotNull,
          reason: 'Run name must reflect the place name',
        );
      },
    );

    // ── 3. No accepted GPS point → fallback name, no crash ───────────────────

    test(
      '3. enrichRun with no accepted GPS points still sets fallback name',
      () async {
        const runId = 'run-nopoints-3';
        final file = File('${tempDir.path}/$runId.jsonl')
          ..writeAsStringSync(_makeRunJsonlNoPoints(runId));
        await repository.saveFromFile(runId, file.path);

        int apiCallCount = 0;
        final trackingClient = MockClient((_) async {
          apiCallCount++;
          return http.Response('', 500);
        });
        final service = RunEnrichmentService(
          repository: repository,
          weatherClient: RunWeatherClient(trackingClient),
          placeClient: RunPlaceClient(
            client: trackingClient,
            cache: PlaceCache(appDatabase),
            contactEmail: 'test@test.com',
          ),
        );

        await expectLater(service.enrichRun(runId), completes);

        // No GPS point → no API calls should be made
        expect(
          apiCallCount,
          0,
          reason: 'No API calls should be made without an accepted point',
        );

        final run = await repository.get(runId);
        expect(
          run!.runName,
          isNotNull,
          reason: 'Fallback name must be set even without GPS points',
        );
        expect(run.localStartDay, isNotNull);
      },
    );

    // ── 4. Re-import retains weather, name, badges ────────────────────────────

    test(
      '4. Re-importing a run via saveFromFile retains enriched metadata',
      () async {
        const runId = 'run-reimport-4';
        final filePath = '${tempDir.path}/$runId.jsonl';
        File(filePath).writeAsStringSync(_makeRunJsonl(runId));
        await repository.saveFromFile(runId, filePath);

        // Enrich it
        final mockClient = MockClient((req) async {
          if (req.url.host.contains('open-meteo')) return _weatherResponse();
          return _placeResponse();
        });
        final service = RunEnrichmentService(
          repository: repository,
          weatherClient: RunWeatherClient(mockClient),
          placeClient: RunPlaceClient(
            client: mockClient,
            cache: PlaceCache(appDatabase),
            contactEmail: 'test@test.com',
          ),
        );
        await service.enrichRun(runId);

        final enriched = await repository.get(runId);
        expect(enriched!.weatherTempC, isNotNull);
        expect(enriched.placeName, isNotNull);

        // Re-import the same file (simulating a crash-recovery import)
        await repository.saveFromFile(runId, filePath);

        final reimported = await repository.get(runId);
        expect(
          reimported!.weatherTempC,
          enriched.weatherTempC,
          reason: 'Weather must survive re-import',
        );
        expect(
          reimported.placeName,
          enriched.placeName,
          reason: 'Place name must survive re-import',
        );
        expect(
          reimported.runName,
          isNotNull,
          reason: 'Run name must survive re-import',
        );
      },
    );

    // ── 5. Place cache hit makes no Nominatim request ─────────────────────────

    test('5. Second enrichRun for same location hits cache, makes no Nominatim call', () async {
      int nominatimCalls = 0;
      final mockClient = MockClient((req) async {
        if (req.url.host.contains('open-meteo')) return _weatherResponse();
        nominatimCalls++;
        return _placeResponse();
      });

      final placeCache = PlaceCache(appDatabase);
      final placeClient = RunPlaceClient(
        client: mockClient,
        cache: placeCache,
        contactEmail: 'test@test.com',
      );
      final weatherClient = RunWeatherClient(mockClient);

      // First run — populates cache
      const run1 = 'run-cache-5a';
      File('${tempDir.path}/$run1.jsonl')
          .writeAsStringSync(_makeRunJsonl(run1));
      await repository.saveFromFile(run1, '${tempDir.path}/$run1.jsonl');
      await RunEnrichmentService(
        repository: repository,
        weatherClient: weatherClient,
        placeClient: placeClient,
      ).enrichRun(run1);

      final callsAfterFirst = nominatimCalls;
      expect(
        callsAfterFirst,
        1,
        reason: 'First lookup must call Nominatim once',
      );

      // Second run at same coordinates — cache hit
      const run2 = 'run-cache-5b';
      File('${tempDir.path}/$run2.jsonl')
          .writeAsStringSync(_makeRunJsonl(run2));
      await repository.saveFromFile(run2, '${tempDir.path}/$run2.jsonl');
      await RunEnrichmentService(
        repository: repository,
        weatherClient: weatherClient,
        placeClient: placeClient,
      ).enrichRun(run2);

      expect(
        nominatimCalls,
        callsAfterFirst,
        reason: 'Second lookup at same location must NOT call Nominatim',
      );
    });

    // ── 6. Deleting a run updates streak / badge results ─────────────────────

    test(
      '6. Deleting a run removes its badges and may change the current streak',
      () async {
        const run1 = 'run-del-6a';
        const run2 = 'run-del-6b';

        // Two consecutive days
        const day1Ms = 1731600000000; // 2024-11-14
        const day2Ms = day1Ms + Duration.millisecondsPerDay;

        for (final entry in [(run1, day1Ms), (run2, day2Ms)]) {
          final (runId, startMs) = entry;
          File('${tempDir.path}/$runId.jsonl')
              .writeAsStringSync(_makeRunJsonl(runId, startedAtUtcMs: startMs));
          await repository.saveFromFile(runId, '${tempDir.path}/$runId.jsonl');
        }

        // Set local_start_day so streak can be calculated
        final d1 = DateTime.fromMillisecondsSinceEpoch(
          day1Ms,
          isUtc: true,
        ).toLocal().toIso8601String().substring(0, 10);
        final d2 = DateTime.fromMillisecondsSinceEpoch(
          day2Ms,
          isUtc: true,
        ).toLocal().toIso8601String().substring(0, 10);
        await repository.updateDetails(run1, localStartDay: d1);
        await repository.updateDetails(run2, localStartDay: d2);
        await repository.recalculateBadges();

        final badgesBeforeDelete = await repository.getBadgesForRun(run1);
        // run1 should at least have the first_run badge
        expect(
          badgesBeforeDelete.map((b) => b.type.key),
          contains('first_run'),
        );

        // Now delete run1
        await repository.delete(run1);

        // Badges for the deleted run must be gone
        final badgesAfterDelete = await repository.getBadgesForRun(run1);
        expect(
          badgesAfterDelete,
          isEmpty,
          reason: 'Deleted run must have no badges',
        );
      },
    );

    // ── 7. Past run opened from History shows saved metadata ──────────────────

    test(
      '7. Getting a run after enrichment shows all metadata fields',
      () async {
        const runId = 'run-history-7';
        final file = File('${tempDir.path}/$runId.jsonl')
          ..writeAsStringSync(_makeRunJsonl(runId));
        await repository.saveFromFile(runId, file.path);

        final mockClient = MockClient((req) async {
          if (req.url.host.contains('open-meteo')) return _weatherResponse();
          return _placeResponse();
        });
        final service = RunEnrichmentService(
          repository: repository,
          weatherClient: RunWeatherClient(mockClient),
          placeClient: RunPlaceClient(
            client: mockClient,
            cache: PlaceCache(appDatabase),
            contactEmail: 'test@test.com',
          ),
        );
        await service.enrichRun(runId);

        final run = await repository.get(runId);
        expect(run, isNotNull);

        // All metadata fields must be present
        expect(run!.runName, isNotNull);
        expect(run.placeName, isNotNull);
        expect(run.weatherTempC, isNotNull);
        expect(run.weatherWindKmh, isNotNull);
        expect(run.weatherCode, isNotNull);
        expect(run.localStartDay, isNotNull);
      },
    );

    // ── 8. ConflictAlgorithm.replace does NOT clear metadata ─────────────────

    test('8. saveFromFile with conflictAlgorithm.replace preserves enriched metadata', () async {
      const runId = 'run-conflict-8';
      final filePath = '${tempDir.path}/$runId.jsonl';
      File(filePath).writeAsStringSync(_makeRunJsonl(runId));
      await repository.saveFromFile(runId, filePath);

      // Manually set enrichment fields
      await repository.updateDetails(
        runId,
        runName: 'Awesome Morning Run',
        placeName: 'Colombo',
        temperatureC: 28.5,
        windKmh: 12.0,
        weatherCode: 1,
        localStartDay: '2024-11-14',
      );

      // Verify they're set
      final beforeReimport = await repository.get(runId);
      expect(beforeReimport!.runName, 'Awesome Morning Run');

      // Re-import the same file (triggers ConflictAlgorithm.replace logic)
      await repository.saveFromFile(runId, filePath);

      final afterReimport = await repository.get(runId);
      expect(
        afterReimport!.runName,
        'Awesome Morning Run',
        reason: 'run_name must not be wiped by re-import',
      );
      expect(
        afterReimport.placeName,
        'Colombo',
        reason: 'place_name must not be wiped by re-import',
      );
      expect(
        afterReimport.weatherTempC,
        28.5,
        reason: 'weather_temp_c must not be wiped by re-import',
      );
      expect(
        afterReimport.weatherCode,
        1,
        reason: 'weather_code must not be wiped by re-import',
      );
      expect(
        afterReimport.localStartDay,
        '2024-11-14',
        reason: 'local_start_day must not be wiped by re-import',
      );
    });

    // ── 9. enrichRun never calls saveFromFile ─────────────────────────────────

    test('9. enrichRun does not alter run distance/duration metrics', () async {
      const runId = 'run-noreplace-9';
      final file = File('${tempDir.path}/$runId.jsonl')
        ..writeAsStringSync(_makeRunJsonl(runId));
      await repository.saveFromFile(runId, file.path);

      final before = await repository.get(runId);
      final distanceBefore = before!.distanceM;
      final movingMsBefore = before.movingMs;

      final mockClient = MockClient((req) async {
        if (req.url.host.contains('open-meteo')) return _weatherResponse();
        return _placeResponse();
      });
      await RunEnrichmentService(
        repository: repository,
        weatherClient: RunWeatherClient(mockClient),
        placeClient: RunPlaceClient(
          client: mockClient,
          cache: PlaceCache(appDatabase),
          contactEmail: 'test@test.com',
        ),
      ).enrichRun(runId);

      final after = await repository.get(runId);
      expect(
        after!.distanceM,
        distanceBefore,
        reason: 'enrichRun must not change distance metrics',
      );
      expect(
        after.movingMs,
        movingMsBefore,
        reason: 'enrichRun must not change moving time',
      );
    });

    test('10. enrichment keeps a runner-chosen name', () async {
      const runId = 'run-custom-name-10';
      final file = File('${tempDir.path}/$runId.jsonl')
        ..writeAsStringSync(_makeRunJsonl(runId));
      await repository.saveFromFile(runId, file.path);
      await repository.updateDetails(runId, runName: 'Park intervals');

      final mockClient = MockClient((req) async {
        if (req.url.host.contains('open-meteo')) return _weatherResponse();
        return _placeResponse();
      });
      await RunEnrichmentService(
        repository: repository,
        weatherClient: RunWeatherClient(mockClient),
        placeClient: RunPlaceClient(
          client: mockClient,
          cache: PlaceCache(appDatabase),
          contactEmail: 'test@test.com',
        ),
      ).enrichRun(runId);

      final run = await repository.get(runId);
      expect(run?.runName, 'Park intervals');
      expect(run?.placeName, isNotNull);
    });
  });
}

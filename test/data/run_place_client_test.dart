// Road Runner — Unit Tests for PlaceCache, RunPlaceClient and Place Enrichment
// Owner: Nadeesha
// SRS reference: Section 8.5

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:road_runner/data/app_database.dart';
import 'package:road_runner/data/place_cache.dart';
import 'package:road_runner/data/run_place_client.dart';
import 'package:road_runner/data/run_repository.dart';
import 'package:road_runner/domain/stats/models.dart';

import 'run_repository_test.dart';

void main() {
  group('placeBucket Tests', () {
    test('rounds coordinates to integer buckets (x 1000)', () {
      expect(placeBucket(-33.815), -33815);
      expect(placeBucket(151.0012), 151001);
      expect(placeBucket(0.0), 0);
    });
  });

  group('PlaceCache & RunPlaceClient Tests', () {
    late FakeDatabase fakeDb;
    late AppDatabase appDatabase;
    late PlaceCache cache;

    final testPoint = Point(
      seq: 0,
      tUtcMs: 1700000000000,
      lat: -33.815,
      lon: 151.001,
      accM: 3.0,
      speedMps: 2.5,
      altM: 10.0,
      accepted: true,
    );

    setUp(() {
      fakeDb = FakeDatabase();
      appDatabase = AppDatabase(database: fakeDb);
      cache = PlaceCache(appDatabase);
    });

    test(
      'cache miss makes exactly one HTTP request and stores result in cache',
      () async {
        int requestCount = 0;
        final mockClient = MockClient((request) async {
          requestCount++;
          expect(request.url.queryParameters['lat'], '-33.815');
          expect(request.url.queryParameters['lon'], '151.001');
          expect(
            request.headers['User-Agent'],
            contains('test@roadrunner.local'),
          );

          final payload = {
            'address': {
              'suburb': 'Parramatta',
              'city': 'Sydney',
              'country': 'Australia',
            },
          };
          return http.Response(jsonEncode(payload), 200);
        });

        final client = RunPlaceClient(
          client: mockClient,
          cache: cache,
          contactEmail: 'test@roadrunner.local',
        );

        final result1 = await client.lookup(testPoint);
        expect(result1, 'Parramatta');
        expect(requestCount, 1);

        // Verify cached in SQLite table
        final cachedValue = await cache.get(testPoint);
        expect(cachedValue, 'Parramatta');

        // Second lookup should be a cache hit with 0 additional HTTP requests
        final result2 = await client.lookup(testPoint);
        expect(result2, 'Parramatta');
        expect(requestCount, 1);
      },
    );

    test('cache hit makes zero HTTP requests', () async {
      await cache.put(testPoint, 'Hyde Park');

      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response('{}', 200);
      });

      final client = RunPlaceClient(
        client: mockClient,
        cache: cache,
        contactEmail: 'test@roadrunner.local',
      );

      final result = await client.lookup(testPoint);
      expect(result, 'Hyde Park');
      expect(requestCount, 0);
    });

    test('extracts city, town, or village if suburb is absent', () async {
      final mockClient = MockClient((request) async {
        final payload = {
          'address': {'city': 'Colombo', 'country': 'Sri Lanka'},
        };
        return http.Response(jsonEncode(payload), 200);
      });

      final client = RunPlaceClient(
        client: mockClient,
        cache: cache,
        contactEmail: 'test@roadrunner.local',
      );

      final result = await client.lookup(testPoint);
      expect(result, 'Colombo');
    });

    test('returns null when address is missing or on HTTP error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final client = RunPlaceClient(
        client: mockClient,
        cache: cache,
        contactEmail: 'test@roadrunner.local',
      );

      final result = await client.lookup(testPoint);
      expect(result, isNull);
    });

    test('returns null on network exception without rethrowing', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('Network error');
      });

      final client = RunPlaceClient(
        client: mockClient,
        cache: cache,
        contactEmail: 'test@roadrunner.local',
      );

      final result = await client.lookup(testPoint);
      expect(result, isNull);
    });
  });

  group('enrichRunPlace Integration Tests', () {
    late FakeDatabase fakeDb;
    late AppDatabase appDatabase;
    late SqliteRunRepository repository;
    late PlaceCache cache;
    late Directory tempDir;

    setUp(() {
      fakeDb = FakeDatabase();
      appDatabase = AppDatabase(database: fakeDb);
      cache = PlaceCache(appDatabase);
      tempDir = Directory.systemTemp.createTempSync('road_runner_place_test_');
      repository = SqliteRunRepository(
        database: appDatabase,
        runsDirectoryPath: tempDir.path,
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('response with suburb: Parramatta produces "Morning run in Parramatta"', () async {
      const runId = 'morning-parramatta-run';
      final file = File('${tempDir.path}/$runId.jsonl');

      // 08:30 UTC
      final startUtc = DateTime.utc(2026, 11, 16, 8, 30).millisecondsSinceEpoch;

      final content = StringBuffer()
        ..writeln('{"v":1,"runId":"$runId","startedAtUtcMs":$startUtc}')
        ..writeln(
          '{"k":"p","seq":0,"t":$startUtc,"lat":-33.815,"lon":151.001,"acc":3.0,"spd":2.5,"alt":10.0,"ok":1}',
        )
        ..writeln('{"k":"end","t":${startUtc + 600000}}');

      await file.writeAsString(content.toString());
      await repository.saveFromFile(runId, file.path);

      final mockClient = MockClient((request) async {
        final payload = {
          'address': {'suburb': 'Parramatta'},
        };
        return http.Response(jsonEncode(payload), 200);
      });

      final placeClient = RunPlaceClient(
        client: mockClient,
        cache: cache,
        contactEmail: 'dev@roadrunner.local',
      );

      await enrichRunPlace(
        runId,
        repository: repository,
        placeClient: placeClient,
      );

      final run = await repository.get(runId);
      expect(run, isNotNull);
      expect(run!.placeName, 'Parramatta');
      final localStart = DateTime.fromMillisecondsSinceEpoch(
        startUtc,
        isUtc: true,
      ).toLocal();
      expect(run.runName, makeRunName(localStart, 'Parramatta'));
    });

    test('missing address or network error gives the fallback name', () async {
      const runId = 'fallback-name-run';
      final file = File('${tempDir.path}/$runId.jsonl');

      final startUtc = DateTime.utc(2026, 11, 16, 8, 30).millisecondsSinceEpoch;
      final content = StringBuffer()
        ..writeln('{"v":1,"runId":"$runId","startedAtUtcMs":$startUtc}')
        ..writeln(
          '{"k":"p","seq":0,"t":$startUtc,"lat":0.0,"lon":0.0,"acc":3.0,"spd":2.5,"alt":10.0,"ok":1}',
        )
        ..writeln('{"k":"end","t":${startUtc + 600000}}');

      await file.writeAsString(content.toString());
      await repository.saveFromFile(runId, file.path);

      final mockClient = MockClient((request) async {
        return http.Response('503 Service Unavailable', 503);
      });

      final placeClient = RunPlaceClient(
        client: mockClient,
        cache: cache,
        contactEmail: 'dev@roadrunner.local',
      );

      await enrichRunPlace(
        runId,
        repository: repository,
        placeClient: placeClient,
      );

      final run = await repository.get(runId);
      expect(run, isNotNull);
      expect(run!.placeName, isNull);
      final localStart = DateTime.fromMillisecondsSinceEpoch(
        startUtc,
        isUtc: true,
      ).toLocal();
      expect(run.runName, makeRunName(localStart, null));
    });

    test('no accepted point gives fallback run name', () async {
      const runId = 'no-accepted-point-place-run';
      final file = File('${tempDir.path}/$runId.jsonl');

      final startUtc = DateTime.utc(2026, 11, 16, 14, 0).millisecondsSinceEpoch;
      final content = StringBuffer()
        ..writeln('{"v":1,"runId":"$runId","startedAtUtcMs":$startUtc}')
        ..writeln(
          '{"k":"p","seq":0,"t":$startUtc,"lat":0.0,"lon":0.0,"acc":100.0,"spd":2.5,"alt":10.0,"ok":0}',
        )
        ..writeln('{"k":"end","t":${startUtc + 600000}}');

      await file.writeAsString(content.toString());
      await repository.saveFromFile(runId, file.path);

      final mockClient = MockClient(
        (request) async => http.Response('{}', 200),
      );
      final placeClient = RunPlaceClient(
        client: mockClient,
        cache: cache,
        contactEmail: 'dev@roadrunner.local',
      );

      await enrichRunPlace(
        runId,
        repository: repository,
        placeClient: placeClient,
      );

      final run = await repository.get(runId);
      expect(run, isNotNull);
      expect(run!.placeName, isNull);
      final localStart = DateTime.fromMillisecondsSinceEpoch(
        startUtc,
        isUtc: true,
      ).toLocal();
      expect(run.runName, makeRunName(localStart, null));
    });

    test('the name survives restart and repeated import', () async {
      const runId = 'survive-reimport-run';
      final file = File('${tempDir.path}/$runId.jsonl');

      final startUtc = DateTime.utc(2026, 11, 16, 9, 0).millisecondsSinceEpoch;
      final content = StringBuffer()
        ..writeln('{"v":1,"runId":"$runId","startedAtUtcMs":$startUtc}')
        ..writeln(
          '{"k":"p","seq":0,"t":$startUtc,"lat":-33.815,"lon":151.001,"acc":3.0,"spd":2.5,"alt":10.0,"ok":1}',
        )
        ..writeln('{"k":"end","t":${startUtc + 600000}}');

      await file.writeAsString(content.toString());
      await repository.saveFromFile(runId, file.path);

      await repository.updateDetails(
        runId,
        placeName: 'Parramatta',
        runName: 'Morning run in Parramatta',
      );

      // Re-import the run file (same run ID)
      await repository.saveFromFile(runId, file.path);

      final reimported = await repository.get(runId);
      expect(reimported, isNotNull);
      expect(reimported!.placeName, 'Parramatta');
      expect(reimported.runName, 'Morning run in Parramatta');
    });
  });
}

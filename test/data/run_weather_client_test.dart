// Road Runner — Unit Tests for RunWeatherClient and Weather Enrichment
// Owner: Nadeesha
// SRS reference: Section 8.5

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:road_runner/data/app_database.dart';
import 'package:road_runner/data/run_repository.dart';
import 'package:road_runner/data/run_weather_client.dart';
import 'package:road_runner/domain/stats/models.dart';

import 'run_repository_test.dart';

void main() {
  group('RunCondition Mapping Tests', () {
    test('maps WMO codes to correct RunCondition', () {
      expect(conditionFromCode(0), RunCondition.clear);
      expect(conditionFromCode(1), RunCondition.clear);
      expect(conditionFromCode(2), RunCondition.cloudy);
      expect(conditionFromCode(3), RunCondition.cloudy);
      expect(conditionFromCode(45), RunCondition.fog);
      expect(conditionFromCode(48), RunCondition.fog);
      expect(conditionFromCode(51), RunCondition.drizzle);
      expect(conditionFromCode(53), RunCondition.drizzle);
      expect(conditionFromCode(55), RunCondition.drizzle);
      expect(conditionFromCode(61), RunCondition.rain);
      expect(conditionFromCode(63), RunCondition.rain);
      expect(conditionFromCode(65), RunCondition.rain);
      expect(conditionFromCode(80), RunCondition.rain);
      expect(conditionFromCode(71), RunCondition.snow);
      expect(conditionFromCode(73), RunCondition.snow);
      expect(conditionFromCode(85), RunCondition.snow);
      expect(conditionFromCode(95), RunCondition.thunderstorm);
      expect(conditionFromCode(96), RunCondition.thunderstorm);
      expect(conditionFromCode(99), RunCondition.thunderstorm);
      expect(conditionFromCode(null), RunCondition.unknown);
      expect(conditionFromCode(999), RunCondition.unknown);
    });
  });

  group('RunWeatherClient Unit Tests', () {
    final testPoint = Point(
      seq: 0,
      tUtcMs: 1700000000000,
      lat: 6.9271,
      lon: 79.8612,
      accM: 3.0,
      speedMps: 2.5,
      altM: 10.0,
      accepted: true,
    );

    test('selects nearest hour and correctly converts seconds to ms', () async {
      // 1700000000 seconds = 1700000000000 ms
      // Target run time: 1700001000000 ms (+1000 sec -> closer to 1700000000 than 1700003600)
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['latitude'], '6.9271');
        expect(request.url.queryParameters['longitude'], '79.8612');
        expect(request.url.queryParameters['timeformat'], 'unixtime');

        final payload = {
          'hourly': {
            'time': [1700000000, 1700003600, 1700007200],
            'temperature_2m': [24.5, 26.0, 27.2],
            'wind_speed_10m': [11.2, 14.5, 10.0],
            'weather_code': [1, 3, 61],
          },
        };
        return http.Response(jsonEncode(payload), 200);
      });

      final client = RunWeatherClient(mockClient);
      final weather = await client.fetch(testPoint, 1700000900000);

      expect(weather, isNotNull);
      expect(weather!.temperatureC, 24.5);
      expect(weather.windKmh, 11.2);
      expect(weather.code, 1);
    });

    test('returns null if nearest hour is too far (> 1 hour gap)', () async {
      final mockClient = MockClient((request) async {
        final payload = {
          'hourly': {
            'time': [1700000000],
            'temperature_2m': [24.5],
            'wind_speed_10m': [11.2],
            'weather_code': [1],
          },
        };
        return http.Response(jsonEncode(payload), 200);
      });

      final client = RunWeatherClient(mockClient);
      // Run time is 2 hours later
      final weather = await client.fetch(testPoint, (1700000000 + 7200) * 1000);
      expect(weather, isNull);
    });

    test('returns null on HTTP non-200 error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final client = RunWeatherClient(mockClient);
      final weather = await client.fetch(testPoint, 1700000000000);
      expect(weather, isNull);
    });

    test('returns null on request timeout or network exception', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('Connection refused');
      });

      final client = RunWeatherClient(mockClient);
      final weather = await client.fetch(testPoint, 1700000000000);
      expect(weather, isNull);
    });
  });

  group('enrichRunWeather Integration Tests', () {
    late FakeDatabase fakeDb;
    late AppDatabase appDatabase;
    late SqliteRunRepository repository;
    late Directory tempDir;

    setUp(() {
      fakeDb = FakeDatabase();
      appDatabase = AppDatabase(database: fakeDb);
      tempDir = Directory.systemTemp.createTempSync(
        'road_runner_weather_test_',
      );
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

    test('enriches run with weather when accepted points exist', () async {
      const runId = 'enrich-weather-run';
      final file = File('${tempDir.path}/$runId.jsonl');

      final content = StringBuffer()
        ..writeln('{"v":1,"runId":"$runId","startedAtUtcMs":1700000000000}')
        ..writeln(
          '{"k":"p","seq":0,"t":1700000000000,"lat":6.9271,"lon":79.8612,"acc":3.0,"spd":2.5,"alt":10.0,"ok":1}',
        )
        ..writeln('{"k":"end","t":1700000600000}');

      await file.writeAsString(content.toString());
      await repository.saveFromFile(runId, file.path);

      final mockClient = MockClient((request) async {
        final payload = {
          'hourly': {
            'time': [1700000000],
            'temperature_2m': [28.2],
            'wind_speed_10m': [15.3],
            'weather_code': [2],
          },
        };
        return http.Response(jsonEncode(payload), 200);
      });

      final weatherClient = RunWeatherClient(mockClient);
      await enrichRunWeather(
        runId,
        repository: repository,
        weatherClient: weatherClient,
      );

      final run = await repository.get(runId);
      expect(run, isNotNull);
      expect(run!.weatherTempC, 28.2);
      expect(run.weatherWindKmh, 15.3);
      expect(run.weatherCode, 2);
    });

    test('skips weather update if no accepted points exist', () async {
      const runId = 'no-accepted-points-run';
      final file = File('${tempDir.path}/$runId.jsonl');

      // Run with only rejected point
      final content = StringBuffer()
        ..writeln('{"v":1,"runId":"$runId","startedAtUtcMs":1700000000000}')
        ..writeln(
          '{"k":"p","seq":0,"t":1700000000000,"lat":6.9271,"lon":79.8612,"acc":50.0,"spd":2.5,"alt":10.0,"ok":0}',
        )
        ..writeln('{"k":"end","t":1700000600000}');

      await file.writeAsString(content.toString());
      await repository.saveFromFile(runId, file.path);

      bool clientCalled = false;
      final mockClient = MockClient((request) async {
        clientCalled = true;
        return http.Response('{}', 200);
      });

      final weatherClient = RunWeatherClient(mockClient);
      await enrichRunWeather(
        runId,
        repository: repository,
        weatherClient: weatherClient,
      );

      expect(clientCalled, isFalse);
      final run = await repository.get(runId);
      expect(run!.weatherTempC, isNull);
    });

    test('re-import preserves existing weather', () async {
      const runId = 'preserve-weather-reimport';
      final file = File('${tempDir.path}/$runId.jsonl');

      final content = StringBuffer()
        ..writeln('{"v":1,"runId":"$runId","startedAtUtcMs":1700000000000}')
        ..writeln(
          '{"k":"p","seq":0,"t":1700000000000,"lat":6.9271,"lon":79.8612,"acc":3.0,"spd":2.5,"alt":10.0,"ok":1}',
        )
        ..writeln('{"k":"end","t":1700000600000}');

      await file.writeAsString(content.toString());
      await repository.saveFromFile(runId, file.path);

      await repository.updateWeather(
        runId,
        temperatureC: 22.0,
        windKmh: 5.0,
        weatherCode: 0,
      );

      // Re-import the run file
      await repository.saveFromFile(runId, file.path);

      final reimported = await repository.get(runId);
      expect(reimported, isNotNull);
      expect(reimported!.weatherTempC, 22.0);
      expect(reimported.weatherWindKmh, 5.0);
      expect(reimported.weatherCode, 0);
    });
  });
}

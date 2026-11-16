// Road Runner — Unit Tests for Run Model
// Owner: Nadeesha
// SRS reference: Section 8.5

import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/contract/contract.dart';
import 'package:road_runner/data/run.dart';

void main() {
  group('Run Model Tests (SRS §8.5)', () {
    const run = Run(
      id: 'test-run-uuid-1',
      startedAtUtcMs: 1731600000000,
      endedAtUtcMs: 1731600300000,
      movingMs: 290000,
      distanceM: 1000.5,
      avgPaceSecPerKm: 289.8,
      maxSpeedMps: 3.8,
      status: kStateSaved,
    );

    const runWithDetails = Run(
      id: 'test-run-details-1',
      startedAtUtcMs: 1731600000000,
      endedAtUtcMs: 1731600300000,
      movingMs: 290000,
      distanceM: 1000.5,
      avgPaceSecPerKm: 289.8,
      maxSpeedMps: 3.8,
      status: kStateSaved,
      runName: 'Morning run in Hyde Park',
      placeName: 'Hyde Park',
      weatherTempC: 21.5,
      weatherWindKmh: 15.2,
      weatherCode: 800,
      localStartDay: '2026-11-16',
    );

    test('converts to SQLite row map with correct column names', () {
      final dbMap = run.toDbMap();

      expect(dbMap['id'], 'test-run-uuid-1');
      expect(dbMap['started_at_utc_ms'], 1731600000000);
      expect(dbMap['ended_at_utc_ms'], 1731600300000);
      expect(dbMap['moving_ms'], 290000);
      expect(dbMap['distance_m'], 1000.5);
      expect(dbMap['avg_pace_sec_per_km'], 289.8);
      expect(dbMap['max_speed_mps'], 3.8);
      expect(dbMap['status'], 'saved');
      expect(dbMap['run_name'], isNull);
      expect(dbMap['place_name'], isNull);
      expect(dbMap['weather_temp_c'], isNull);
      expect(dbMap['weather_wind_kmh'], isNull);
      expect(dbMap['weather_code'], isNull);
      expect(dbMap['local_start_day'], isNull);
    });

    test('converts to SQLite row map with details fields', () {
      final dbMap = runWithDetails.toDbMap();

      expect(dbMap['run_name'], 'Morning run in Hyde Park');
      expect(dbMap['place_name'], 'Hyde Park');
      expect(dbMap['weather_temp_c'], 21.5);
      expect(dbMap['weather_wind_kmh'], 15.2);
      expect(dbMap['weather_code'], 800);
      expect(dbMap['local_start_day'], '2026-11-16');
    });

    test('reconstructs from SQLite row map accurately with details', () {
      final dbMap = runWithDetails.toDbMap();
      final reconstructed = Run.fromDbMap(dbMap);

      expect(reconstructed, equals(runWithDetails));
      expect(reconstructed.runName, 'Morning run in Hyde Park');
      expect(reconstructed.placeName, 'Hyde Park');
      expect(reconstructed.weatherTempC, 21.5);
      expect(reconstructed.weatherWindKmh, 15.2);
      expect(reconstructed.weatherCode, 800);
      expect(reconstructed.localStartDay, '2026-11-16');
    });

    test('reconstructs from SQLite row map accurately without details', () {
      final dbMap = run.toDbMap();
      final reconstructed = Run.fromDbMap(dbMap);

      expect(reconstructed, equals(run));
      expect(reconstructed.id, run.id);
      expect(reconstructed.startedAtUtcMs, run.startedAtUtcMs);
      expect(reconstructed.endedAtUtcMs, run.endedAtUtcMs);
      expect(reconstructed.movingMs, run.movingMs);
      expect(reconstructed.distanceM, run.distanceM);
      expect(reconstructed.avgPaceSecPerKm, run.avgPaceSecPerKm);
      expect(reconstructed.maxSpeedMps, run.maxSpeedMps);
      expect(reconstructed.status, 'saved');
      expect(reconstructed.runName, isNull);
      expect(reconstructed.placeName, isNull);
    });

    test('handles nullable avgPaceSecPerKm and maxSpeedMps gracefully', () {
      final Map<String, Object?> minimalMap = {
        'id': 'short-run-uuid',
        'started_at_utc_ms': 1731600000000,
        'ended_at_utc_ms': 1731600010000,
        'moving_ms': 10000,
        'distance_m': 30.0, // < 50m, no pace
        'avg_pace_sec_per_km': null,
        'max_speed_mps': null,
        'status': 'saved',
      };

      final parsed = Run.fromDbMap(minimalMap);
      expect(parsed.id, 'short-run-uuid');
      expect(parsed.avgPaceSecPerKm, isNull);
      expect(parsed.maxSpeedMps, isNull);
      expect(parsed.status, kStateSaved);
      expect(parsed.runName, isNull);

      final exported = parsed.toDbMap();
      expect(exported['avg_pace_sec_per_km'], isNull);
      expect(exported['max_speed_mps'], isNull);
      expect(exported['run_name'], isNull);
    });

    test('copyWith creates new instance with updated details properties', () {
      final updated = run.copyWith(
        distanceM: 1500.0,
        movingMs: 400000,
        runName: 'Afternoon run',
        weatherTempC: 24.0,
        placeName: 'Central Park',
      );

      expect(updated.distanceM, 1500.0);
      expect(updated.movingMs, 400000);
      expect(updated.id, run.id);
      expect(updated.runName, 'Afternoon run');
      expect(updated.weatherTempC, 24.0);
      expect(updated.placeName, 'Central Park');
      expect(updated.weatherWindKmh, isNull);
    });

    test('supports value equality and hashCode', () {
      const run2 = Run(
        id: 'test-run-details-1',
        startedAtUtcMs: 1731600000000,
        endedAtUtcMs: 1731600300000,
        movingMs: 290000,
        distanceM: 1000.5,
        avgPaceSecPerKm: 289.8,
        maxSpeedMps: 3.8,
        status: kStateSaved,
        runName: 'Morning run in Hyde Park',
        placeName: 'Hyde Park',
        weatherTempC: 21.5,
        weatherWindKmh: 15.2,
        weatherCode: 800,
        localStartDay: '2026-11-16',
      );

      expect(runWithDetails, equals(run2));
      expect(runWithDetails.hashCode, equals(run2.hashCode));
    });

    test('toString produces readable output', () {
      expect(runWithDetails.toString(), contains('weatherTempC: 21.5'));
      expect(runWithDetails.toString(), contains('placeName: Hyde Park'));
    });
  });
}

// Road Runner — Unit Tests for Running Statistics Calculator (Pure Dart)
// Owner: Nadeesha
// SRS reference: Section 4.6, 4.7, 8.5

import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/contract/contract.dart';
import 'package:road_runner/domain/stats/stats.dart';

void main() {
  group('computeDistance Tests (SRS §4.7)', () {
    test('returns 0.0 for empty or single point list', () {
      expect(computeDistance([]), 0.0);
      expect(
        computeDistance([
          const Point(tUtcMs: 1000, lat: 6.9271, lon: 79.8612),
        ]),
        0.0,
      );
    });

    test('sums distance between consecutive points accurately', () {
      // 1 degree latitude is ~111,195 meters
      const p1 = Point(tUtcMs: 1000, lat: 0.0, lon: 0.0);
      const p2 = Point(tUtcMs: 2000, lat: 0.0089932, lon: 0.0); // ~1000 m
      const p3 = Point(tUtcMs: 3000, lat: 0.0179864, lon: 0.0); // ~another 1000 m

      final dist = computeDistance([p1, p2, p3]);
      expect(dist, closeTo(2000.0, 1.0));
    });

    test('ignores unaccepted points in distance accumulation', () {
      const p1 = Point(tUtcMs: 1000, lat: 0.0, lon: 0.0, accepted: true);
      // Spike point rejected by GPS filter
      const pSpike = Point(tUtcMs: 1500, lat: 10.0, lon: 10.0, accepted: false);
      const p2 = Point(tUtcMs: 2000, lat: 0.0089932, lon: 0.0, accepted: true);

      final dist = computeDistance([p1, pSpike, p2]);
      // Should calculate distance directly between p1 and p2 (~1000m), skipping spike
      expect(dist, closeTo(1000.0, 1.0));
    });
  });

  group('computeMovingMs Tests (SRS §4.7)', () {
    test('returns full duration when no pauses occurred', () {
      expect(computeMovingMs(1000, 61000, []), 60000);
    });

    test('subtracts single pause correctly', () {
      final pauses = [
        const PauseInterval(startMs: 20000, endMs: 30000), // 10s pause
      ];
      // Total elapsed = 60s, moving = 50s = 50000ms
      expect(computeMovingMs(0, 60000, pauses), 50000);
    });

    test('subtracts multiple non-overlapping pauses correctly', () {
      final pauses = [
        const PauseInterval(startMs: 10000, endMs: 15000), // 5s
        const PauseInterval(startMs: 30000, endMs: 40000), // 10s
      ];
      // Total elapsed = 60s, paused = 15s, moving = 45s = 45000ms
      expect(computeMovingMs(0, 60000, pauses), 45000);
    });

    test('merges overlapping pause intervals and does not double-count pause time', () {
      final pauses = [
        const PauseInterval(startMs: 10000, endMs: 25000), // 10s to 25s
        const PauseInterval(startMs: 20000, endMs: 35000), // 20s to 35s (overlaps)
      ];
      // Merged pause window: 10s to 35s = 25s paused.
      // Total elapsed = 60s, moving = 35s = 35000ms
      expect(computeMovingMs(0, 60000, pauses), 35000);
    });

    test('merges adjacent touching pause intervals', () {
      final pauses = [
        const PauseInterval(startMs: 10000, endMs: 20000), // 10s
        const PauseInterval(startMs: 20000, endMs: 30000), // 10s
      ];
      // Merged: 10s to 30s = 20s paused.
      // Total elapsed = 60s, moving = 40s = 40000ms
      expect(computeMovingMs(0, 60000, pauses), 40000);
    });

    test('clamps pauses extending outside the start/end window', () {
      final pauses = [
        const PauseInterval(startMs: -5000, endMs: 10000), // starts before 0
        const PauseInterval(startMs: 50000, endMs: 80000), // ends after 60000
      ];
      // Clamped: [0, 10000] (10s) and [50000, 60000] (10s) -> total 20s
      // Total elapsed = 60s, moving = 40s = 40000ms
      expect(computeMovingMs(0, 60000, pauses), 40000);
    });

    test('returns 0 when pauses cover or exceed the entire run duration', () {
      final pauses = [
        const PauseInterval(startMs: 0, endMs: 60000),
      ];
      expect(computeMovingMs(0, 60000, pauses), 0);
    });

    test('returns 0 for invalid time range (endMs <= startMs)', () {
      expect(computeMovingMs(50000, 40000, []), 0);
      expect(computeMovingMs(50000, 50000, []), 0);
    });
  });

  group('computeAvgPaceSecPerKm Tests (SRS §4.7)', () {
    test('returns null when distance is below threshold (50m)', () {
      expect(computeAvgPaceSecPerKm(49.9, 30000), isNull);
      expect(computeAvgPaceSecPerKm(0.0, 30000), isNull);
    });

    test('returns null when moving time is non-positive', () {
      expect(computeAvgPaceSecPerKm(1000.0, 0), isNull);
      expect(computeAvgPaceSecPerKm(1000.0, -500), isNull);
    });

    test('calculates correct pace for valid distance and time', () {
      // 1000 m (1.0 km) in 300,000 ms (300 s) = 300 s/km (5:00 min/km)
      final pace = computeAvgPaceSecPerKm(1000.0, 300000);
      expect(pace, isNotNull);
      expect(pace!, closeTo(300.0, 0.001));

      // 5000 m (5.0 km) in 1,500,000 ms (1500 s) = 300 s/km
      final pace5k = computeAvgPaceSecPerKm(5000.0, 1500000);
      expect(pace5k, isNotNull);
      expect(pace5k!, closeTo(300.0, 0.001));
    });

    test('returns null when pace exceeds max limit (1200 s/km = 20 min/km)', () {
      // 1000 m in 1,201,000 ms = 1201 s/km > 1200
      expect(computeAvgPaceSecPerKm(1000.0, 1201000), isNull);
    });

    test('returns null for NaN or infinite inputs', () {
      expect(computeAvgPaceSecPerKm(double.nan, 300000), isNull);
      expect(computeAvgPaceSecPerKm(1000.0, 0), isNull);
    });
  });

  group('computeSplits Tests (SRS §4.7)', () {
    test('returns empty list for fewer than 2 points', () {
      expect(computeSplits([]), isEmpty);
      expect(
        computeSplits([
          const Point(tUtcMs: 0, lat: 0.0, lon: 0.0),
        ]),
        isEmpty,
      );
    });

    test('interpolates split timestamp accurately for a complete 1 km run', () {
      // Point 0 at 0m, t=0
      // Point 1 at 500m, t=150,000
      // Point 2 at 1000m, t=300,000
      // 0.0089933 degrees produces ~1000.009 meters (genuinely reaching and crossing 1 km)
      const p0 = Point(tUtcMs: 0, lat: 0.0, lon: 0.0);
      const p1 = Point(tUtcMs: 150000, lat: 0.0044966, lon: 0.0); // 500m
      const p2 = Point(tUtcMs: 300000, lat: 0.0089933, lon: 0.0); // ~1000m

      final splits = computeSplits([p0, p1, p2]);
      expect(splits, hasLength(1));
      expect(splits[0].kmIndex, 1);
      expect(splits[0].durationMs, closeTo(300000, 100));
      expect(splits[0].distanceM, CalcConfig.splitDistanceM);
      expect(splits[0].isPartial, isFalse);
    });

    test('reports partial split and does not round up for run slightly shorter than 1 km', () {
      // 0.0089932 degrees produces ~999.998 meters (1.8 mm short of 1 km)
      const p0 = Point(tUtcMs: 0, lat: 0.0, lon: 0.0);
      const p1 = Point(tUtcMs: 150000, lat: 0.0044966, lon: 0.0);
      const p2 = Point(tUtcMs: 300000, lat: 0.0089932, lon: 0.0);

      final splits = computeSplits([p0, p1, p2]);
      expect(splits, hasLength(1));
      expect(splits[0].kmIndex, 1);
      expect(splits[0].isPartial, isTrue);
      expect(splits[0].distanceM, closeTo(999.998, 0.01));
      expect(splits[0].durationMs, 300000);
    });

    test('interpolates split boundary crossing between two points', () {
      // Point 0 at 0m, t=0
      // Point 1 at 900m, t=270,000
      // Point 2 at 1100m, t=330,000
      // The 1000m mark is halfway between Point 1 and Point 2.
      // Expected boundary timestamp = 270,000 + 0.5 * (330,000 - 270,000) = 300,000 ms.
      const p0 = Point(tUtcMs: 0, lat: 0.0, lon: 0.0);
      const p1 = Point(tUtcMs: 270000, lat: 0.0080939, lon: 0.0); // ~900m
      const p2 = Point(tUtcMs: 330000, lat: 0.0098925, lon: 0.0); // ~1100m

      final splits = computeSplits([p0, p1, p2]);
      expect(splits, hasLength(2)); // 1 complete split + 1 partial split for 100m

      // First split: exactly 1 km
      expect(splits[0].kmIndex, 1);
      expect(splits[0].isPartial, isFalse);
      expect(splits[0].durationMs, closeTo(300000, 200));

      // Second split: partial for remainder (100m)
      expect(splits[1].kmIndex, 2);
      expect(splits[1].isPartial, isTrue);
      expect(splits[1].distanceM, closeTo(100.0, 1.0));
      expect(splits[1].durationMs, closeTo(30000, 200));
    });

    test('generates multiple full splits and partial final split for a 2.5 km run', () {
      // ~2.5 km run over 750,000 ms (5 min/km pace)
      const p0 = Point(tUtcMs: 0, lat: 0.0, lon: 0.0);
      const p1 = Point(tUtcMs: 300000, lat: 0.0089932, lon: 0.0); // 1000m
      const p2 = Point(tUtcMs: 600000, lat: 0.0179864, lon: 0.0); // 2000m
      const p3 = Point(tUtcMs: 750000, lat: 0.0224830, lon: 0.0); // 2500m

      final splits = computeSplits([p0, p1, p2, p3]);
      expect(splits, hasLength(3));

      expect(splits[0].kmIndex, 1);
      expect(splits[0].isPartial, isFalse);
      expect(splits[0].durationMs, closeTo(300000, 100));

      expect(splits[1].kmIndex, 2);
      expect(splits[1].isPartial, isFalse);
      expect(splits[1].durationMs, closeTo(300000, 100));

      expect(splits[2].kmIndex, 3);
      expect(splits[2].isPartial, isTrue);
      expect(splits[2].distanceM, closeTo(500.0, 1.0));
      expect(splits[2].durationMs, closeTo(150000, 100));
    });

    test('ignores unaccepted GPS points when calculating splits', () {
      const p0 = Point(tUtcMs: 0, lat: 0.0, lon: 0.0, accepted: true);
      const pSpike = Point(tUtcMs: 100000, lat: 5.0, lon: 5.0, accepted: false);
      const p1 = Point(tUtcMs: 300000, lat: 0.0089932, lon: 0.0, accepted: true);

      final splits = computeSplits([p0, pSpike, p1]);
      expect(splits, hasLength(1));
      expect(splits[0].kmIndex, 1);
      expect(splits[0].durationMs, closeTo(300000, 100));
    });
  });

  group('computeMaxSpeedMps Tests (SRS §4.7)', () {
    test('returns null when no points or all speeds are null', () {
      expect(computeMaxSpeedMps([]), isNull);
      expect(
        computeMaxSpeedMps([
          const Point(tUtcMs: 1000, lat: 0.0, lon: 0.0, speedMps: null),
        ]),
        isNull,
      );
    });

    test('finds maximum speed among accepted points', () {
      const points = [
        Point(tUtcMs: 1000, lat: 0.0, lon: 0.0, speedMps: 2.5),
        Point(tUtcMs: 2000, lat: 0.0, lon: 0.0, speedMps: 3.8),
        Point(tUtcMs: 3000, lat: 0.0, lon: 0.0, speedMps: 3.1),
      ];

      expect(computeMaxSpeedMps(points), 3.8);
    });

    test('ignores unaccepted points even if they have high speed', () {
      const points = [
        Point(tUtcMs: 1000, lat: 0.0, lon: 0.0, speedMps: 2.5, accepted: true),
        // Rejected spike speed
        Point(tUtcMs: 2000, lat: 0.0, lon: 0.0, speedMps: 25.0, accepted: false),
        Point(tUtcMs: 3000, lat: 0.0, lon: 0.0, speedMps: 3.2, accepted: true),
      ];

      expect(computeMaxSpeedMps(points), 3.2);
    });

    test('ignores negative or NaN speeds', () {
      const points = [
        Point(tUtcMs: 1000, lat: 0.0, lon: 0.0, speedMps: -2.5),
        Point(tUtcMs: 2000, lat: 0.0, lon: 0.0, speedMps: double.nan),
        Point(tUtcMs: 3000, lat: 0.0, lon: 0.0, speedMps: 2.8),
      ];

      expect(computeMaxSpeedMps(points), 2.8);
    });
  });

  group('Model Serialization Tests', () {
    test('Point SQLite database mapping', () {
      const point = Point(
        seq: 5,
        tUtcMs: 1731600000000,
        lat: 6.9271,
        lon: 79.8612,
        accM: 3.5,
        speedMps: 2.8,
        altM: 15.0,
        accepted: true,
      );

      final dbMap = point.toDbMap('run-123');
      expect(dbMap['run_id'], 'run-123');
      expect(dbMap['seq'], 5);
      expect(dbMap['t_utc_ms'], 1731600000000);
      expect(dbMap['lat'], 6.9271);
      expect(dbMap['lon'], 79.8612);
      expect(dbMap['acc_m'], 3.5);
      expect(dbMap['speed_mps'], 2.8);
      expect(dbMap['alt_m'], 15.0);
      expect(dbMap['accepted'], 1);

      final reconstructed = Point.fromDbMap(dbMap);
      expect(reconstructed.seq, point.seq);
      expect(reconstructed.tUtcMs, point.tUtcMs);
      expect(reconstructed.lat, point.lat);
      expect(reconstructed.lon, point.lon);
      expect(reconstructed.accM, point.accM);
      expect(reconstructed.speedMps, point.speedMps);
      expect(reconstructed.altM, point.altM);
      expect(reconstructed.accepted, isTrue);
    });

    test('Point JSONL parsing', () {
      final jsonl = {
        'k': 'p',
        'seq': 2,
        't': 1731600002000,
        'lat': 6.9272,
        'lon': 79.8613,
        'acc': 4.0,
        'spd': 2.75,
        'alt': 14.5,
        'ok': 1,
      };

      final point = Point.fromJsonl(jsonl);
      expect(point.seq, 2);
      expect(point.tUtcMs, 1731600002000);
      expect(point.lat, 6.9272);
      expect(point.lon, 79.8613);
      expect(point.accM, 4.0);
      expect(point.speedMps, 2.75);
      expect(point.altM, 14.5);
      expect(point.accepted, isTrue);
    });

    test('Split JSON serialization', () {
      const split = Split(
        kmIndex: 1,
        durationMs: 302000,
        distanceM: 1000.0,
        isPartial: false,
      );

      final json = split.toJson();
      expect(json['km_index'], 1);
      expect(json['duration_ms'], 302000);
      expect(json['is_partial'], isFalse);

      final parsed = Split.fromJson(json);
      expect(parsed.kmIndex, 1);
      expect(parsed.durationMs, 302000);
      expect(parsed.isPartial, isFalse);
    });
  });
}

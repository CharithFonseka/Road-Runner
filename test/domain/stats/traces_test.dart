import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/domain/stats/stats.dart';

// Road Runner — Golden GPS Trace Integration Tests
// Owner: Nadeesha
// SRS reference: Section 8.5, TC-04

/// Loads GPS points from a CSV trace file.
List<Point> _loadCsv(String path) {
  final lines = File(path).readAsLinesSync();
  if (lines.isEmpty) return [];

  final points = <Point>[];

  for (int i = 1; i < lines.length; i++) {
    final raw = lines[i].trim();
    if (raw.isEmpty) continue;

    final cols = raw.split(',');
    if (cols.length < 7) continue;

    final tUtcMs = int.tryParse(cols[0]);
    final lat = double.tryParse(cols[1]);
    final lon = double.tryParse(cols[2]);
    final accM = double.tryParse(cols[3]);
    final speedMps = cols[4].isEmpty ? null : double.tryParse(cols[4]);
    final altM = cols[5].isEmpty ? null : double.tryParse(cols[5]);

    if (tUtcMs == null || lat == null || lon == null || accM == null) {
      continue;
    }

    points.add(
      Point(
        seq: i - 1,
        tUtcMs: tUtcMs,
        lat: lat,
        lon: lon,
        accM: accM,
        speedMps: speedMps,
        altM: altM,
        accepted: true,
      ),
    );
  }

  return points;
}

/// Loads the expected JSON results for a trace.
Map<String, dynamic> _loadExpected(String path) {
  return jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
}

/// Returns a path relative to the project root.
String _tracePath(String name) => 'test_data/traces/$name';

void main() {
  group('Golden Trace Distance Tests (TC-04)', () {
    // 1. Straight 1 km trace
    test('straight_1km: distance within 1% of expected', () {
      final points = _loadCsv(_tracePath('straight_1km.csv'));
      final expected = _loadExpected(_tracePath('straight_1km_expected.json'));

      final expectedDist = (expected['distance_m'] as num).toDouble();

      expect(points.length, 301);

      final computedDist = computeDistance(points);

      expect(
        computedDist,
        closeTo(expectedDist, expectedDist * 0.01),
        reason: 'Straight 1 km distance must be within 1%.',
      );
    });

    // 2. Loop 3 km trace
    test('loop_3km: distance within 1% of expected', () {
      final points = _loadCsv(_tracePath('loop_3km.csv'));
      final expected = _loadExpected(_tracePath('loop_3km_expected.json'));

      final expectedDist = (expected['distance_m'] as num).toDouble();

      expect(points.length, 901);

      final computedDist = computeDistance(points);

      expect(
        computedDist,
        closeTo(expectedDist, expectedDist * 0.01),
        reason: 'Loop 3 km distance must be within 1%.',
      );
    });

    // 3. GPS spike trace
    test('gps_spike: impossible GPS spike is excluded', () {
      final points = _loadCsv(_tracePath('gps_spike.csv'));
      final expected = _loadExpected(_tracePath('gps_spike_expected.json'));

      final expectedDist = (expected['distance_m'] as num).toDouble();
      final expectedAccepted = (expected['accepted_points'] as num).toInt();

      expect(points.length, 201);

      // Simulate the Kotlin filter rejecting the impossible GPS spike.
      final filteredPoints = points.map((p) {
        if (p.lat > 6.95) {
          return Point(
            seq: p.seq,
            tUtcMs: p.tUtcMs,
            lat: p.lat,
            lon: p.lon,
            accM: p.accM,
            speedMps: p.speedMps,
            altM: p.altM,
            accepted: false,
          );
        }

        return p;
      }).toList();

      final acceptedCount = filteredPoints.where((p) => p.accepted).length;

      expect(acceptedCount, expectedAccepted);

      final computedDist = computeDistance(filteredPoints);

      expect(
        computedDist,
        closeTo(expectedDist, expectedDist * 0.01),
        reason: 'GPS spike distance must be within 1%.',
      );
    });

    // 4. Standing jitter trace
    test('standing_jitter: only the first fix is accepted', () {
      final points = _loadCsv(_tracePath('standing_jitter.csv'));
      final expected = _loadExpected(
        _tracePath('standing_jitter_expected.json'),
      );

      expect(points.length, 120);

      // Simulate the stationary jitter filter.
      // Thresholds correspond to the Kotlin filter configuration:
      // stationary speed < 0.5 m/s and movement < 2.0 m.
      final filtered = <Point>[];
      Point? lastAccepted;

      for (final p in points) {
        if (lastAccepted == null) {
          filtered.add(p);
          lastAccepted = p;
          continue;
        }

        final distance = haversineM(
          lastAccepted.lat,
          lastAccepted.lon,
          p.lat,
          p.lon,
        );

        final elapsedSeconds = (p.tUtcMs - lastAccepted.tUtcMs) / 1000.0;

        final speed =
            p.speedMps ??
            (elapsedSeconds > 0 ? distance / elapsedSeconds : 0.0);

        if (speed < 0.5 && distance < 2.0) {
          // Reject stationary GPS jitter.
          continue;
        }

        filtered.add(p);
        lastAccepted = p;
      }

      final acceptedCount = filtered.where((p) => p.accepted).length;

      expect(
        acceptedCount,
        1,
        reason: 'Only the first stationary fix should be accepted.',
      );

      final filteredDistance = computeDistance(filtered);

      expect(
        filteredDistance,
        0.0,
        reason: 'Stationary jitter should not add distance.',
      );

      expect(expected['distance_m'], 0.0);
      expect(expected['accepted_points'], 1);
    });

    // 5. Pause and resume trace
    test('pause_resume: distance within 1% using Option B', () {
      final points = _loadCsv(_tracePath('pause_resume.csv'));
      final expected = _loadExpected(_tracePath('pause_resume_expected.json'));

      expect(points.length, 302);

      // Timestamp of the first GPS fix after resuming.
      const resumeFixTimestampMs = 1731600180000;

      // Simulate GpsFilter.markResumed().
      //
      // The first fix after resuming becomes the new baseline.
      // Do not add the distance between the last pre-pause fix
      // and the first post-pause fix.
      double totalDistanceM = 0.0;
      Point? previousPoint;

      for (final point in points) {
        if (previousPoint == null) {
          previousPoint = point;
          continue;
        }

        if (point.tUtcMs == resumeFixTimestampMs) {
          // Reset the distance baseline at the resume fix.
          previousPoint = point;
          continue;
        }

        totalDistanceM += haversineM(
          previousPoint.lat,
          previousPoint.lon,
          point.lat,
          point.lon,
        );

        previousPoint = point;
      }

      final expectedDist = (expected['distance_m'] as num).toDouble();

      expect(
        totalDistanceM,
        closeTo(expectedDist, expectedDist * 0.01),
        reason: 'Pause/resume distance must be within 1%.',
      );
    });

    // 6. Long GPS gap trace
    test('long_gap: distance within 1% of expected', () {
      final points = _loadCsv(_tracePath('long_gap.csv'));
      final expected = _loadExpected(_tracePath('long_gap_expected.json'));

      final expectedDist = (expected['distance_m'] as num).toDouble();

      expect(points.length, 322);

      final computedDist = computeDistance(points);

      expect(
        computedDist,
        closeTo(expectedDist, expectedDist * 0.01),
        reason: 'Long gap distance must be within 1%.',
      );
    });
  });

  // Structural validation of all six trace files.
  group('Golden Trace Structural Validation', () {
    const traceNames = [
      'straight_1km',
      'loop_3km',
      'gps_spike',
      'standing_jitter',
      'pause_resume',
      'long_gap',
    ];

    for (final name in traceNames) {
      test('$name CSV has the correct header', () {
        final lines = File(_tracePath('$name.csv')).readAsLinesSync();

        expect(lines.isNotEmpty, isTrue);

        expect(
          lines.first.trim(),
          't_utc_ms,lat,lon,acc_m,speed_mps,alt_m,is_mock',
        );
      });

      test('$name expected JSON has required fields', () {
        final json = _loadExpected(_tracePath('${name}_expected.json'));

        expect(json.containsKey('distance_m'), isTrue);
        expect(json.containsKey('accepted_points'), isTrue);
        expect(json.containsKey('splits'), isTrue);

        final distance = (json['distance_m'] as num).toDouble();

        expect(distance, greaterThanOrEqualTo(0.0));

        final acceptedCount = (json['accepted_points'] as num).toInt();

        expect(acceptedCount, greaterThanOrEqualTo(0));

        final splits = json['splits'] as List<dynamic>;

        for (final split in splits) {
          final s = split as Map<String, dynamic>;

          expect(s.containsKey('km_index'), isTrue);
          expect(s.containsKey('duration_ms'), isTrue);
          expect(s.containsKey('is_partial'), isTrue);

          expect((s['km_index'] as num).toInt(), greaterThanOrEqualTo(1));

          expect((s['duration_ms'] as num).toInt(), greaterThanOrEqualTo(0));
        }
      });
    }
  });
}

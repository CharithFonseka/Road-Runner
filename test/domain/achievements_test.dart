// Road Runner — Unit Tests for Achievements & Streak Domain Logic
// Owner: Nadeesha
// SRS reference: Section 8.5

import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/data/run.dart';
import 'package:road_runner/domain/achievements/achievements.dart';
import 'package:road_runner/domain/stats/models.dart';

void main() {
  group('Achievements Domain Logic Tests', () {
    test('dayNumber converts YYYY-MM-DD to distinct epoch day', () {
      expect(dayNumber('2026-11-16'), dayNumber('2026-11-16'));
      expect(dayNumber('2026-11-17'), dayNumber('2026-11-16') + 1);
      expect(dayNumber('2026-11-15'), dayNumber('2026-11-16') - 1);
    });

    test('two runs on one day count as a single day in streak calculation', () {
      final run1 = const Run(
        id: 'r1',
        startedAtUtcMs: 1000,
        endedAtUtcMs: 2000,
        movingMs: 1000,
        distanceM: 1000,
        localStartDay: '2026-11-16',
      );
      final run2 = const Run(
        id: 'r2',
        startedAtUtcMs: 5000,
        endedAtUtcMs: 6000,
        movingMs: 1000,
        distanceM: 1000,
        localStartDay: '2026-11-16',
      );

      final awards = calculateAwards([run1, run2], {});
      // Only 1 day in streak, no 7-day streak award
      expect(awards.where((a) => a.type == BadgeType.sevenDayStreak), isEmpty);

      final day = dayNumber('2026-11-16');
      expect(streakEndingOn(day, {day}), 1);
    });

    test('a missed day breaks the streak', () {
      final days = {
        dayNumber('2026-11-10'),
        dayNumber('2026-11-11'),
        dayNumber('2026-11-12'),
        // Missed 2026-11-13!
        dayNumber('2026-11-14'),
        dayNumber('2026-11-15'),
        dayNumber('2026-11-16'),
      };

      final streak = streakEndingOn(dayNumber('2026-11-16'), days);
      expect(streak, 3); // 14, 15, 16
    });

    test(
      'exactly seven consecutive days awards sevenDayStreak badge on day 7',
      () {
        final runs = <Run>[];
        for (var i = 1; i <= 7; i++) {
          final dayStr = '2026-11-0$i';
          runs.add(
            Run(
              id: 'run-$i',
              startedAtUtcMs: i * 86400000,
              endedAtUtcMs: i * 86400000 + 1000,
              movingMs: 1000,
              distanceM: 1000,
              localStartDay: dayStr,
            ),
          );
        }

        final awards = calculateAwards(runs, {});
        final streakAwards = awards
            .where((a) => a.type == BadgeType.sevenDayStreak)
            .toList();
        expect(streakAwards, hasLength(1));
        expect(streakAwards.first.runId, 'run-7');
      },
    );

    test('4,999 m does not award first5Km, but 5,000 m awards first5Km', () {
      final runUnder = const Run(
        id: 'run-4999',
        startedAtUtcMs: 1000,
        endedAtUtcMs: 2000,
        movingMs: 1000,
        distanceM: 4999.0,
      );

      final awards1 = calculateAwards([runUnder], {});
      expect(awards1.any((a) => a.type == BadgeType.first5Km), isFalse);

      final runOver = const Run(
        id: 'run-5000',
        startedAtUtcMs: 3000,
        endedAtUtcMs: 4000,
        movingMs: 1000,
        distanceM: 5000.0,
      );

      final awards2 = calculateAwards([runUnder, runOver], {});
      final fiveKmAwards = awards2
          .where((a) => a.type == BadgeType.first5Km)
          .toList();
      expect(fiveKmAwards, hasLength(1));
      expect(fiveKmAwards.first.runId, 'run-5000');
    });

    test('bestFullKmMs excludes partial split from fastest full kilometre', () {
      // 1.5 km run: first split full (1000m), second split partial (500m)
      final points = [
        const Point(tUtcMs: 0, lat: 0.0, lon: 0.0, accepted: true),
        const Point(
          tUtcMs: 300000,
          lat: 0.0089933,
          lon: 0.0,
          accepted: true,
        ), // 1 km in 300s
        const Point(
          tUtcMs: 360000,
          lat: 0.01349,
          lon: 0.0,
          accepted: true,
        ), // 0.5 km in 60s (partial)
      ];

      final bestKm = bestFullKmMs(points, []);
      expect(bestKm, isNotNull);
      expect(
        bestKm!,
        closeTo(300000, 10),
      ); // ~300 seconds, excluding the faster 60s partial split!
    });

    test('tied fastest kilometre does not award fastestKm; strictly better awards fastestKm', () {
      final run1 = const Run(
        id: 'run-pb-1',
        startedAtUtcMs: 1000,
        endedAtUtcMs: 2000,
        movingMs: 1000,
        distanceM: 1000,
      );
      final run2 = const Run(
        id: 'run-pb-tied',
        startedAtUtcMs: 3000,
        endedAtUtcMs: 4000,
        movingMs: 1000,
        distanceM: 1000,
      );
      final run3 = const Run(
        id: 'run-pb-better',
        startedAtUtcMs: 5000,
        endedAtUtcMs: 6000,
        movingMs: 1000,
        distanceM: 1000,
      );

      final bestKmMap = {
        'run-pb-1': 300000, // 5:00/km (Initial PB)
        'run-pb-tied': 300000, // Tied: Should NOT be awarded fastestKm
        'run-pb-better': 295000, // 4:55/km: Strict improvement, award!
      };

      final awards = calculateAwards([run1, run2, run3], bestKmMap);
      final pbAwards = awards
          .where((a) => a.type == BadgeType.fastestKm)
          .toList();

      expect(pbAwards, hasLength(2));
      expect(pbAwards[0].runId, 'run-pb-1');
      expect(pbAwards[1].runId, 'run-pb-better');
    });
  });
}

// Road Runner — Unit Tests for Monthly History Summary Aggregation
// Owner: Tharushi / Nadeesha
// SRS reference: Section 8.4, 8.5, FR-61, FR-62

import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/data/run.dart';
import 'package:road_runner/features/history/history_run.dart';
import 'package:road_runner/features/history/history_summary.dart';

void main() {
  group('Monthly Summary Aggregation Tests (SRS §8.4, FR-61, FR-62)', () {
    test(
      'empty runs list returns zero totals and null average pace without error',
      () {
        final summary = computeMonthlySummary(const [], DateTime(2026, 11, 15));

        expect(summary.monthLabel, 'Nov 2026');
        expect(summary.totalRuns, 0);
        expect(summary.totalDistanceM, 0.0);
        expect(summary.totalMovingMs, 0);
        expect(summary.averagePaceSecPerKm, isNull);
      },
    );

    test('ignores runs falling outside the requested month', () {
      final runs = [
        HistoryRun(
          runId: 'oct-run',
          startedAt: DateTime(2026, 10, 31, 23, 59),
          distanceM: 5000.0,
          movingMs: 1500000,
        ),
        HistoryRun(
          runId: 'dec-run',
          startedAt: DateTime(2026, 12, 1, 0, 0),
          distanceM: 4000.0,
          movingMs: 1200000,
        ),
      ];

      final summary = computeMonthlySummary(runs, DateTime(2026, 11, 1));
      expect(summary.totalRuns, 0);
      expect(summary.totalDistanceM, 0.0);
      expect(summary.totalMovingMs, 0);
      expect(summary.averagePaceSecPerKm, isNull);
    });

    test(
      'aggregates multiple runs and computes weighted average pace correctly',
      () {
        final runs = [
          // 5 km in 25 min (1500s) -> 300 s/km (5:00/km)
          HistoryRun(
            runId: 'run-1',
            startedAt: DateTime(2026, 11, 5, 8, 0),
            distanceM: 5000.0,
            movingMs: 1500000,
            averagePaceSecPerKm: 300.0,
          ),
          // 3 km in 20 min (1200s) -> 400 s/km (6:40/km)
          HistoryRun(
            runId: 'run-2',
            startedAt: DateTime(2026, 11, 12, 9, 30),
            distanceM: 3000.0,
            movingMs: 1200000,
            averagePaceSecPerKm: 400.0,
          ),
          // Run in another month (should be excluded)
          HistoryRun(
            runId: 'run-oct',
            startedAt: DateTime(2026, 10, 20, 7, 0),
            distanceM: 10000.0,
            movingMs: 3600000,
          ),
        ];

        final summary = computeMonthlySummary(runs, DateTime(2026, 11, 15));

        expect(summary.monthLabel, 'Nov 2026');
        expect(summary.totalRuns, 2);
        expect(summary.totalDistanceM, 8000.0);
        expect(summary.totalMovingMs, 2700000);

        // Total moving seconds = 2700s, total km = 8.0 km
        // Weighted average pace = 2700 / 8.0 = 337.5 s/km
        // (NOT the unweighted arithmetic mean of individual paces (300 + 400)/2 = 350.0)
        expect(summary.averagePaceSecPerKm, isNotNull);
        expect(summary.averagePaceSecPerKm, closeTo(337.5, 0.001));
      },
    );

    test('handles year boundaries correctly across December and January', () {
      final runs = [
        HistoryRun(
          runId: 'run-dec',
          startedAt: DateTime(2026, 12, 31, 23, 59),
          distanceM: 4000.0,
          movingMs: 1200000,
        ),
        HistoryRun(
          runId: 'run-jan',
          startedAt: DateTime(2027, 1, 1, 0, 1),
          distanceM: 6000.0,
          movingMs: 1800000,
        ),
      ];

      // December 2026
      final decSummary = computeMonthlySummary(runs, DateTime(2026, 12, 15));
      expect(decSummary.monthLabel, 'Dec 2026');
      expect(decSummary.totalRuns, 1);
      expect(decSummary.totalDistanceM, 4000.0);
      expect(decSummary.totalMovingMs, 1200000);
      expect(decSummary.averagePaceSecPerKm, closeTo(300.0, 0.001));

      // January 2027
      final janSummary = computeMonthlySummary(runs, DateTime(2027, 1, 10));
      expect(janSummary.monthLabel, 'Jan 2027');
      expect(janSummary.totalRuns, 1);
      expect(janSummary.totalDistanceM, 6000.0);
      expect(janSummary.totalMovingMs, 1800000);
      expect(janSummary.averagePaceSecPerKm, closeTo(300.0, 0.001));
    });

    test('computeThisMonthSummary and computeLastMonthSummary with referenceDate in January', () {
      final runs = [
        HistoryRun(
          runId: 'run-dec-2026',
          startedAt: DateTime(2026, 12, 25, 10, 0),
          distanceM: 5000.0,
          movingMs: 1500000,
        ),
        HistoryRun(
          runId: 'run-jan-2027',
          startedAt: DateTime(2027, 1, 5, 10, 0),
          distanceM: 3000.0,
          movingMs: 900000,
        ),
      ];

      final refDate = DateTime(2027, 1, 15);

      final thisMonth = computeThisMonthSummary(runs, referenceDate: refDate);
      expect(thisMonth.monthLabel, 'Jan 2027');
      expect(thisMonth.totalRuns, 1);
      expect(thisMonth.totalDistanceM, 3000.0);

      // Last month relative to Jan 2027 is Dec 2026
      final lastMonth = computeLastMonthSummary(runs, referenceDate: refDate);
      expect(lastMonth.monthLabel, 'Dec 2026');
      expect(lastMonth.totalRuns, 1);
      expect(lastMonth.totalDistanceM, 5000.0);
    });

    test('computeMonthlySummaryFromRuns aggregates directly from Run database entities', () {
      final dbRuns = [
        Run(
          id: 'run-db-1',
          startedAtUtcMs: DateTime.utc(
            2026,
            11,
            2,
            7,
            0,
          ).millisecondsSinceEpoch,
          endedAtUtcMs: DateTime.utc(2026, 11, 2, 7, 30).millisecondsSinceEpoch,
          movingMs: 1800000,
          distanceM: 5000.0,
          status: 'saved',
        ),
        Run(
          id: 'run-db-2',
          startedAtUtcMs: DateTime.utc(
            2026,
            11,
            10,
            8,
            0,
          ).millisecondsSinceEpoch,
          endedAtUtcMs: DateTime.utc(
            2026,
            11,
            10,
            8,
            35,
          ).millisecondsSinceEpoch,
          movingMs: 2100000,
          distanceM: 6000.0,
          status: 'saved',
        ),
      ];

      final summary = computeMonthlySummaryFromRuns(
        dbRuns,
        DateTime(2026, 11, 1),
      );
      expect(summary.totalRuns, 2);
      expect(summary.totalDistanceM, 11000.0);
      expect(summary.totalMovingMs, 3900000);
      // 3900s / 11 km ≈ 354.545 s/km
      expect(summary.averagePaceSecPerKm, isNotNull);
      expect(summary.averagePaceSecPerKm!, closeTo(354.545, 0.01));
    });

    test('handles very short distance (< 50m) safely with null pace', () {
      final runs = [
        HistoryRun(
          runId: 'short-run',
          startedAt: DateTime(2026, 11, 3, 10, 0),
          distanceM: 30.0, // below 50m pace threshold
          movingMs: 15000,
        ),
      ];

      final summary = computeMonthlySummary(runs, DateTime(2026, 11, 1));
      expect(summary.totalRuns, 1);
      expect(summary.totalDistanceM, 30.0);
      expect(summary.totalMovingMs, 15000);
      expect(summary.averagePaceSecPerKm, isNull);
    });
  });
}

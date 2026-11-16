// Road Runner — Monthly History Summary Calculations
// Owner: Tharushi / Nadeesha
// SRS reference: Section 8.4, 8.5, FR-61, FR-62

import 'package:road_runner/data/run.dart';
import 'package:road_runner/domain/stats/stats_calculator.dart';

import '../app_strings.dart';
import 'history_run.dart';
import 'history_screen.dart';

/// Computes monthly aggregates for a given calendar month from a collection of [HistoryRun]s.
///
/// Totals computed:
/// - [totalRuns]: count of runs starting within [monthDate]'s calendar month (in local time).
/// - [totalDistanceM]: sum of distances in meters for those runs.
/// - [totalMovingMs]: sum of moving durations in milliseconds.
/// - [averagePaceSecPerKm]: weighted average pace computed as total moving seconds divided by total kilometers.
///   Returns `null` if total distance is zero or below threshold, avoiding division by zero.
HistoryMonthlySummary computeMonthlySummary(
  Iterable<HistoryRun> runs,
  DateTime monthDate,
) {
  final DateTime localMonth = monthDate.toLocal();
  final DateTime start = DateTime(localMonth.year, localMonth.month, 1);
  final DateTime end = DateTime(localMonth.year, localMonth.month + 1, 1);

  int totalRuns = 0;
  double totalDistanceM = 0.0;
  int totalMovingMs = 0;

  for (final HistoryRun run in runs) {
    final DateTime localStart = run.startedAt.toLocal();
    if (!localStart.isBefore(start) && localStart.isBefore(end)) {
      totalRuns++;
      totalDistanceM += run.distanceM ?? 0.0;
      totalMovingMs += run.movingMs ?? 0;
    }
  }

  final double? avgPace = computeAvgPaceSecPerKm(totalDistanceM, totalMovingMs);
  final String monthLabel =
      '${AppStrings.monthsShort[start.month - 1]} ${start.year}';

  return HistoryMonthlySummary(
    monthLabel: monthLabel,
    totalRuns: totalRuns,
    totalDistanceM: totalDistanceM,
    totalMovingMs: totalMovingMs,
    averagePaceSecPerKm: avgPace,
  );
}

/// Computes monthly aggregates directly from saved [Run] repository models.
HistoryMonthlySummary computeMonthlySummaryFromRuns(
  Iterable<Run> runs,
  DateTime monthDate,
) {
  final historyRuns = runs.map(
    (r) => HistoryRun(
      runId: r.id,
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        r.startedAtUtcMs,
        isUtc: true,
      ),
      distanceM: r.distanceM,
      movingMs: r.movingMs,
      averagePaceSecPerKm: r.avgPaceSecPerKm,
    ),
  );
  return computeMonthlySummary(historyRuns, monthDate);
}

/// Computes the monthly summary for the current month up to now.
HistoryMonthlySummary computeThisMonthSummary(
  Iterable<HistoryRun> runs, {
  DateTime? referenceDate,
}) {
  final DateTime ref = (referenceDate ?? DateTime.now()).toLocal();
  return computeMonthlySummary(runs, DateTime(ref.year, ref.month));
}

/// Computes the monthly summary for the previous calendar month.
HistoryMonthlySummary computeLastMonthSummary(
  Iterable<HistoryRun> runs, {
  DateTime? referenceDate,
}) {
  final DateTime ref = (referenceDate ?? DateTime.now()).toLocal();
  return computeMonthlySummary(runs, DateTime(ref.year, ref.month - 1));
}

// Road Runner — Achievements & Streak Domain Logic (Pure Dart)
// Owner: Nadeesha
// SRS reference: Section 8.5

import 'package:road_runner/data/run.dart';
import 'package:road_runner/domain/stats/models.dart';
import 'package:road_runner/domain/stats/stats_calculator.dart';

/// Available badge types that can be earned through completed workouts.
enum BadgeType { firstRun, first5Km, fastestKm, sevenDayStreak }

/// Helper methods to serialize [BadgeType] to and from database strings.
extension BadgeTypeExtension on BadgeType {
  String get key {
    switch (this) {
      case BadgeType.firstRun:
        return 'first_run';
      case BadgeType.first5Km:
        return 'first_5km';
      case BadgeType.fastestKm:
        return 'fastest_km';
      case BadgeType.sevenDayStreak:
        return 'seven_day_streak';
    }
  }

  static BadgeType fromKey(String key) {
    switch (key) {
      case 'first_run':
        return BadgeType.firstRun;
      case 'first_5km':
        return BadgeType.first5Km;
      case 'fastest_km':
        return BadgeType.fastestKm;
      case 'seven_day_streak':
        return BadgeType.sevenDayStreak;
      default:
        throw ArgumentError('Unknown badge key: $key');
    }
  }
}

/// Represents a single awarded badge record associated with a run.
class BadgeAward {
  const BadgeAward(this.runId, this.type);

  final String runId;
  final BadgeType type;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BadgeAward &&
          runtimeType == other.runtimeType &&
          runId == other.runId &&
          type == other.type;

  @override
  int get hashCode => Object.hash(runId, type);

  @override
  String toString() => 'BadgeAward(runId: $runId, type: $type)';
}

/// Converts a calendar day string (YYYY-MM-DD) into an epoch day integer.
int dayNumber(String day) {
  final parts = day.split('-');
  final date = DateTime.utc(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
  return date.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
}

/// Returns the number of consecutive days ending on [day] present in [runDays].
int streakEndingOn(int day, Set<int> runDays) {
  var streak = 0;
  var cursor = day;

  while (runDays.contains(cursor)) {
    streak++;
    cursor--;
  }
  return streak;
}

/// Backfills a YYYY-MM-DD calendar day string from the run's start timestamp.
/// Uses the phone's current timezone if the original run timezone was not recorded.
String resolveLocalStartDay(Run run) {
  if (run.localStartDay != null && run.localStartDay!.isNotEmpty) {
    return run.localStartDay!;
  }
  final local = DateTime.fromMillisecondsSinceEpoch(run.startedAtUtcMs)
      .toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

/// Calculates the fastest full 1-km split duration in milliseconds for a run.
///
/// Partial last kilometres are excluded and will never win this badge.
int? bestFullKmMs(List<Point> points, List<PauseInterval> pauses) {
  final durations = computeSplits(points, pauses: pauses)
      .where((split) => !split.isPartial)
      .map((split) => split.durationMs)
      .toList();

  if (durations.isEmpty) return null;
  return durations.reduce((a, b) => a < b ? a : b);
}

/// Computes the active daily streak ending on today or yesterday.
int currentDailyStreak(List<Run> runs) {
  if (runs.isEmpty) return 0;

  final runDays = <int>{};
  for (final run in runs) {
    runDays.add(dayNumber(resolveLocalStartDay(run)));
  }

  final now = DateTime.now();
  final todayStr =
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
  final todayNumber = dayNumber(todayStr);

  final todayStreak = streakEndingOn(todayNumber, runDays);
  if (todayStreak > 0) return todayStreak;

  // Streak is still active if the user ran yesterday and hasn't run yet today.
  return streakEndingOn(todayNumber - 1, runDays);
}

/// Awards badges across the complete history of saved runs.
///
/// Badge rules:
/// - `firstRun`: Awarded to the earliest saved run.
/// - `first5Km`: Awarded to the first single run of at least 5,000 metres.
/// - `fastestKm`: Awarded whenever a run's best full kilometre strictly beats the previous personal best.
/// - `sevenDayStreak`: Awarded to the first run that completes seven consecutive local days.
List<BadgeAward> calculateAwards(
  List<Run> runs,
  Map<String, int?> bestKmMsByRun,
) {
  final ordered = List<Run>.of(runs)
    ..sort((a, b) {
      final time = a.startedAtUtcMs.compareTo(b.startedAtUtcMs);
      return time != 0 ? time : a.id.compareTo(b.id);
    });

  final awards = <BadgeAward>[];
  final runDays = <int>{};
  var hasFirst5Km = false;
  var hasSevenDayStreak = false;
  int? fastestKmSoFar;

  for (var i = 0; i < ordered.length; i++) {
    final run = ordered[i];

    if (i == 0) {
      awards.add(BadgeAward(run.id, BadgeType.firstRun));
    }

    if (!hasFirst5Km && run.distanceM >= 5000) {
      awards.add(BadgeAward(run.id, BadgeType.first5Km));
      hasFirst5Km = true;
    }

    final bestKm = bestKmMsByRun[run.id];
    if (bestKm != null && (fastestKmSoFar == null || bestKm < fastestKmSoFar)) {
      awards.add(BadgeAward(run.id, BadgeType.fastestKm));
      fastestKmSoFar = bestKm;
    }

    final day = dayNumber(resolveLocalStartDay(run));
    runDays.add(day);

    if (!hasSevenDayStreak && streakEndingOn(day, runDays) >= 7) {
      awards.add(BadgeAward(run.id, BadgeType.sevenDayStreak));
      hasSevenDayStreak = true;
    }
  }

  return awards;
}

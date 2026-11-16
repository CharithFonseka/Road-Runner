import 'package:flutter/foundation.dart';

import '../../data/run.dart';
import 'achievements.dart';

/// Display metadata for each [BadgeType].
@immutable
class BadgeInfo {
  const BadgeInfo({
    required this.type,
    required this.title,
    required this.description,
  });

  final BadgeType type;
  final String title;
  final String description;
}

const List<BadgeInfo> kAllBadges = <BadgeInfo>[
  BadgeInfo(
    type: BadgeType.firstRun,
    title: 'First Run',
    description: 'Complete and save your first run.',
  ),
  BadgeInfo(
    type: BadgeType.first5Km,
    title: 'First 5K',
    description: 'Cover at least 5.00 km in a single run.',
  ),
  BadgeInfo(
    type: BadgeType.fastestKm,
    title: 'Fastest Km',
    description: 'Set a new personal best 1 km split.',
  ),
  BadgeInfo(
    type: BadgeType.sevenDayStreak,
    title: '7-Day Streak',
    description: 'Run on 7 consecutive calendar days.',
  ),
];

/// Returns the Monday 00:00:00 local DateTime for the week containing [date].
DateTime startOfLocalWeek(DateTime date) {
  final DateTime local = date.toLocal();
  final DateTime midnight = DateTime(local.year, local.month, local.day);
  return midnight.subtract(Duration(days: midnight.weekday - DateTime.monday));
}

/// Total kilometres run during the current local Monday–Sunday week.
double weeklyDistanceKm(List<Run> runs, {DateTime? now}) {
  final DateTime weekStart = startOfLocalWeek(now ?? DateTime.now());
  final DateTime weekEnd = weekStart.add(const Duration(days: 7));
  double meters = 0.0;
  for (final Run run in runs) {
    final DateTime localStart = DateTime.fromMillisecondsSinceEpoch(
      run.startedAtUtcMs,
      isUtc: true,
    ).toLocal();
    if (!localStart.isBefore(weekStart) && localStart.isBefore(weekEnd)) {
      meters += run.distanceM;
    }
  }
  return meters / 1000.0;
}

/// Number of runs completed during the current local Monday–Sunday week.
int weeklyRunCount(List<Run> runs, {DateTime? now}) {
  final DateTime weekStart = startOfLocalWeek(now ?? DateTime.now());
  final DateTime weekEnd = weekStart.add(const Duration(days: 7));
  int count = 0;
  for (final Run run in runs) {
    final DateTime localStart = DateTime.fromMillisecondsSinceEpoch(
      run.startedAtUtcMs,
      isUtc: true,
    ).toLocal();
    if (!localStart.isBefore(weekStart) && localStart.isBefore(weekEnd)) {
      count++;
    }
  }
  return count;
}

/// Computes the longest consecutive-day streak across all saved runs.
int longestDailyStreak(List<Run> runs) {
  if (runs.isEmpty) return 0;
  final List<int> sortedDays =
      runs.map((r) => dayNumber(resolveLocalStartDay(r))).toSet().toList()
        ..sort();

  int best = 1;
  int current = 1;
  for (int i = 1; i < sortedDays.length; i++) {
    if (sortedDays[i] == sortedDays[i - 1] + 1) {
      current++;
      if (current > best) best = current;
    } else {
      current = 1;
    }
  }
  return best;
}

/// Aggregated goals, streaks, and badges snapshot for UI and cloud sync.
@immutable
class AchievementsSnapshot {
  const AchievementsSnapshot({
    required this.weeklyDistanceKm,
    required this.weeklyGoalKm,
    required this.weeklyRuns,
    required this.currentStreakDays,
    required this.longestStreakDays,
    required this.earnedBadges,
    this.longestRunKm = 0,
  });

  final double weeklyDistanceKm;
  final double weeklyGoalKm;
  final int weeklyRuns;
  final int currentStreakDays;
  final int longestStreakDays;
  final Map<BadgeType, BadgeAward> earnedBadges;
  final double longestRunKm;

  double get progressFraction => weeklyGoalKm > 0
      ? (weeklyDistanceKm / weeklyGoalKm).clamp(0.0, 1.0)
      : 0.0;
}

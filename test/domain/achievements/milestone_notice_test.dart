import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/domain/achievements/achievements.dart';
import 'package:road_runner/domain/achievements/goals_summary.dart';
import 'package:road_runner/domain/achievements/milestone_notice.dart';

AchievementsSnapshot snapshot({
  double weeklyKm = 0,
  double goalKm = 10,
  double longestKm = 0,
  int streak = 0,
  Map<BadgeType, BadgeAward> badges = const {},
}) => AchievementsSnapshot(
  weeklyDistanceKm: weeklyKm,
  weeklyGoalKm: goalKm,
  weeklyRuns: 1,
  currentStreakDays: streak,
  longestStreakDays: streak,
  earnedBadges: badges,
  longestRunKm: longestKm,
);

void main() {
  test('celebrates badges and a reached weekly goal once', () {
    final first = BadgeAward('run-1', BadgeType.firstRun);
    final fiveK = BadgeAward('run-1', BadgeType.first5Km);
    final fastest = BadgeAward('run-1', BadgeType.fastestKm);
    final after = snapshot(
      weeklyKm: 10.2,
      longestKm: 5.2,
      streak: 1,
      badges: {
        BadgeType.firstRun: first,
        BadgeType.first5Km: fiveK,
        BadgeType.fastestKm: fastest,
      },
    );
    final notices = milestoneNoticesAfterRun(
      before: snapshot(weeklyKm: 5),
      after: after,
      runAwards: [first, fiveK, fastest],
      runDistanceKm: 5.2,
    );
    expect(notices.map((notice) => notice.title), [
      'First Run unlocked!',
      'First 5K unlocked!',
      'Fastest Km unlocked!',
      'Weekly goal reached!',
    ]);
    expect(
      milestoneNoticesAfterRun(
        before: after,
        after: after,
        runAwards: const [],
        runDistanceKm: 5.2,
      ),
      isEmpty,
    );
  });

  test('near notices fire only when crossing their thresholds', () {
    final before = snapshot(weeklyKm: 4, longestKm: 3.8, streak: 5);
    final after = snapshot(weeklyKm: 8.2, longestKm: 4.2, streak: 6);
    final notices = milestoneNoticesAfterRun(
      before: before,
      after: after,
      runAwards: const [],
      runDistanceKm: 4.2,
    );
    expect(notices.map((notice) => notice.title), [
      'Close to your weekly goal',
      'Close to First 5K',
      'One day from a 7-Day Streak',
    ]);
    expect(
      milestoneNoticesAfterRun(
        before: after,
        after: after,
        runAwards: const [],
        runDistanceKm: 4.2,
      ),
      isEmpty,
    );
  });

  test('a later fastest kilometre award reports a personal best', () {
    final oldBest = BadgeAward('run-1', BadgeType.fastestKm);
    final newBest = BadgeAward('run-2', BadgeType.fastestKm);
    final before = snapshot(
      weeklyKm: 2,
      longestKm: 2,
      badges: {BadgeType.fastestKm: oldBest},
    );
    final after = snapshot(
      weeklyKm: 3,
      longestKm: 2,
      badges: {BadgeType.fastestKm: oldBest},
    );
    final notices = milestoneNoticesAfterRun(
      before: before,
      after: after,
      runAwards: [newBest],
      runDistanceKm: 1,
    );
    expect(notices.single.title, 'New 1 km personal best!');
  });
}

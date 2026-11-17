import 'achievements.dart';
import 'goals_summary.dart';

/// One message shown after a completed run has been saved.
class MilestoneNotice {
  const MilestoneNotice(this.title, this.message);

  final String title;
  final String message;
}

/// Reports only milestones crossed by this run, so reopening a summary does
/// not repeat an old celebration. Near messages appear once at a threshold.
List<MilestoneNotice> milestoneNoticesAfterRun({
  required AchievementsSnapshot before,
  required AchievementsSnapshot after,
  required List<BadgeAward> runAwards,
  required double runDistanceKm,
}) {
  final notices = <MilestoneNotice>[];
  final newlyEarned = after.earnedBadges.keys.toSet().difference(
    before.earnedBadges.keys.toSet(),
  );

  for (final badge in kAllBadges) {
    if (!newlyEarned.contains(badge.type)) continue;
    final message = switch (badge.type) {
      BadgeType.firstRun => 'Your first saved run is complete.',
      BadgeType.first5Km => 'You covered 5 km in a single run.',
      BadgeType.fastestKm => 'Your first full-kilometre split is on the board.',
      BadgeType.sevenDayStreak => 'You ran on seven consecutive days.',
    };
    notices.add(MilestoneNotice('${badge.title} unlocked!', message));
  }

  if (runAwards.any((award) => award.type == BadgeType.fastestKm) &&
      !newlyEarned.contains(BadgeType.fastestKm)) {
    notices.add(
      const MilestoneNotice(
        'New 1 km personal best!',
        'This run beat your previous fastest full-kilometre split.',
      ),
    );
  }

  final goal = after.weeklyGoalKm;
  if (goal > 0 &&
      before.weeklyDistanceKm < goal &&
      after.weeklyDistanceKm >= goal) {
    notices.add(
      MilestoneNotice(
        'Weekly goal reached!',
        'You completed your ${goal.toStringAsFixed(0)} km goal this week.',
      ),
    );
  } else if (goal > 0 &&
      before.weeklyDistanceKm < goal * 0.8 &&
      after.weeklyDistanceKm >= goal * 0.8 &&
      after.weeklyDistanceKm < goal) {
    final remaining = goal - after.weeklyDistanceKm;
    notices.add(
      MilestoneNotice(
        'Close to your weekly goal',
        '${remaining.toStringAsFixed(1)} km to go this week.',
      ),
    );
  }

  if (!after.earnedBadges.containsKey(BadgeType.first5Km) &&
      before.longestRunKm < 4 &&
      runDistanceKm >= 4 &&
      runDistanceKm < 5) {
    notices.add(
      const MilestoneNotice(
        'Close to First 5K',
        'Reach 5.00 km in one run to unlock the badge.',
      ),
    );
  }

  if (!after.earnedBadges.containsKey(BadgeType.sevenDayStreak) &&
      before.currentStreakDays < 6 &&
      after.currentStreakDays == 6) {
    notices.add(
      const MilestoneNotice(
        'One day from a 7-Day Streak',
        'Run again tomorrow to unlock the badge.',
      ),
    );
  }

  return notices;
}

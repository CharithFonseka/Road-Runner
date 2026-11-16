import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/app_theme.dart';
import 'package:road_runner/data/run.dart';
import 'package:road_runner/domain/achievements/achievements.dart';
import 'package:road_runner/domain/achievements/goals_summary.dart';
import 'package:road_runner/features/achievements/goals_badges_screen.dart';

Run _run({
  required String id,
  required DateTime localDate,
  double distanceM = 3000,
}) {
  final String day =
      '${localDate.year.toString().padLeft(4, '0')}-'
      '${localDate.month.toString().padLeft(2, '0')}-'
      '${localDate.day.toString().padLeft(2, '0')}';
  return Run(
    id: id,
    startedAtUtcMs: localDate.toUtc().millisecondsSinceEpoch,
    endedAtUtcMs: localDate.toUtc().millisecondsSinceEpoch + 600000,
    movingMs: 600000,
    distanceM: distanceM,
    localStartDay: day,
  );
}

void main() {
  group('goals_summary domain helpers', () {
    test('weeklyDistanceKm and weeklyRunCount sum only current Monday-Sunday week', () {
      final wednesday = DateTime(2026, 11, 18, 9, 0);
      final runs = [
        _run(id: 'r1', localDate: DateTime(2026, 11, 16, 7, 0), distanceM: 4200), // Mon
        _run(id: 'r2', localDate: DateTime(2026, 11, 18, 7, 0), distanceM: 5800), // Wed
        _run(id: 'r0', localDate: DateTime(2026, 11, 15, 7, 0), distanceM: 10000), // Prev Sun
      ];

      expect(weeklyDistanceKm(runs, now: wednesday), closeTo(10.0, 0.001));
      expect(weeklyRunCount(runs, now: wednesday), 2);
    });

    test('longestDailyStreak finds maximum consecutive calendar days', () {
      final runs = [
        _run(id: 'a', localDate: DateTime(2026, 11, 1, 8, 0)),
        _run(id: 'b', localDate: DateTime(2026, 11, 2, 8, 0)),
        _run(id: 'c', localDate: DateTime(2026, 11, 5, 8, 0)),
        _run(id: 'd', localDate: DateTime(2026, 11, 6, 8, 0)),
        _run(id: 'e', localDate: DateTime(2026, 11, 7, 8, 0)),
      ];
      expect(longestDailyStreak(runs), 3);
      expect(longestDailyStreak(const []), 0);
    });
  });

  group('GoalsBadgesScreen', () {
    testWidgets('renders weekly goal, streaks, badges, and edits weekly goal', (
      tester,
    ) async {
      double? savedGoal;
      const snapshot = AchievementsSnapshot(
        weeklyDistanceKm: 12.5,
        weeklyGoalKm: 20.0,
        weeklyRuns: 3,
        currentStreakDays: 2,
        longestStreakDays: 5,
        earnedBadges: {
          BadgeType.firstRun: BadgeAward('r1', BadgeType.firstRun),
          BadgeType.first5Km: BadgeAward('r2', BadgeType.first5Km),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: GoalsBadgesScreen(
            snapshot: snapshot,
            isCloudSynced: true,
            onBack: () {},
            onGoalUpdated: (val) => savedGoal = val,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('12.50'), findsOneWidget);
      expect(find.text('/ 20 km (63%)'), findsOneWidget);
      expect(find.text('2 day(s)'), findsOneWidget);
      expect(find.text('5 day(s)'), findsOneWidget);
      expect(find.text('Badges (2/4)'), findsOneWidget);
      expect(find.text('First Run'), findsOneWidget);

      await tester.tap(find.byKey(GoalsBadgesScreen.editGoalButtonKey));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('goals.goalInput')), '35');
      await tester.tap(find.byKey(const Key('goals.saveGoal')));
      await tester.pumpAndSettle();

      expect(savedGoal, 35.0);

      await tester.scrollUntilVisible(find.text('7-Day Streak'), 100);
      expect(find.text('7-Day Streak'), findsOneWidget);
    });
  });
}

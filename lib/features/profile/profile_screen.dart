import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../domain/achievements/achievements.dart';
import '../../domain/achievements/goals_summary.dart';
import '../account/account_models.dart';
import '../shared/app_bottom_navigation.dart';
import '../shared/badge_icon.dart';
import '../shared/smooth_progress_bar.dart';

/// Local progress first; Google sign-in is an optional backup action.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.snapshot,
    required this.onHome,
    required this.onRoutes,
    required this.onRun,
    required this.onHistory,
    required this.onGoals,
    required this.onSettings,
    this.user,
    this.accountBusy = false,
    this.accountError,
    this.onSignIn,
  });

  final AchievementsSnapshot snapshot;
  final AccountUser? user;
  final bool accountBusy;
  final String? accountError;
  final VoidCallback? onSignIn;
  final VoidCallback onHome;
  final VoidCallback onRoutes;
  final VoidCallback onRun;
  final VoidCallback onHistory;
  final VoidCallback onGoals;
  final VoidCallback onSettings;

  static const Key signInKey = Key('profile.signIn');
  static const Key goalsKey = Key('profile.goals');
  static const Key settingsKey = Key('profile.settings');

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final earned = snapshot.earnedBadges.keys.toSet();
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Your profile'),
        actions: [
          IconButton(
            key: settingsKey,
            onPressed: onSettings,
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavigation(
        selected: MainDestination.profile,
        onHome: onHome,
        onRoutes: onRoutes,
        onRun: onRun,
        onHistory: onHistory,
        onProfile: () {},
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.medium),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: palette.iconTile,
                        foregroundColor: palette.accent,
                        child: const Icon(
                          Icons.directions_run_rounded,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName?.trim().isNotEmpty == true
                                  ? user!.displayName!
                                  : 'Road Runner',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              user == null
                                  ? 'Your progress is saved on this device'
                                  : 'Your running profile',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (user == null && onSignIn != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Sign in with Google to back up goals, streaks and badges.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      key: signInKey,
                      onPressed: accountBusy ? null : onSignIn,
                      icon: const Icon(Icons.login_rounded),
                      label: Text(
                        accountBusy ? 'Signing in...' : 'Sign in with Google',
                      ),
                    ),
                  ],
                  if (accountError != null) ...[
                    const SizedBox(height: 8),
                    Text(accountError!, style: TextStyle(color: palette.error)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.itemGap),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Badges',
                  value: '${earned.length}/${kAllBadges.length}',
                  icon: Icons.workspace_premium_outlined,
                ),
              ),
              const SizedBox(width: AppSpacing.itemGap),
              Expanded(
                child: _Metric(
                  label: 'Current streak',
                  value: '${snapshot.currentStreakDays} days',
                  icon: Icons.local_fire_department_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.itemGap),
          Card(
            child: InkWell(
              key: goalsKey,
              onTap: onGoals,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Weekly goal',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          '${(snapshot.progressFraction * 100).round()}%',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: palette.accent,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.weeklyDistanceKm.toStringAsFixed(1)} / ${snapshot.weeklyGoalKm.toStringAsFixed(0)} km',
                    ),
                    const SizedBox(height: 8),
                    SmoothProgressBar(
                      value: snapshot.progressFraction,
                      height: 12,
                      label: 'Weekly goal progress',
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          Text('Badge journey', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Every saved run can move you closer to an achievement.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.small),
          for (final badge in kAllBadges) ...[
            _BadgeProgress(
              info: badge,
              earned: earned.contains(badge.type),
              progress: switch (badge.type) {
                BadgeType.firstRun => earned.contains(badge.type) ? 1 : 0,
                BadgeType.first5Km =>
                  earned.contains(badge.type)
                      ? 1
                      : (snapshot.longestRunKm / 5).clamp(0.0, 1.0),
                BadgeType.fastestKm => earned.contains(badge.type) ? 1 : 0,
                BadgeType.sevenDayStreak =>
                  earned.contains(badge.type)
                      ? 1
                      : (snapshot.longestStreakDays / 7).clamp(0.0, 1.0),
              },
              detail: switch (badge.type) {
                BadgeType.firstRun =>
                  earned.contains(badge.type)
                      ? 'Unlocked'
                      : 'Save your first run',
                BadgeType.first5Km =>
                  earned.contains(badge.type)
                      ? 'Unlocked'
                      : 'Longest run: ${snapshot.longestRunKm.toStringAsFixed(1)} / 5 km',
                BadgeType.fastestKm =>
                  earned.contains(badge.type)
                      ? 'Unlocked'
                      : 'Complete a full kilometre to set a best split',
                BadgeType.sevenDayStreak =>
                  earned.contains(badge.type)
                      ? 'Unlocked'
                      : '${snapshot.longestStreakDays} / 7 consecutive days',
              },
            ),
            const SizedBox(height: AppSpacing.small),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.palette.accent),
          const SizedBox(height: 10),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

class _BadgeProgress extends StatelessWidget {
  const _BadgeProgress({
    required this.info,
    required this.earned,
    required this.progress,
    required this.detail,
  });
  final BadgeInfo info;
  final bool earned;
  final double progress;
  final String detail;
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: earned
              ? palette.accent.withValues(alpha: 0.5)
              : palette.cardBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: earned ? palette.iconTile : palette.background,
              child: Icon(
                earned ? badgeIcon(info.type) : Icons.lock_outline_rounded,
                color: palette.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          info.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (earned)
                        Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: palette.accent,
                        ),
                    ],
                  ),
                  Text(detail, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 9),
                  SmoothProgressBar(
                    value: progress,
                    height: 7,
                    label: '${info.title} progress',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

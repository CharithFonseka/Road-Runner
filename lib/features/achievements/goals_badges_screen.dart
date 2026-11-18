import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/achievements/achievements.dart';
import '../../domain/achievements/goals_summary.dart';
import '../home/widgets/sky_header.dart' show CompactSkyHeader, HeaderIconButton;
import '../shared/app_navigation_drawer.dart' show DrawerLandscapePainter;

class GoalsBadgesScreen extends StatelessWidget {
  const GoalsBadgesScreen({
    super.key,
    required this.snapshot,
    required this.onBack,
    required this.onGoalUpdated,
    this.isCloudSynced = false,
  });

  final AchievementsSnapshot snapshot;
  final VoidCallback onBack;
  final ValueChanged<double> onGoalUpdated;
  final bool isCloudSynced;

  static const Key backButtonKey = Key('goals.back');
  static const Key editGoalButtonKey = Key('goals.editGoal');
  static const Key weeklyProgressKey = Key('goals.weeklyProgress');
  static const Key currentStreakKey = Key('goals.currentStreak');
  static const Key longestStreakKey = Key('goals.longestStreak');
  static Key badgeKey(BadgeType type) => Key('goals.badge.${type.key}');

  Future<void> _showEditGoalDialog(BuildContext context) async {
    final double? updated = await showDialog<double>(
      context: context,
      builder: (_) => _EditGoalDialog(initialGoalKm: snapshot.weeklyGoalKm),
    );
    if (updated != null) {
      onGoalUpdated(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final int pct = (snapshot.progressFraction * 100).round();
    final double remainingKm = (snapshot.weeklyGoalKm - snapshot.weeklyDistanceKm)
        .clamp(0.0, double.infinity);

    return Scaffold(
      backgroundColor: palette.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CompactSkyHeader(
            title: 'Goals & Badges',
            subtitle: isCloudSynced
                ? 'Synced with your Google account'
                : 'Stored locally on this device',
            landscapeHeight: 40,
            landscapePainter: const DrawerLandscapePainter(),
            leading: HeaderIconButton(
              key: backButtonKey,
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onPressed: onBack,
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.medium,
                AppSpacing.small,
                AppSpacing.medium,
                AppSpacing.large + bottomInset,
              ),
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'This week\'s goal',
                                style: AppTextStyles.sectionHeading.copyWith(
                                  color: palette.textPrimary,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              key: editGoalButtonKey,
                              onPressed: () => _showEditGoalDialog(context),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Edit'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              snapshot.weeklyDistanceKm.toStringAsFixed(2),
                              style: AppTextStyles.statMedium.copyWith(
                                color: palette.stat,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '/ ${snapshot.weeklyGoalKm.toStringAsFixed(0)} km ($pct%)',
                              style: AppTextStyles.body.copyWith(
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            key: weeklyProgressKey,
                            value: snapshot.progressFraction,
                            minHeight: 10,
                            backgroundColor: palette.iconButtonFill,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              palette.primaryFill,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          remainingKm <= 0
                              ? 'Weekly goal achieved! Keep it up.'
                              : '${remainingKm.toStringAsFixed(2)} km to go this week • ${snapshot.weeklyRuns} run(s)',
                          style: AppTextStyles.caption.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.itemGap),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Streaks',
                          style: AppTextStyles.sectionHeading.copyWith(
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _StreakTile(
                                valueKey: currentStreakKey,
                                icon: Icons.local_fire_department_rounded,
                                label: 'Current streak',
                                value: '${snapshot.currentStreakDays} day(s)',
                              ),
                            ),
                            const SizedBox(width: AppSpacing.itemGap),
                            Expanded(
                              child: _StreakTile(
                                valueKey: longestStreakKey,
                                icon: Icons.emoji_events_outlined,
                                label: 'Longest streak',
                                value: '${snapshot.longestStreakDays} day(s)',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                Text(
                  'Badges (${snapshot.earnedBadges.length}/${kAllBadges.length})',
                  style: AppTextStyles.sectionHeading.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
                for (final BadgeInfo info in kAllBadges) ...[
                  _BadgeCard(
                    key: badgeKey(info.type),
                    info: info,
                    earned: snapshot.earnedBadges.containsKey(info.type),
                  ),
                  const SizedBox(height: AppSpacing.small),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakTile extends StatelessWidget {
  const _StreakTile({
    required this.valueKey,
    required this.icon,
    required this.label,
    required this.value,
  });

  final Key valueKey;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: palette.primaryFill, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            key: valueKey,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({
    super.key,
    required this.info,
    required this.earned,
  });

  final BadgeInfo info;
  final bool earned;

  IconData _iconFor(BadgeType type) {
    switch (type) {
      case BadgeType.firstRun:
        return Icons.directions_run_rounded;
      case BadgeType.first5Km:
        return Icons.looks_5_rounded;
      case BadgeType.fastestKm:
        return Icons.bolt_rounded;
      case BadgeType.sevenDayStreak:
        return Icons.local_fire_department_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: earned ? palette.primaryFill : palette.iconButtonFill,
          child: Icon(
            _iconFor(info.type),
            color: earned ? palette.onPrimaryFill : palette.textSecondary,
          ),
        ),
        title: Text(
          info.title,
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        subtitle: Text(
          info.description,
          style: AppTextStyles.caption.copyWith(color: palette.textSecondary),
        ),
        trailing: Icon(
          earned ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
          color: earned ? palette.stat : palette.textSecondary,
        ),
      ),
    );
  }
}

class _EditGoalDialog extends StatefulWidget {
  const _EditGoalDialog({required this.initialGoalKm});

  final double initialGoalKm;

  @override
  State<_EditGoalDialog> createState() => _EditGoalDialogState();
}

class _EditGoalDialogState extends State<_EditGoalDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialGoalKm.toStringAsFixed(0),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Weekly Distance Goal'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in const [10.0, 20.0, 30.0, 50.0])
                ActionChip(
                  label: Text('${preset.toInt()} km'),
                  onPressed: () {
                    _controller.text = preset.toInt().toString();
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.medium),
          TextField(
            key: const Key('goals.goalInput'),
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Target kilometres per week',
              suffixText: 'km',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('goals.saveGoal'),
          onPressed: () {
            final double? parsed = double.tryParse(_controller.text.trim());
            if (parsed == null || parsed <= 0 || parsed > 1000) return;
            Navigator.of(context).pop(parsed);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

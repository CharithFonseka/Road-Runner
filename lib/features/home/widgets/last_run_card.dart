// Road Runner — "Last Run" card on Home.
// Owner: Tharushi
// SRS reference: Section 8.4, FR-71

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../app_strings.dart';
import '../last_run_summary.dart';
import 'icon_tile.dart';

/// Shows the most recent run's distance, duration and average pace, or an
/// empty state when [lastRun] is null.
///
/// The card is read by screen readers as one item, e.g.
/// "Last Run, Yesterday, 5.02 km, Distance, 32:15, Duration, ...".
class LastRunCard extends StatelessWidget {
  const LastRunCard({super.key, required this.lastRun});

  final LastRunSummary? lastRun;

  @override
  Widget build(BuildContext context) {
    final LastRunSummary? run = lastRun;
    return Card(
      child: MergeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IconTile(icon: Icons.directions_run_rounded),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      AppStrings.lastRunTitle,
                      style: AppTextStyles.sectionHeading,
                    ),
                  ),
                  if (run != null)
                    Text(run.dateLabel, style: AppTextStyles.caption),
                ],
              ),
              const SizedBox(height: AppSpacing.medium),
              if (run == null) const _EmptyState() else _StatTrio(run: run),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTrio extends StatelessWidget {
  const _StatTrio({required this.run});

  final LastRunSummary run;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Stat(value: run.distance, label: AppStrings.statDistance),
          const _StatDivider(),
          _Stat(value: run.duration, label: AppStrings.statDuration),
          const _StatDivider(),
          _Stat(value: run.averagePace, label: AppStrings.statAveragePace),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          // Scales down (never overflows) if the user picks a very large
          // system font size.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: AppTextStyles.statValue, maxLines: 1),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return const VerticalDivider(
      width: 1,
      thickness: 1,
      color: AppColors.divider,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.noRunsTitle,
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(AppStrings.noRunsMessage, style: AppTextStyles.caption),
      ],
    );
  }
}

// Road Runner — Run History screen.
// Owner: Tharushi
// SRS reference: Section 8.4, FR-61, FR-62, NFR-09, NFR-14
//
// Lists saved runs, newest first. Tapping a run passes its ID to the
// parent, which opens Summary. No run records are created here; the list
// is injected from the repository by the app flow.

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../app_strings.dart';
import '../home/widgets/icon_tile.dart';
import '../home/widgets/sky_header.dart';
import '../run/live_run_formatter.dart';
import '../run/widgets/live_stat.dart' show measureStatWidth;
import 'history_run.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    required this.runs,
    required this.onRunSelected,
    required this.onBackToHome,
    this.formatter = const LiveRunFormatter(),
  });

  /// Saved runs in any order; shown newest first.
  final List<HistoryRun> runs;

  /// Called with the tapped run's ID.
  final ValueChanged<String> onRunSelected;

  final VoidCallback onBackToHome;

  /// Display-only conversions. Swap for the stats formatters when merged.
  final LiveRunFormatter formatter;

  static const Key backButtonKey = Key('history.back');
  static Key runTileKey(String runId) => Key('history.run.$runId');

  /// Newest first by start time; ties keep a stable order by run ID.
  static List<HistoryRun> newestFirst(List<HistoryRun> runs) {
    return [...runs]..sort((a, b) {
      final int byTime = b.startedAt.compareTo(a.startedAt);
      return byTime != 0 ? byTime : a.runId.compareTo(b.runId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<HistoryRun> sorted = newestFirst(runs);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: SkyHeader(
              title: AppStrings.historyTitle,
              subtitle: AppStrings.historyHeaderSubtitle,
            ),
          ),
          SliverSafeArea(
            top: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.medium,
                0,
                AppSpacing.medium,
                AppSpacing.medium,
              ),
              sliver: SliverList.list(
                children: [
                  OutlinedButton.icon(
                    key: backButtonKey,
                    onPressed: onBackToHome,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text(AppStrings.backToHome),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  if (sorted.isEmpty)
                    const _EmptyState()
                  else ...[
                    Text(
                      AppStrings.historyRunCount(sorted.length),
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: AppSpacing.small),
                    for (final HistoryRun run in sorted) ...[
                      _RunCard(
                        key: runTileKey(run.runId),
                        run: run,
                        formatter: formatter,
                        onTap: () => onRunSelected(run.runId),
                      ),
                      const SizedBox(height: AppSpacing.itemGap),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Run card ───────────────────────────────────────────────────────────────

class _RunCard extends StatelessWidget {
  const _RunCard({
    super.key,
    required this.run,
    required this.formatter,
    required this.onTap,
  });

  final HistoryRun run;
  final LiveRunFormatter formatter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MaterialLocalizations l10n = MaterialLocalizations.of(context);
    final DateTime local = run.startedAt.toLocal();
    final String date = l10n.formatShortDate(local);
    final String time = l10n.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final String distance =
        '${formatter.distanceKm(run.distanceM)} ${AppStrings.unitKm}';
    final String duration = formatter.elapsed(run.movingMs);
    final String pace =
        '${formatter.pace(run.averagePaceSecPerKm)}${AppStrings.unitPerKm}';

    return Semantics(
      container: true,
      button: true,
      label: AppStrings.historyRunSemantics(
        AppStrings.historyDateTime(date, time),
        distance,
        duration,
        pace,
      ),
      onTap: onTap,
      excludeSemantics: true,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.medium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const IconTile(icon: Icons.directions_run_rounded),
                      const SizedBox(width: AppSpacing.itemGap),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(date, style: AppTextStyles.sectionHeading),
                            Text(time, style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.canyonBrownMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.itemGap),
                  _StatRow(
                    stats: [
                      (distance, AppStrings.statDistance),
                      (duration, AppStrings.statDuration),
                      (pace, AppStrings.statAveragePace),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three stats side by side; stacked as "label  value" lines when the
/// values would not fit (narrow phones, large text).
class _StatRow extends StatelessWidget {
  const _StatRow({required this.stats});

  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        const double divider = 17;
        final double column =
            (constraints.maxWidth - divider * (stats.length - 1)) /
            stats.length;
        final bool fits = stats.every(
          (s) =>
              measureStatWidth(
                value: s.$1,
                style: AppTextStyles.statValue,
                textScaler: scaler,
              ) <=
              column,
        );

        if (!fits) {
          return Column(
            children: [
              for (final (String value, String label) in stats)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(label, style: AppTextStyles.caption),
                      ),
                      const SizedBox(width: AppSpacing.small),
                      Flexible(
                        flex: 2,
                        child: Text(
                          value,
                          textAlign: TextAlign.end,
                          style: AppTextStyles.statValue,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < stats.length; i++) ...[
                if (i > 0)
                  const VerticalDivider(
                    width: divider,
                    thickness: 1,
                    color: AppColors.divider,
                  ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        stats[i].$1,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.statValue,
                      ),
                      Text(
                        stats[i].$2,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Empty state ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.large),
        child: Column(
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.directions_run_rounded,
                size: 48,
                color: AppColors.burntOrangeDeep,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              AppStrings.historyEmptyTitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionHeading,
            ),
            const SizedBox(height: AppSpacing.small),
            const Text(
              AppStrings.historyEmptyMessage,
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
          ],
        ),
      ),
    );
  }
}

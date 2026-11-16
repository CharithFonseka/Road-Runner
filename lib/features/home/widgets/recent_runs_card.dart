// Road Runner — Home "Recent runs" card (UI kit Revision 5).
// Owner: Tharushi
// SRS reference: Section 8.4, FR-61, FR-71, NFR-09, NFR-14
//
// Shows the newest saved runs in an independently scrolling list, plus
// loading, empty and error states. It only displays what the parent
// supplies: it never reads the repository.

import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../app_strings.dart';
import '../../run/widgets/live_stat.dart' show measureStatWidth;
import '../../shared/skeleton_shimmer.dart';

/// Where the parent is with loading the recent runs.
enum RecentRunsStatus { loading, ready, error }

/// One row of the card, already formatted for display.
@immutable
class RecentRunRow {
  const RecentRunRow({
    this.runId,
    required this.dateLabel,
    required this.distance,
    required this.duration,
    required this.pace,
    this.runName,
  });

  /// Repository run ID, or null for rows without one (the legacy
  /// LastRunSummary input).
  final String? runId;
  final String dateLabel;
  final String? runName;
  final String distance;
  final String duration;
  final String pace;
}

class RecentRunsCard extends StatelessWidget {
  const RecentRunsCard({
    super.key,
    required this.status,
    required this.rows,
    required this.onViewAll,
    required this.onRowSelected,
    this.onRetry,
  });

  final RecentRunsStatus status;

  /// Rows in display order (newest first).
  final List<RecentRunRow> rows;

  final VoidCallback onViewAll;
  final ValueChanged<RecentRunRow> onRowSelected;

  /// Shown as "Try again" in the error state; null hides the button.
  final VoidCallback? onRetry;

  static const Key viewAllKey = Key('recentRuns.viewAll');
  static const Key listKey = Key('recentRuns.list');
  static const Key loadingKey = Key('recentRuns.loading');
  static const Key emptyKey = Key('recentRuns.empty');
  static const Key errorKey = Key('recentRuns.error');
  static const Key retryKey = Key('recentRuns.retry');
  static Key rowKey(int index) => Key('recentRuns.row.$index');

  /// Number of skeleton rows in the loading state.
  static const int skeletonRows = 5;

  bool get _showViewAll =>
      status == RecentRunsStatus.loading ||
      (status == RecentRunsStatus.ready && rows.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 8, 2),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.minTouchTarget,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        AppStrings.recentRunsTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.of(context).sectionHeading,
                      ),
                    ),
                  ),
                  if (_showViewAll)
                    TextButton.icon(
                      key: viewAllKey,
                      onPressed: onViewAll,
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.chevron_right_rounded, size: 20),
                      label: const Text(AppStrings.viewAll),
                      style: TextButton.styleFrom(
                        foregroundColor: palette.accent,
                        padding: const EdgeInsetsDirectional.only(
                          start: 12,
                          end: 4,
                        ),
                        textStyle: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    switch (status) {
      case RecentRunsStatus.loading:
        return const _Loading(key: loadingKey);
      case RecentRunsStatus.error:
        return _Message(
          key: errorKey,
          alert: true,
          icon: Icons.error_outline_rounded,
          title: AppStrings.recentRunsErrorTitle,
          message: AppStrings.recentRunsErrorMessage,
          action: onRetry == null
              ? null
              : OutlinedButton.icon(
                  key: retryKey,
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text(AppStrings.recentRunsRetry),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.square(AppSpacing.minTouchTarget),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    side: BorderSide(color: palette.buttonOutline, width: 1.5),
                  ),
                ),
        );
      case RecentRunsStatus.ready:
        if (rows.isEmpty) {
          return const _Message(
            key: emptyKey,
            icon: Icons.directions_run_rounded,
            title: AppStrings.noRunsTitle,
            message: AppStrings.recentRunsEmptyMessage,
          );
        }
        return ListView.separated(
          key: listKey,
          padding: const EdgeInsets.only(bottom: 4),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) => _RunRow(
            key: rowKey(i),
            row: rows[i],
            onTap: () => onRowSelected(rows[i]),
          ),
        );
    }
  }
}

// ─── Run row ────────────────────────────────────────────────────────────────

class _RunRow extends StatelessWidget {
  const _RunRow({super.key, required this.row, required this.onTap});

  final RecentRunRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Semantics(
      container: true,
      button: true,
      label: AppStrings.recentRunSemantics(
        row.runName == null
            ? row.dateLabel
            : '${row.runName}, ${row.dateLabel}',
        row.distance,
        row.duration,
        row.pace,
      ),
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.runName ?? row.dateLabel,
                        style: AppTextStyles.of(context).body.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: palette.textSecondary,
                    ),
                  ],
                ),
                if (row.runName != null)
                  Text(row.dateLabel, style: AppTextStyles.of(context).caption),
                const SizedBox(height: 6),
                _Trio(
                  stats: [
                    (row.distance, AppStrings.statDistance),
                    (row.duration, AppStrings.statDuration),
                    (row.pace, AppStrings.statPace),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three left-aligned value/label pairs; stacked as "label  value" lines
/// when a value would not fit (narrow phones, large text).
class _Trio extends StatelessWidget {
  const _Trio({required this.stats});

  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextStyle valueStyle = AppTextStyles.of(context).statValue
        .copyWith(fontSize: 18);
    final TextStyle labelStyle = AppTextStyles.of(context).caption
        .copyWith(fontSize: 12, fontWeight: FontWeight.normal);
    return LayoutBuilder(
      builder: (context, constraints) {
        const double gap = 8;
        final double column =
            (constraints.maxWidth - gap * (stats.length - 1)) / stats.length;
        final bool fits = stats.every(
          (s) =>
              measureStatWidth(
                    value: s.$1,
                    style: valueStyle,
                    textScaler: scaler,
                  ) <=
                  column &&
              measureStatWidth(
                    value: s.$2,
                    style: labelStyle,
                    textScaler: scaler,
                  ) <=
                  column,
        );

        if (!fits) {
          return Column(
            children: [
              for (final (String value, String label) in stats)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(child: Text(label, style: labelStyle)),
                    const SizedBox(width: AppSpacing.small),
                    Flexible(
                      flex: 2,
                      child: Text(
                        value,
                        textAlign: TextAlign.end,
                        style: valueStyle,
                      ),
                    ),
                  ],
                ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < stats.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stats[i].$1, maxLines: 1, style: valueStyle),
                    const SizedBox(height: 3),
                    Text(stats[i].$2, maxLines: 1, style: labelStyle),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ─── Loading ────────────────────────────────────────────────────────────────

/// Skeleton rows the size of real rows. Read as "Loading recent runs".
class _Loading extends StatelessWidget {
  const _Loading({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: AppStrings.recentRunsLoading,
      excludeSemantics: true,
      child: SkeletonShimmer(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: RecentRunsCard.skeletonRows,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, _) => const _SkeletonRow(),
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  static Widget _block(BuildContext context, double width, double height) =>
      SkeletonShimmerBlock(
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: AppPalette.of(context).skeleton,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _block(context, 110, 16)),
              const SizedBox(width: 16, height: 16),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (int i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _block(context, 70, 18),
                      const SizedBox(height: 6),
                      _block(context, 48, 10),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Empty and error ────────────────────────────────────────────────────────

class _Message extends StatelessWidget {
  const _Message({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.alert = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  /// Error states are announced when they appear.
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: palette.isDark && alert
                            ? palette.errorTint
                            : palette.iconTile,
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      child: Icon(
                        icon,
                        size: 34,
                        color: palette.isDark && alert
                            ? palette.error
                            : palette.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  Semantics(
                    container: true,
                    liveRegion: alert,
                    child: Column(
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.of(context).sectionHeading,
                        ),
                        const SizedBox(height: AppSpacing.small),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.of(context).body.copyWith(
                            fontSize: 15,
                            height: 22 / 15,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (action != null) ...[
                    const SizedBox(height: AppSpacing.medium),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

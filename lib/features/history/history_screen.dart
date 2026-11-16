// Road Runner — Run History screen.
// Owner: Tharushi
// SRS reference: Section 8.4, FR-61, FR-62, NFR-09, NFR-14
//
// Lists saved runs, newest first. Tapping a run passes its ID to the
// parent, which opens Summary. No run records are created here; the list
// is injected from the repository by the app flow.

import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../app_strings.dart';
import '../home/widgets/icon_tile.dart';
import '../home/widgets/sky_header.dart';
import '../shared/app_navigation_drawer.dart';
import '../shared/skeleton_shimmer.dart';
import '../run/live_run_formatter.dart';
import '../run/widgets/live_stat.dart' show measureStatWidth;
import 'history_run.dart';

enum HistoryRunFilter { allRuns, thisMonth, lastMonth }

@immutable
class HistoryMonthlySummary {
  const HistoryMonthlySummary({
    required this.monthLabel,
    required this.totalRuns,
    required this.totalDistanceM,
    required this.totalMovingMs,
    this.averagePaceSecPerKm,
  });

  final String monthLabel;
  final int totalRuns;
  final double totalDistanceM;
  final int totalMovingMs;
  final double? averagePaceSecPerKm;
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.runs,
    required this.onRunSelected,
    required this.onBackToHome,
    this.formatter = const LiveRunFormatter(),
    this.referenceDate,
    this.initialFilter = HistoryRunFilter.allRuns,
    this.thisMonthSummary,
    this.lastMonthSummary,
    this.isLoading = false,
    this.hasError = false,
    this.onRetry,
    this.onStartRun,
    this.onOpenHome,
    this.onOpenSettings,
  });

  /// Saved runs in any order; shown newest first.
  final List<HistoryRun> runs;

  /// Called with the tapped run's ID.
  final ValueChanged<String> onRunSelected;

  final VoidCallback onBackToHome;

  /// Display-only conversions. Swap for the stats formatters when merged.
  final LiveRunFormatter formatter;

  /// Optional local-calendar reference date for deterministic month filtering.
  /// Defaults to the current local date.
  final DateTime? referenceDate;

  /// Initial selected filter. Defaults to All Runs to preserve existing callers.
  final HistoryRunFilter initialFilter;

  /// Optional summaries supplied by the integration/domain layer.
  final HistoryMonthlySummary? thisMonthSummary;
  final HistoryMonthlySummary? lastMonthSummary;

  /// Optional asynchronous state supplied by the integration layer.
  final bool isLoading;
  final bool hasError;
  final VoidCallback? onRetry;

  /// Optional actions shown only when supported by the caller.
  final VoidCallback? onStartRun;
  final VoidCallback? onOpenHome;
  final VoidCallback? onOpenSettings;

  static const Key backButtonKey = Key('history.back');
  static const Key menuButtonKey = Key('history.menu');
  static const Key summaryCardKey = Key('history.monthlySummary');
  static const Key loadingStateKey = Key('history.loading');
  static Key runTileKey(String runId) => Key('history.run.$runId');
  static Key filterChipKey(HistoryRunFilter filter) =>
      Key('history.filter.${filter.name}');

  /// Newest first by start time; ties keep a stable order by run ID.
  static List<HistoryRun> newestFirst(List<HistoryRun> runs) {
    return [...runs]..sort((a, b) {
      final int byTime = b.startedAt.compareTo(a.startedAt);
      return byTime != 0 ? byTime : a.runId.compareTo(b.runId);
    });
  }

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late HistoryRunFilter _filter = widget.initialFilter;

  @override
  void didUpdateWidget(HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilter != widget.initialFilter) {
      _filter = widget.initialFilter;
    }
  }

  void _selectFilter(HistoryRunFilter filter) {
    if (_filter == filter) return;
    setState(() => _filter = filter);
  }

  DateTime get _referenceDate =>
      (widget.referenceDate ?? DateTime.now()).toLocal();

  List<HistoryRun> _visibleRuns() {
    if (_filter == HistoryRunFilter.allRuns) {
      return HistoryScreen.newestFirst(widget.runs);
    }

    final DateTime now = _referenceDate;
    final DateTime start = _filter == HistoryRunFilter.thisMonth
        ? DateTime(now.year, now.month)
        : DateTime(now.year, now.month - 1);
    final DateTime end = DateTime(start.year, start.month + 1);
    final List<HistoryRun> periodRuns = widget.runs.where((run) {
      final DateTime localStart = run.startedAt.toLocal();
      return !localStart.isBefore(start) && localStart.isBefore(end);
    }).toList();
    return HistoryScreen.newestFirst(periodRuns);
  }

  HistoryMonthlySummary? get _visibleSummary => switch (_filter) {
    HistoryRunFilter.allRuns => null,
    HistoryRunFilter.thisMonth => widget.thisMonthSummary,
    HistoryRunFilter.lastMonth => widget.lastMonthSummary,
  };

  @override
  Widget build(BuildContext context) {
    final List<HistoryRun> visibleRuns = _visibleRuns();
    final HistoryMonthlySummary? summary = _visibleSummary;
    final List<Widget> content = [
      if (widget.isLoading)
        _HistoryLoadingState(selected: _filter, onSelected: _selectFilter)
      else ...[
        if (summary != null) ...[
          _MonthlySummaryCard(summary: summary, formatter: widget.formatter),
          const SizedBox(height: AppSpacing.itemGap),
        ],
        _HistoryFilterBar(selected: _filter, onSelected: _selectFilter),
        const SizedBox(height: AppSpacing.itemGap),
        if (widget.hasError)
          _HistoryErrorState(onRetry: widget.onRetry)
        else if (visibleRuns.isEmpty)
          _EmptyState(filter: _filter, onStartRun: widget.onStartRun)
        else ...[
          if (summary == null) ...[
            Text(
              AppStrings.historyRunCount(visibleRuns.length),
              style: AppTextStyles.of(context).caption,
            ),
            const SizedBox(height: AppSpacing.small),
          ],
          for (int i = 0; i < visibleRuns.length; i++) ...[
            _RunCard(
              key: HistoryScreen.runTileKey(visibleRuns[i].runId),
              run: visibleRuns[i],
              formatter: widget.formatter,
              onTap: () => widget.onRunSelected(visibleRuns[i].runId),
            ),
            if (i != visibleRuns.length - 1)
              const SizedBox(height: AppSpacing.itemGap),
          ],
        ],
      ],
    ];

    return Scaffold(
      drawer: AppNavigationDrawer(
        selected: AppDestination.history,
        onOpenHome: widget.onOpenHome ?? widget.onBackToHome,
        onOpenHistory: _doNothing,
        onOpenSettings: widget.onOpenSettings ?? _doNothing,
      ),
      body: Column(
        children: [
          Builder(
            builder: (context) => CompactSkyHeader(
              title: AppStrings.historyTitle,
              subtitle: AppStrings.historyHeaderSubtitle,
              leading: HeaderIconButton(
                key: HistoryScreen.backButtonKey,
                icon: Icons.arrow_back_rounded,
                tooltip: AppStrings.backToHome,
                onPressed: widget.onBackToHome,
              ),
              trailing: HeaderIconButton(
                key: HistoryScreen.menuButtonKey,
                icon: Icons.menu_rounded,
                tooltip: AppStrings.homeOpenMenu,
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverSafeArea(
                  top: false,
                  sliver: SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.medium,
                      AppSpacing.small,
                      AppSpacing.medium,
                      AppSpacing.medium,
                    ),
                    sliver: SliverList.list(children: content),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _doNothing() {}

class _HistoryFilterBar extends StatelessWidget {
  const _HistoryFilterBar({required this.selected, required this.onSelected});

  final HistoryRunFilter selected;
  final ValueChanged<HistoryRunFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Semantics(
      container: true,
      label: AppStrings.historyFilterLabel,
      child: Row(
        children: [
          for (final HistoryRunFilter filter in HistoryRunFilter.values) ...[
            if (filter != HistoryRunFilter.values.first)
              const SizedBox(width: AppSpacing.small / 2),
            Expanded(
              child: SizedBox(
                height: AppSpacing.minTouchTarget,
                child: ChoiceChip(
                  key: HistoryScreen.filterChipKey(filter),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _filterLabel(filter),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected == filter
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  selected: selected == filter,
                  showCheckmark: false,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  visualDensity: VisualDensity.standard,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  labelPadding: EdgeInsets.zero,
                  // Kit: day chips sit on the card colour with a burnt-orange
                  // border; night chips are transparent with a taupe
                  // border. The selected chip is the primary fill in both.
                  backgroundColor: palette.isDark
                      ? Colors.transparent
                      : palette.surface,
                  selectedColor: palette.primaryFill,
                  side: BorderSide(
                    color: selected == filter
                        ? palette.primaryFill
                        : palette.buttonOutline,
                    width: 1.5,
                  ),
                  shape: const StadiumBorder(),
                  labelStyle: TextStyle(
                    color: selected == filter
                        ? palette.onPrimaryFill
                        : palette.textPrimary,
                  ),
                  onSelected: (_) => onSelected(filter),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _filterLabel(HistoryRunFilter filter) => switch (filter) {
    HistoryRunFilter.allRuns => AppStrings.historyAllRuns,
    HistoryRunFilter.thisMonth => AppStrings.historyThisMonth,
    HistoryRunFilter.lastMonth => AppStrings.historyLastMonth,
  };
}

class _MonthlySummaryCard extends StatelessWidget {
  const _MonthlySummaryCard({required this.summary, required this.formatter});

  final HistoryMonthlySummary summary;
  final LiveRunFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final String distance = formatter.distanceKm(summary.totalDistanceM);
    final AppThemedTextStyles text = AppTextStyles.of(context);
    return Card(
      key: HistoryScreen.summaryCardKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.medium,
          vertical: 14,
        ),
        child: Row(
          children: [
            const IconTile(icon: Icons.bar_chart_rounded),
            const SizedBox(width: AppSpacing.itemGap),
            // Total time sits on the right, or wraps below the month on
            // narrow phones with large text, so nothing overflows.
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.small,
                runSpacing: AppSpacing.small,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(summary.monthLabel, style: text.sectionHeading),
                      Text(
                        AppStrings.historySummaryRunsDistance(
                          summary.totalRuns,
                          distance,
                        ),
                        style: text.caption,
                      ),
                      if (summary.averagePaceSecPerKm != null)
                        Text(
                          '${AppStrings.statAveragePace} ${formatter.pace(summary.averagePaceSecPerKm)}/km',
                          style: AppTextStyles.caption,
                        ),
                    ],
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatter.elapsed(summary.totalMovingMs),
                        style: text.statValue,
                      ),
                      Text(AppStrings.historyTotalTime, style: text.caption),
                    ],
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

class _HistoryLoadingState extends StatelessWidget {
  const _HistoryLoadingState({
    required this.selected,
    required this.onSelected,
  });

  final HistoryRunFilter selected;
  final ValueChanged<HistoryRunFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: HistoryScreen.loadingStateKey,
      container: true,
      liveRegion: true,
      label: AppStrings.historyLoading,
      child: SkeletonShimmer(
        child: Column(
          children: [
            const _HistorySkeletonSummary(),
            const SizedBox(height: AppSpacing.itemGap),
            _HistoryFilterBar(selected: selected, onSelected: onSelected),
            const SizedBox(height: AppSpacing.itemGap),
            for (int i = 0; i < 3; i++) ...[
              const _HistorySkeletonCard(),
              if (i < 2) const SizedBox(height: AppSpacing.itemGap),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistorySkeletonSummary extends StatelessWidget {
  const _HistorySkeletonSummary();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Row(
          children: [
            const _SkeletonBlock(width: 40, height: 40, radius: 12),
            const SizedBox(width: AppSpacing.itemGap),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBlock(width: 96, height: 18),
                  SizedBox(height: AppSpacing.small),
                  _SkeletonBlock(width: 120, height: 11),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.small),
            const _SkeletonBlock(width: 64, height: 30),
          ],
        ),
      ),
    );
  }
}

class _HistorySkeletonCard extends StatelessWidget {
  const _HistorySkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            const Row(
              children: [
                _SkeletonBlock(width: 40, height: 40, radius: 12),
                SizedBox(width: AppSpacing.itemGap),
                _SkeletonBlock(width: 130, height: 18),
              ],
            ),
            const SizedBox(height: AppSpacing.itemGap),
            Row(
              children: [
                for (int i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.medium),
                  const Expanded(
                    child: Column(
                      children: [
                        _SkeletonBlock(width: 64, height: 20),
                        SizedBox(height: AppSpacing.small),
                        _SkeletonBlock(width: 44, height: 10),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.width,
    required this.height,
    this.radius = 6,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return SkeletonShimmerBlock(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          // Day keeps its existing tile-coloured blocks; night uses the
          // kit skeleton fill (textPrimary 9%), as on Home and Summary.
          color: palette.isDark ? palette.skeleton : palette.iconTile,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _HistoryErrorState extends StatelessWidget {
  const _HistoryErrorState({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final AppThemedTextStyles text = AppTextStyles.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.small,
        vertical: AppSpacing.large,
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 44,
            color: text.palette.error,
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            AppStrings.historyErrorTitle,
            textAlign: TextAlign.center,
            style: text.sectionHeading,
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            AppStrings.historyErrorMessage,
            textAlign: TextAlign.center,
            style: text.body,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.medium),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(AppStrings.historyRetry),
            ),
          ],
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
    final String date = _formatHistoryDate(local);
    final String time = l10n.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final String distance =
        '${formatter.distanceKm(run.distanceM)} ${AppStrings.unitKm}';
    final String duration = formatter.elapsed(run.movingMs);
    final String pace =
        '${formatter.pace(run.averagePaceSecPerKm)}${AppStrings.unitPerKm}';
    final AppThemedTextStyles text = AppTextStyles.of(context);

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
                            Text(
                              date,
                              style: text.sectionHeading.copyWith(fontSize: 19),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: text.palette.textSecondary,
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

String _formatHistoryDate(DateTime date) {
  const List<String> months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

/// Three stats side by side; stacked as "label  value" lines when the
/// values would not fit (narrow phones, large text).
class _StatRow extends StatelessWidget {
  const _StatRow({required this.stats});

  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final AppThemedTextStyles text = AppTextStyles.of(context);
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
                      Expanded(child: Text(label, style: text.caption)),
                      const SizedBox(width: AppSpacing.small),
                      Flexible(
                        flex: 2,
                        child: Text(
                          value,
                          textAlign: TextAlign.end,
                          style: text.statValue,
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
                  VerticalDivider(
                    width: divider,
                    thickness: 1,
                    color: text.palette.hairline,
                  ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        stats[i].$1,
                        textAlign: TextAlign.center,
                        style: text.statValue,
                      ),
                      Text(
                        stats[i].$2,
                        textAlign: TextAlign.center,
                        style: text.caption,
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
  const _EmptyState({required this.filter, required this.onStartRun});

  final HistoryRunFilter filter;
  final VoidCallback? onStartRun;

  @override
  Widget build(BuildContext context) {
    final AppThemedTextStyles text = AppTextStyles.of(context);
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.large),
        child: Column(
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.directions_run_rounded,
                size: 48,
                color: text.palette.accent,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              switch (filter) {
                HistoryRunFilter.allRuns => AppStrings.historyEmptyTitle,
                HistoryRunFilter.thisMonth =>
                  AppStrings.historyEmptyThisMonthTitle,
                HistoryRunFilter.lastMonth =>
                  AppStrings.historyEmptyLastMonthTitle,
              },
              textAlign: TextAlign.center,
              style: text.sectionHeading,
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              filter == HistoryRunFilter.allRuns
                  ? AppStrings.historyEmptyMessage
                  : AppStrings.historyEmptyPeriodMessage,
              textAlign: TextAlign.center,
              style: text.body,
            ),
            if (onStartRun != null) ...[
              const SizedBox(height: AppSpacing.large),
              FilledButton.icon(
                onPressed: onStartRun,
                icon: const Icon(Icons.directions_run_rounded),
                label: const Text(AppStrings.historyStartRun),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

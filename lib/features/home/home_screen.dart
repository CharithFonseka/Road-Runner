// Road Runner — Home screen (UI kit Revision 5).
// Owner: Tharushi
// SRS reference: Section 8.4, FR-01 (trigger), FR-61, FR-71, NFR-09, NFR-14
//
// Layout, top to bottom:
//   * compact sky header with appearance and Settings shortcuts;
//   * route/weather, weekly goal/streak, badge and two-run preview cards;
//   * a fixed 72dp Slide to Start control and five-destination bottom bar.
//
// Home only displays data and reports actions. It never starts a run, reads
// the repository or talks to TrackingBridge: the app shell supplies the runs
// and handles every callback (permissions, navigation, retry).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/current_weather_client.dart';
import '../../data/run_weather_client.dart';
import '../../domain/achievements/goals_summary.dart';
import '../app_strings.dart';
import '../history/history_run.dart';
import '../history/history_screen.dart';
import '../run/live_run_formatter.dart';
import '../shared/app_bottom_navigation.dart';
import 'last_run_summary.dart';
import 'widgets/recent_runs_card.dart';
import 'widgets/sky_header.dart';
import 'widgets/slide_to_start.dart';

export 'widgets/recent_runs_card.dart' show RecentRunsStatus;

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    @Deprecated('Pass recentRuns. Kept so older callers still compile.')
    this.lastRun,
    required this.onStartRun,
    required this.onOpenHistory,
    required this.onOpenPermissions,
    this.recentRuns = const <HistoryRun>[],
    this.recentRunsStatus = RecentRunsStatus.ready,
    this.onRetry,
    this.onRunSelected,
    this.onOpenSettings,
    this.onPlanRoute,
    this.onOpenGoals,
    this.onOpenProfile,
    this.onOpenRun,
    this.achievements,
    this.weather,
    this.onToggleTheme,
    this.weeklyDistanceKm,
    this.weeklyGoalKm,
    this.isStartingRun = false,
    this.startRunEnabled = true,
    this.formatter = const LiveRunFormatter(),
  });

  /// Legacy single "last run" input from before Revision 5. Shown as the
  /// only Recent runs row when [recentRuns] is empty; tapping it opens
  /// History. New code should pass [recentRuns].
  @Deprecated('Pass recentRuns. Kept so older callers still compile.')
  final LastRunSummary? lastRun;

  /// Called once each time the user completes Slide to Start (drag, hold,
  /// screen reader or keyboard). The parent checks permissions and opens
  /// the Run screen; there is no extra confirmation on Home.
  final VoidCallback onStartRun;

  /// "View all", bottom navigation, and run rows when
  /// [onRunSelected] is not supplied.
  final VoidCallback onOpenHistory;

  /// Kept for compatibility. Home has no Permissions row any more
  /// (Permissions is reached from Settings or when starting a run). Used
  /// for the Settings shortcut until the
  /// shell supplies [onOpenSettings].
  final VoidCallback onOpenPermissions;

  /// Saved runs in any order; shown newest first. The parent decides how
  /// many are "recent" (for example the latest 10).
  final List<HistoryRun> recentRuns;

  /// Loading, ready or error. Set [RecentRunsStatus.loading] only for
  /// reads that are actually slow; never add a delay to show it.
  final RecentRunsStatus recentRunsStatus;

  /// "Try again" in the error state. Null hides the button.
  final VoidCallback? onRetry;

  /// Called with a tapped run's ID (the parent opens Summary).
  final ValueChanged<String>? onRunSelected;

  /// Settings shortcut. Falls back to [onOpenPermissions].
  final VoidCallback? onOpenSettings;

  /// Opens the walking route planner when available.
  final VoidCallback? onPlanRoute;
  final VoidCallback? onOpenGoals;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenRun;
  final AchievementsSnapshot? achievements;
  final RunWeather? weather;
  final ValueChanged<bool>? onToggleTheme;
  final double? weeklyDistanceKm;
  final double? weeklyGoalKm;

  /// The parent's "starting a run" flag (for example while it checks
  /// permissions). True shows "Starting run"; turning it back to false
  /// re-arms the slider.
  final bool isStartingRun;

  /// False disables Slide to Start.
  final bool startRunEnabled;

  /// Display-only conversions. Swap for the stats formatters when merged.
  final LiveRunFormatter formatter;

  /// Key of the Slide to Start control (was the Start Run button).
  static const Key startRunButtonKey = Key('home_start_run_button');
  static const Key settingsButtonKey = Key('home.settings');
  static const Key recentRunsKey = Key('home.recentRuns');
  static const Key planRouteButtonKey = Key('home.planRoute');
  static const Key goalsButtonKey = Key('home.goals');
  static const Key weeklyGoalKey = Key('home.weeklyGoal');
  static const Key weatherKey = Key('home.weather');
  static const Key badgesKey = Key('home.badges');
  static const Key themeButtonKey = Key('home.theme');

  /// Below this height (phone in landscape) the desert strip is left out
  /// so the Recent runs card keeps usable space.
  static const double compactHeightBreakpoint = 480;

  /// Maximum width for Slide to Start in landscape/wide screens so thumb travel
  /// distance remains comfortable and ergonomic.
  static const double maxLandscapeSliderWidth = 340;

  static double _landscapeArtworkHeight(double availableHeight) {
    if (availableHeight >= 380) {
      return CompactSkyHeader.compactLandscapeHeight;
    } else if (availableHeight >= 330) {
      return 52;
    } else {
      return 40;
    }
  }

  static bool _showLandscapeArtwork(double availableHeight) {
    return availableHeight >= 280;
  }

  VoidCallback get _openSettings => onOpenSettings ?? onOpenPermissions;

  Widget _headerActions(AppPalette palette) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (onToggleTheme != null) ...[
        HeaderIconButton(
          key: themeButtonKey,
          icon: palette.isDark
              ? Icons.light_mode_outlined
              : Icons.dark_mode_outlined,
          tooltip: palette.isDark
              ? 'Switch to light mode'
              : 'Switch to dark mode',
          onPressed: () => onToggleTheme!(palette.isDark),
        ),
        const SizedBox(width: 4),
      ],
      HeaderIconButton(
        key: settingsButtonKey,
        icon: Icons.settings_outlined,
        tooltip: AppStrings.homeSettings,
        onPressed: _openSettings,
      ),
    ],
  );

  List<RecentRunRow> _rows() {
    if (recentRuns.isNotEmpty) {
      return [
        for (final HistoryRun run in HistoryScreen.newestFirst(recentRuns))
          RecentRunRow(
            runId: run.runId,
            dateLabel: AppStrings.runDate(run.startedAt.toLocal()),
            runName: run.runName,
            distance:
                '${formatter.distanceKm(run.distanceM)} ${AppStrings.unitKm}',
            duration: formatter.elapsed(run.movingMs),
            pace:
                '${formatter.pace(run.averagePaceSecPerKm)}'
                '${AppStrings.unitPerKm}',
          ),
      ];
    }
    // ignore: deprecated_member_use_from_same_package
    final LastRunSummary? legacy = lastRun;
    if (legacy != null) {
      return [
        RecentRunRow(
          dateLabel: legacy.dateLabel,
          distance: legacy.distance,
          duration: legacy.duration,
          pace: legacy.averagePace,
        ),
      ];
    }
    return const [];
  }

  void _onRowSelected(RecentRunRow row) {
    final String? id = row.runId;
    final ValueChanged<String>? select = onRunSelected;
    if (id != null && select != null) {
      select(id);
    } else {
      onOpenHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      bottomNavigationBar: onPlanRoute != null && onOpenProfile != null
          ? AppBottomNavigation(
              selected: MainDestination.home,
              onHome: () {},
              onRoutes: onPlanRoute!,
              onRun: onOpenRun ?? onStartRun,
              onHistory: onOpenHistory,
              onProfile: onOpenProfile!,
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isLandscape =
              constraints.maxWidth > constraints.maxHeight &&
              constraints.maxWidth >= 500;
          if (isLandscape) {
            return _buildLandscape(context, palette, constraints);
          }
          return _buildPortrait(context, palette, constraints);
        },
      ),
    );
  }

  Widget _buildActionRow() {
    return Row(
      children: [
        if (onPlanRoute != null)
          Expanded(
            child: OutlinedButton.icon(
              key: planRouteButtonKey,
              onPressed: onPlanRoute,
              icon: const Icon(Icons.route_outlined, size: 18),
              label: const Text('Plan a route'),
            ),
          ),
        if (onPlanRoute != null && onOpenGoals != null)
          const SizedBox(width: AppSpacing.itemGap),
        if (onOpenGoals != null)
          Expanded(
            child: OutlinedButton.icon(
              key: goalsButtonKey,
              onPressed: onOpenGoals,
              icon: const Icon(Icons.emoji_events_outlined, size: 18),
              label: const Text('Goals & Badges'),
            ),
          ),
      ],
    );
  }

  Widget _buildPortrait(
    BuildContext context,
    AppPalette palette,
    BoxConstraints constraints,
  ) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final List<RecentRunRow> rows = _rows();
    final bool tall = MediaQuery.sizeOf(context).height >= 900;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CompactSkyHeader(
          title: AppStrings.appName,
          subtitle: AppStrings.homeTagline,
          showLandscape: tall,
          trailing: _headerActions(palette),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.medium,
              AppSpacing.small,
              AppSpacing.medium,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (onPlanRoute != null) ...[
                  _RouteWeatherCard(weather: weather, onTap: onPlanRoute!),
                  const SizedBox(height: AppSpacing.itemGap),
                ],
                if (weeklyDistanceKm != null &&
                    weeklyGoalKm != null &&
                    weeklyGoalKm! > 0 &&
                    onOpenGoals != null) ...[
                  _WeeklyGoalCard(
                    distanceKm: weeklyDistanceKm!,
                    goalKm: weeklyGoalKm!,
                    onTap: onOpenGoals!,
                    streakDays: achievements?.currentStreakDays,
                  ),
                  const SizedBox(height: AppSpacing.itemGap),
                ],
                if (onOpenProfile != null) ...[
                  _BadgesPreviewCard(
                    achievements: achievements,
                    onTap: onOpenProfile!,
                  ),
                  const SizedBox(height: AppSpacing.itemGap),
                ],
                SizedBox(
                  height:
                      recentRunsStatus == RecentRunsStatus.ready &&
                          rows.length > 1
                      ? 214
                      : 190,
                  child: RecentRunsCard(
                    key: recentRunsKey,
                    compact: true,
                    status: recentRunsStatus,
                    rows: rows.take(2).toList(),
                    onViewAll: onOpenHistory,
                    onRowSelected: _onRowSelected,
                    onRetry: onRetry,
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.medium,
            AppSpacing.itemGap,
            AppSpacing.medium,
            AppSpacing.medium + bottomInset,
          ),
          child: SlideToStart(
            key: startRunButtonKey,
            onStart: onStartRun,
            starting: isStartingRun,
            enabled: startRunEnabled,
          ),
        ),
      ],
    );
  }

  Widget _buildLandscape(
    BuildContext context,
    AppPalette palette,
    BoxConstraints constraints,
  ) {
    final double topInset = MediaQuery.paddingOf(context).top;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final double availableHeight = constraints.maxHeight - bottomInset;
    final bool showArtwork = _showLandscapeArtwork(availableHeight);
    final double artworkHeight = _landscapeArtworkHeight(availableHeight);

    final double leftWidth = math.min(
      maxLandscapeSliderWidth,
      (constraints.maxWidth - AppSpacing.medium) * 0.46,
    );

    return SafeArea(
      left: true,
      right: true,
      top: false,
      bottom: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: leftWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  child: CompactSkyHeader(
                    title: AppStrings.appName,
                    subtitle: AppStrings.homeTagline,
                    showLandscape: showArtwork,
                    landscapeHeight: artworkHeight,
                    trailing: _headerActions(palette),
                  ),
                ),
                const Spacer(),
                if (onPlanRoute != null || onOpenGoals != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.medium,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: maxLandscapeSliderWidth,
                        ),
                        child: _buildActionRow(),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.medium,
                    AppSpacing.itemGap,
                    AppSpacing.medium,
                    AppSpacing.medium + bottomInset,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: maxLandscapeSliderWidth,
                      ),
                      child: SlideToStart(
                        key: startRunButtonKey,
                        maxWidth: maxLandscapeSliderWidth,
                        onStart: onStartRun,
                        starting: isStartingRun,
                        enabled: startRunEnabled,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.medium),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                0,
                topInset + 6,
                AppSpacing.medium,
                AppSpacing.medium + bottomInset,
              ),
              child: RecentRunsCard(
                key: recentRunsKey,
                status: recentRunsStatus,
                rows: _rows(),
                onViewAll: onOpenHistory,
                onRowSelected: _onRowSelected,
                onRetry: onRetry,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyGoalCard extends StatelessWidget {
  const _WeeklyGoalCard({
    required this.distanceKm,
    required this.goalKm,
    required this.onTap,
    this.streakDays,
  });

  final double distanceKm;
  final double goalKm;
  final VoidCallback onTap;
  final int? streakDays;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final double progress = (distanceKm / goalKm).clamp(0.0, 1.0);
    return Semantics(
      key: HomeScreen.weeklyGoalKey,
      button: true,
      label: AppStrings.weeklyGoalProgress(distanceKm, goalKm),
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.emoji_events_outlined, color: palette.accent),
                    const SizedBox(width: AppSpacing.small),
                    Expanded(
                      child: Text(
                        AppStrings.weeklyGoalTitle,
                        style: AppTextStyles.of(context).sectionHeading,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: palette.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.small),
                Text(
                  AppStrings.weeklyGoalProgress(distanceKm, goalKm),
                  style: AppTextStyles.of(context).body,
                ),
                const SizedBox(height: AppSpacing.small),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: palette.iconButtonFill,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      palette.primaryFill,
                    ),
                  ),
                ),
                if (streakDays != null) ...[
                  const SizedBox(height: AppSpacing.small),
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 17,
                        color: palette.accent,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$streakDays day streak  ·  View goals',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.of(context).caption,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteWeatherCard extends StatelessWidget {
  const _RouteWeatherCard({required this.weather, required this.onTap});

  final RunWeather? weather;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final temperature = weather?.temperatureC;
    return Card(
      key: HomeScreen.weatherKey,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: HomeScreen.planRouteButtonKey,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: palette.iconTile,
                foregroundColor: palette.accent,
                child: const Icon(Icons.route_rounded),
              ),
              const SizedBox(width: AppSpacing.itemGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plan your next route',
                      style: AppTextStyles.of(context).sectionHeading,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      temperature == null
                          ? 'Choose a route and check conditions'
                          : '${temperature.round()}°C · ${weatherDescription(weather)} · near your last run',
                      style: AppTextStyles.of(context).caption,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgesPreviewCard extends StatelessWidget {
  const _BadgesPreviewCard({required this.achievements, required this.onTap});

  final AchievementsSnapshot? achievements;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final earned = achievements?.earnedBadges.keys.toSet() ?? {};
    return Card(
      key: HomeScreen.badgesKey,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.workspace_premium_outlined, color: palette.accent),
                  const SizedBox(width: AppSpacing.small),
                  Expanded(
                    child: Text(
                      'Your badges',
                      style: AppTextStyles.of(context).sectionHeading,
                    ),
                  ),
                  Text(
                    '${earned.length}/${kAllBadges.length}',
                    style: AppTextStyles.of(context).caption,
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: palette.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.small),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final badge in kAllBadges.take(2))
                    Chip(
                      avatar: Icon(
                        earned.contains(badge.type)
                            ? Icons.stars_rounded
                            : Icons.lock_outline_rounded,
                        size: 18,
                      ),
                      label: Text(badge.title),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: earned.contains(badge.type)
                          ? palette.iconTile
                          : palette.surface,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

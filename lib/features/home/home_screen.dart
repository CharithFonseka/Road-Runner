// Road Runner — Home screen (UI kit Revision 5).
// Owner: Tharushi
// SRS reference: Section 8.4, FR-01 (trigger), FR-61, FR-71, NFR-09, NFR-14
//
// Layout, top to bottom:
//   * compact sky header: menu button (opens the navigation drawer), name,
//     tagline and a Settings shortcut, all 48dp targets;
//   * "Recent runs" card filling the free space, with its own scrolling
//     list and loading, empty and error states;
//   * a fixed 72dp Slide to Start control above the system navigation bar.
//
// Home only displays data and reports actions. It never starts a run, reads
// the repository or talks to TrackingBridge: the app shell supplies the runs
// and handles every callback (permissions, navigation, retry).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../app_strings.dart';
import '../history/history_run.dart';
import '../history/history_screen.dart';
import '../run/live_run_formatter.dart';
import '../shared/app_navigation_drawer.dart';
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

  /// "View all", the drawer's History entry, and run rows when
  /// [onRunSelected] is not supplied.
  final VoidCallback onOpenHistory;

  /// Kept for compatibility. Home has no Permissions row any more
  /// (Permissions is reached from Settings or when starting a run). Used
  /// for the Settings shortcut and the drawer's Settings entry until the
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

  /// Settings shortcut and drawer entry. Falls back to [onOpenPermissions].
  final VoidCallback? onOpenSettings;

  /// Opens the walking route planner when available.
  final VoidCallback? onPlanRoute;

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
  static const Key menuButtonKey = Key('home.menu');
  static const Key settingsButtonKey = Key('home.settings');
  static const Key recentRunsKey = Key('home.recentRuns');
  static const Key planRouteButtonKey = Key('home.planRoute');

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
      drawer: AppNavigationDrawer(
        selected: AppDestination.home,
        onOpenHome: () {}, // Home is the current page: the drawer only closes.
        onOpenHistory: onOpenHistory,
        onOpenSettings: _openSettings,
      ),
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

  Widget _buildPortrait(
    BuildContext context,
    AppPalette palette,
    BoxConstraints constraints,
  ) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    final bool tall =
        MediaQuery.sizeOf(context).height >= compactHeightBreakpoint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Builder(
          builder: (context) => CompactSkyHeader(
            title: AppStrings.appName,
            subtitle: AppStrings.homeTagline,
            showLandscape: tall,
            leading: HeaderIconButton(
              key: menuButtonKey,
              icon: Icons.menu_rounded,
              tooltip: AppStrings.homeOpenMenu,
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            trailing: HeaderIconButton(
              key: settingsButtonKey,
              icon: Icons.settings_outlined,
              tooltip: AppStrings.homeSettings,
              onPressed: _openSettings,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.medium,
              6,
              AppSpacing.medium,
              0,
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
        if (onPlanRoute != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
            child: OutlinedButton.icon(
              key: planRouteButtonKey,
              onPressed: onPlanRoute,
              icon: const Icon(Icons.route_outlined),
              label: const Text('Plan a route'),
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
                Builder(
                  builder: (context) => ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                    child: CompactSkyHeader(
                      title: AppStrings.appName,
                      subtitle: AppStrings.homeTagline,
                      showLandscape: showArtwork,
                      landscapeHeight: artworkHeight,
                      leading: HeaderIconButton(
                        key: menuButtonKey,
                        icon: Icons.menu_rounded,
                        tooltip: AppStrings.homeOpenMenu,
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                      trailing: HeaderIconButton(
                        key: settingsButtonKey,
                        icon: Icons.settings_outlined,
                        tooltip: AppStrings.homeSettings,
                        onPressed: _openSettings,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                if (onPlanRoute != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.medium,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: maxLandscapeSliderWidth,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            key: planRouteButtonKey,
                            onPressed: onPlanRoute,
                            icon: const Icon(Icons.route_outlined),
                            label: const Text('Plan a route'),
                          ),
                        ),
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

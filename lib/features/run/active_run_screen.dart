// Road Runner — Active Run / Paused Run screen.
// Owner: Tharushi
// SRS reference: Section 4.2, 4.5, 8.3, 8.4, FR-20–23, NFR-09, NFR-14
//
// Shows live values exactly as the TrackingBridge reports them. Values are
// only formatted for display (LiveRunFormatter); nothing is calculated here.
//
// Tracking semantics (confirmed by Aadila):
//  * The main timer is TrackingSnapshot.movingMs ("Moving time"). It freezes
//    while paused. elapsedMs is wall-clock time and is not shown.
//  * paceSecPerKm is the CURRENT pace from smoothed speed ("Current pace"),
//    not the run's average pace.
//
// Navigation is the parent's job:
//  * onRunFinished receives the real RunResult from bridge.stopRun().
//  * onExit is called when the user leaves after a failed start, or after
//    a run stopped outside this screen whose result could not be recovered.
// The parent owns the bridge. Removing this screen never stops the run.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../bridge/tracking_bridge.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/planned_route.dart';
import '../app_strings.dart';
import 'active_run_controller.dart';
import 'live_run_formatter.dart';
import 'live_run_map.dart';
import 'widgets/live_stat.dart';
import 'widgets/run_control_button.dart';
import 'widgets/status_chips.dart';
import 'widgets/stop_run_dialog.dart';

class ActiveRunScreen extends StatefulWidget {
  const ActiveRunScreen({
    super.key,
    required this.bridge,
    required this.onRunFinished,
    required this.onExit,
    this.formatter = const LiveRunFormatter(),
    this.plannedRoute,
    this.runName,
  });

  /// Owned by the parent. Read once in initState; this screen never
  /// disposes it.
  final TrackingBridge bridge;

  /// Called once with the real result after the run is stopped.
  final ValueChanged<RunResult> onRunFinished;

  /// Leave the Run screen without a result (failed start, unresolved stop).
  final VoidCallback onExit;

  /// Display formatter. Replace with the domain formatters when merged.
  final LiveRunFormatter formatter;

  /// Optional planned route to display as a guide on the live map.
  final PlannedRoute? plannedRoute;
  final String? runName;

  static const Key pauseResumeButtonKey = Key('activeRun.pauseResume');
  static const Key stopButtonKey = Key('activeRun.stop');
  static const Key tryAgainButtonKey = Key('activeRun.tryAgain');
  static const Key exitButtonKey = Key('activeRun.exit');
  static const Key issueRetryButtonKey = Key('activeRun.issueRetry');
  static const Key issueDismissButtonKey = Key('activeRun.issueDismiss');

  /// The main timer (moving time).
  static const Key movingTimeValueKey = Key('activeRun.movingTime');

  /// Old name for [movingTimeValueKey], kept so existing callers compile.
  @Deprecated('Use movingTimeValueKey. The timer now shows moving time.')
  static const Key elapsedValueKey = movingTimeValueKey;
  static const Key paceValueKey = Key('activeRun.pace');
  static const Key distanceValueKey = Key('activeRun.distance');
  static const Key speedValueKey = Key('activeRun.speed');

  @override
  State<ActiveRunScreen> createState() => _ActiveRunScreenState();
}

class _ActiveRunScreenState extends State<ActiveRunScreen> {
  late final ActiveRunController _controller;

  /// The open Stop confirmation, or null. Also blocks a second dialog.
  DialogRoute<bool>? _stopDialog;

  @override
  void initState() {
    super.initState();
    _controller = ActiveRunController(
      bridge: widget.bridge,
      onRunFinished: (result) => widget.onRunFinished(result),
    )..addListener(_closeDialogIfRunEnded);
    unawaited(_controller.start());
  }

  @override
  void dispose() {
    _closeStopDialog();
    _controller
      ..removeListener(_closeDialogIfRunEnded)
      ..dispose();
    super.dispose();
  }

  Future<void> _confirmStop() async {
    if (_stopDialog != null || !_controller.state.canStop) return;
    final DialogRoute<bool> route = buildStopRunDialogRoute(context);
    _stopDialog = route;
    final bool? confirmed = await Navigator.of(context).push(route);

    // If the run ended while the dialog was open, _closeDialogIfRunEnded
    // already took the route away. Its late answer must not act on a run
    // that is over, so it is ignored.
    if (!identical(_stopDialog, route)) return;
    _stopDialog = null;
    if (!mounted || confirmed != true) return;
    await _controller.finish(); // also re-checks canStop
  }

  /// Closes the Stop confirmation when the run is no longer running or
  /// paused for a reason other than this dialog (e.g. a stopped event from
  /// the notification). Never calls stopRun().
  void _closeDialogIfRunEnded() {
    final RunPhase phase = _controller.state.phase;
    if (phase == RunPhase.running || phase == RunPhase.paused) return;
    _closeStopDialog();
  }

  void _closeStopDialog() {
    final DialogRoute<bool>? route = _stopDialog;
    if (route == null) return;
    _stopDialog = null;
    if (route.isActive) route.navigator?.removeRoute(route);
  }

  void _onBack() {
    switch (_controller.state.phase) {
      case RunPhase.running:
      case RunPhase.paused:
        unawaited(_confirmStop());
      case RunPhase.startFailed:
      case RunPhase.stoppedUnresolved:
        widget.onExit();
      case RunPhase.starting:
      case RunPhase.stopping:
      case RunPhase.finished:
        // Busy talking to the bridge: Back is ignored until it settles.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: context.palette.background,
        body: SafeArea(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => _buildBody(_controller.state),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ActiveRunState state) {
    switch (state.phase) {
      case RunPhase.startFailed:
        return _MessagePanel(
          icon: Icons.error_outline,
          title: AppStrings.startFailedTitle,
          message: _issueMessage(state.issue?.kind),
          primaryKey: ActiveRunScreen.tryAgainButtonKey,
          primaryLabel: AppStrings.tryAgain,
          onPrimary: state.busy ? null : _controller.start,
          secondaryLabel: AppStrings.exitRun,
          onSecondary: widget.onExit,
        );
      case RunPhase.stoppedUnresolved:
        return _MessagePanel(
          icon: Icons.flag_outlined,
          title: AppStrings.stoppedUnresolvedTitle,
          message: AppStrings.stoppedUnresolvedMessage,
          primaryKey: ActiveRunScreen.exitButtonKey,
          primaryLabel: AppStrings.exitRun,
          onPrimary: widget.onExit,
        );
      case RunPhase.starting:
      case RunPhase.running:
      case RunPhase.paused:
      case RunPhase.stopping:
      case RunPhase.finished:
        return _buildLive(state);
    }
  }

  Widget _buildLive(ActiveRunState state) {
    final bool paused = state.phase == RunPhase.paused;
    final RunIssue? issue = state.issue;
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isLandscape =
            constraints.maxWidth > constraints.maxHeight &&
            constraints.maxWidth >= 500;
        if (isLandscape) {
          return _buildLiveLandscape(state, paused, issue);
        }
        return _buildLivePortrait(state, paused, issue);
      },
    );
  }

  Widget _buildLivePortrait(
    ActiveRunState state,
    bool paused,
    RunIssue? issue,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(state: state, title: widget.runName),
        const SizedBox(height: AppSpacing.itemGap),
        if (issue != null) ...[
          _IssueBanner(
            message: _issueMessage(issue.kind),
            onRetry: _retryFor(issue.kind, state),
            onDismiss: _controller.clearIssue,
          ),
          const SizedBox(height: AppSpacing.itemGap),
        ],
        Expanded(
          child: CustomMultiChildLayout(
            delegate: _StatsAndControlsLayout(),
            children: [
              LayoutId(
                id: _BodySlot.stats,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _StatsCard(
                        snapshot: state.snapshot,
                        paused: paused,
                        formatter: widget.formatter,
                      ),
                      if (widget.plannedRoute != null ||
                          state.route.isNotEmpty ||
                          (state.snapshot?.lat != null &&
                              state.snapshot?.lon != null)) ...[
                        const SizedBox(height: AppSpacing.itemGap),
                        LiveRunMap(
                          route: state.route,
                          snapshot: state.snapshot,
                          plannedRoute: widget.plannedRoute,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              LayoutId(
                id: _BodySlot.controls,
                child: _Controls(
                  state: state,
                  onPause: _controller.pause,
                  onResume: _controller.resume,
                  onStop: () => unawaited(_confirmStop()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLiveLandscape(
    ActiveRunState state,
    bool paused,
    RunIssue? issue,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 11,
          child: LiveRunMap(
            route: state.route,
            snapshot: state.snapshot,
            plannedRoute: widget.plannedRoute,
            height: null,
            showSearchingPlaceholder: true,
          ),
        ),
        const SizedBox(width: AppSpacing.medium),
        Expanded(
          flex: 9,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(state: state, title: widget.runName),
              const SizedBox(height: AppSpacing.small),
              if (issue != null) ...[
                _IssueBanner(
                  message: _issueMessage(issue.kind),
                  onRetry: _retryFor(issue.kind, state),
                  onDismiss: _controller.clearIssue,
                ),
                const SizedBox(height: AppSpacing.small),
              ],
              Expanded(
                child: SingleChildScrollView(
                  child: _StatsCard(
                    snapshot: state.snapshot,
                    paused: paused,
                    formatter: widget.formatter,
                    isLandscape: true,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.small),
              _LandscapeControls(
                state: state,
                onPause: _controller.pause,
                onResume: _controller.resume,
                onStop: () => unawaited(_confirmStop()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  VoidCallback? _retryFor(RunIssueKind kind, ActiveRunState state) {
    switch (kind) {
      case RunIssueKind.pauseFailed:
        return state.canPause ? _controller.pause : null;
      case RunIssueKind.resumeFailed:
        return state.canResume ? _controller.resume : null;
      case RunIssueKind.stopFailed:
        // The user already confirmed Finish Run; retry stops directly.
        return state.canStop ? _controller.finish : null;
      case RunIssueKind.locationOff:
      case RunIssueKind.permissionDenied:
      case RunIssueKind.serviceFailed:
        return null;
    }
  }

  static String _issueMessage(RunIssueKind? kind) {
    switch (kind) {
      case RunIssueKind.locationOff:
        return AppStrings.errorLocationOff;
      case RunIssueKind.permissionDenied:
        return AppStrings.errorPermissionDenied;
      case RunIssueKind.pauseFailed:
        return AppStrings.errorPauseFailed;
      case RunIssueKind.resumeFailed:
        return AppStrings.errorResumeFailed;
      case RunIssueKind.stopFailed:
        return AppStrings.errorStopFailed;
      case RunIssueKind.serviceFailed:
      case null:
        return AppStrings.errorServiceFailed;
    }
  }
}

// ─── Body layout ────────────────────────────────────────────────────────────

enum _BodySlot { stats, controls }

/// Stats card at its natural height, buttons filling everything below it.
///
/// The card never takes more than its content needs, so there is no empty
/// gap above the buttons. The buttons always keep at least
/// [minControlsHeight] (two 72dp buttons + gap); if the card needs more
/// than what is left, it is capped and scrolls instead.
class _StatsAndControlsLayout extends MultiChildLayoutDelegate {
  _StatsAndControlsLayout();

  static const double gap = AppSpacing.itemGap;
  static const double minControlsHeight = 2 * 72.0 + AppSpacing.itemGap;

  @override
  void performLayout(Size size) {
    final double maxStats = math.max(
      0.0,
      size.height - gap - minControlsHeight,
    );
    // A scroll view with a loose height shrink-wraps its content.
    final Size stats = layoutChild(
      _BodySlot.stats,
      BoxConstraints(
        minWidth: size.width,
        maxWidth: size.width,
        maxHeight: maxStats,
      ),
    );
    positionChild(_BodySlot.stats, Offset.zero);

    final double top = math.min(stats.height + gap, size.height);
    layoutChild(
      _BodySlot.controls,
      BoxConstraints.tight(Size(size.width, size.height - top)),
    );
    positionChild(_BodySlot.controls, Offset(0, top));
  }

  @override
  bool shouldRelayout(_StatsAndControlsLayout oldDelegate) => false;
}

// ─── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.state, this.title});

  final ActiveRunState state;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final String? gps = state.gpsQuality;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.small,
      runSpacing: AppSpacing.small,
      children: [
        Semantics(
          header: true,
          child: Text(
            title ?? AppStrings.runTitle,
            style: AppTextStyles.of(context).heading,
          ),
        ),
        Wrap(
          spacing: AppSpacing.small,
          runSpacing: AppSpacing.small,
          children: [
            if (gps != null) GpsStatusBadge(quality: gps),
            RunStatusPill(phase: state.phase),
          ],
        ),
      ],
    );
  }
}

// ─── Stats ──────────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.snapshot,
    required this.paused,
    required this.formatter,
    this.isLandscape = false,
  });

  final TrackingSnapshot? snapshot;
  final bool paused;
  final LiveRunFormatter formatter;
  final bool isLandscape;

  @override
  Widget build(BuildContext context) {
    final TrackingSnapshot? s = snapshot;
    final AppPalette palette = context.palette;
    final AppThemedTextStyles textStyles = AppTextStyles.of(context);

    if (isLandscape) {
      final TextStyle liveStatStyle = palette.isDark
          ? AppTextStyles.statMedium.copyWith(color: palette.statLive)
          : AppTextStyles.statMedium;
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LiveStat(
                      label: AppStrings.statMovingTime,
                      value: formatter.elapsed(s?.movingMs),
                      template: '0:00:00',
                      valueKey: ActiveRunScreen.movingTimeValueKey,
                      style: textStyles.liveTimer.copyWith(
                        fontSize: 32,
                        color: paused ? palette.textSecondary : null,
                      ),
                      labelTrailing: paused ? const _PausedBadge() : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  Expanded(
                    child: LiveStat(
                      label: AppStrings.statCurrentPace,
                      value: formatter.pace(s?.paceSecPerKm),
                      unit: AppStrings.unitPerKm,
                      template: '00:00',
                      valueKey: ActiveRunScreen.paceValueKey,
                      style: textStyles.livePace.copyWith(fontSize: 32),
                    ),
                  ),
                ],
              ),
              const Divider(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: LiveStat(
                      label: AppStrings.statDistance,
                      value: formatter.distanceKm(s?.distanceM),
                      unit: AppStrings.unitKm,
                      valueKey: ActiveRunScreen.distanceValueKey,
                      style: liveStatStyle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  Expanded(
                    child: LiveStat(
                      label: AppStrings.statSpeed,
                      value: formatter.speedKmh(s?.speedMps),
                      unit: AppStrings.unitKmPerHour,
                      valueKey: ActiveRunScreen.speedValueKey,
                      style: liveStatStyle,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LiveStat(
              label: AppStrings.statMovingTime,
              value: formatter.elapsed(s?.movingMs),
              template: '0:00:00',
              valueKey: ActiveRunScreen.movingTimeValueKey,
              style: textStyles.liveTimer.copyWith(
                color: paused ? palette.textSecondary : null,
              ),
              labelTrailing: paused ? const _PausedBadge() : null,
            ),
            const Divider(height: AppSpacing.large),
            LiveStat(
              label: AppStrings.statCurrentPace,
              value: formatter.pace(s?.paceSecPerKm),
              unit: AppStrings.unitPerKm,
              template: '00:00',
              valueKey: ActiveRunScreen.paceValueKey,
              style: textStyles.livePace,
            ),
            const Divider(height: AppSpacing.large),
            _DistanceSpeedRow(
              distance: formatter.distanceKm(s?.distanceM),
              speed: formatter.speedKmh(s?.speedMps),
            ),
          ],
        ),
      ),
    );
  }
}

/// Distance and speed side by side; stacked when 32sp values would not
/// fit in two columns (narrow phones, large text).
class _DistanceSpeedRow extends StatelessWidget {
  const _DistanceSpeedRow({required this.distance, required this.speed});

  final String distance;
  final String speed;

  static const String _distanceTemplate = '00.00';
  static const String _speedTemplate = '00.0';

  @override
  Widget build(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final AppPalette palette = context.palette;
    final TextStyle liveStatStyle = palette.isDark
        ? AppTextStyles.statMedium.copyWith(color: palette.statLive)
        : AppTextStyles.statMedium;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double column = (constraints.maxWidth - AppSpacing.medium) / 2;
        final bool fitsSideBySide =
            measureStatWidth(
                  value: _distanceTemplate,
                  style: liveStatStyle,
                  unit: AppStrings.unitKm,
                  textScaler: scaler,
                ) <=
                column &&
            measureStatWidth(
                  value: _speedTemplate,
                  style: liveStatStyle,
                  unit: AppStrings.unitKmPerHour,
                  textScaler: scaler,
                ) <=
                column;

        final Widget distanceStat = LiveStat(
          label: AppStrings.statDistance,
          value: distance,
          unit: AppStrings.unitKm,
          valueKey: ActiveRunScreen.distanceValueKey,
          style: liveStatStyle,
        );
        final Widget speedStat = LiveStat(
          label: AppStrings.statSpeed,
          value: speed,
          unit: AppStrings.unitKmPerHour,
          valueKey: ActiveRunScreen.speedValueKey,
          style: liveStatStyle,
        );

        if (fitsSideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: distanceStat),
              const SizedBox(width: AppSpacing.medium),
              Expanded(child: speedStat),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            distanceStat,
            const SizedBox(height: AppSpacing.itemGap),
            speedStat,
          ],
        );
      },
    );
  }
}

/// "PAUSED" next to the moving-time label. Outlined, not tinted, so the
/// orange text keeps 5.36:1 on the card.
class _PausedBadge extends StatelessWidget {
  const _PausedBadge();

  @override
  Widget build(BuildContext context) {
    final Color accent = context.palette.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        border: Border.all(color: accent, width: 1.5),
      ),
      child: Text(
        AppStrings.pausedBadge,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          color: accent,
        ),
      ),
    );
  }
}

// ─── Controls ───────────────────────────────────────────────────────────────

class _Controls extends StatelessWidget {
  const _Controls({
    required this.state,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  final ActiveRunState state;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final bool paused = state.phase == RunPhase.paused;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: RunControlButton(
            key: ActiveRunScreen.pauseResumeButtonKey,
            icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            label: paused ? AppStrings.resumeRun : AppStrings.pauseRun,
            onPressed: paused
                ? (state.canResume ? onResume : null)
                : (state.canPause ? onPause : null),
          ),
        ),
        const SizedBox(height: AppSpacing.itemGap),
        Expanded(
          child: RunControlButton(
            key: ActiveRunScreen.stopButtonKey,
            icon: Icons.stop_rounded,
            label: AppStrings.stopRun,
            filled: true,
            onPressed: state.canStop ? onStop : null,
          ),
        ),
      ],
    );
  }
}

class _LandscapeControls extends StatelessWidget {
  const _LandscapeControls({
    required this.state,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  final ActiveRunState state;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final bool paused = state.phase == RunPhase.paused;
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Expanded(
            child: RunControlButton(
              key: ActiveRunScreen.pauseResumeButtonKey,
              icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              label: paused ? AppStrings.resumeRun : AppStrings.pauseRun,
              onPressed: paused
                  ? (state.canResume ? onResume : null)
                  : (state.canPause ? onPause : null),
            ),
          ),
          const SizedBox(width: AppSpacing.small),
          Expanded(
            child: RunControlButton(
              key: ActiveRunScreen.stopButtonKey,
              icon: Icons.stop_rounded,
              label: AppStrings.stopRun,
              filled: true,
              onPressed: state.canStop ? onStop : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Messages ───────────────────────────────────────────────────────────────

class _IssueBanner extends StatelessWidget {
  const _IssueBanner({
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback? onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.all(
            Radius.circular(AppSpacing.radiusTile),
          ),
          border: Border.all(color: palette.error, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(Icons.error_outline, color: palette.error),
                ),
                const SizedBox(width: AppSpacing.small),
                Expanded(
                  child: Text(
                    message,
                    style: AppTextStyles.of(context).body.copyWith(
                      color: palette.isDark
                          ? palette.textPrimary
                          : AppColors.canyonBrownDeep,
                    ),
                  ),
                ),
              ],
            ),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                if (onRetry != null)
                  TextButton(
                    key: ActiveRunScreen.issueRetryButtonKey,
                    onPressed: onRetry,
                    child: const Text(AppStrings.tryAgain),
                  ),
                TextButton(
                  key: ActiveRunScreen.issueDismissButtonKey,
                  onPressed: onDismiss,
                  child: const Text(AppStrings.dismiss),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen message with large actions (failed start, unresolved stop).
class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryKey,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final Key primaryKey;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final String? secondary = secondaryLabel;
    final AppPalette palette = context.palette;
    final AppThemedTextStyles textStyles = AppTextStyles.of(context);
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(
                child: Icon(icon, size: 56, color: palette.accent),
              ),
              const SizedBox(height: AppSpacing.medium),
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: textStyles.heading,
                ),
              ),
              const SizedBox(height: AppSpacing.small),
              Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: textStyles.body,
                ),
              ),
              const SizedBox(height: AppSpacing.large),
              FilledButton(
                key: primaryKey,
                onPressed: onPrimary,
                child: Text(primaryLabel),
              ),
              if (secondary != null) ...[
                const SizedBox(height: AppSpacing.itemGap),
                OutlinedButton(
                  key: ActiveRunScreen.exitButtonKey,
                  onPressed: onSecondary,
                  child: Text(secondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

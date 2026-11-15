// Road Runner — Run Summary screen.
// Owner: Tharushi
// SRS reference: Section 8.4, FR-50, FR-51, FR-52, NFR-09, NFR-14
//
// Shows one completed run from an injected [RunSummary]. Values are only
// formatted for display; distance, pace, speed, splits and the fastest
// split come from the data/stats layer. Navigation is the parent's job.

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../app_strings.dart';
import '../home/widgets/icon_tile.dart';
import '../home/widgets/sky_header.dart';
import '../run/live_run_formatter.dart';
import '../run/widgets/live_stat.dart' show measureStatWidth;
import 'run_summary.dart';
import 'widgets/route_painter.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({
    super.key,
    required this.summary,
    required this.onBackToHome,
    required this.onOpenHistory,
    this.formatter = const LiveRunFormatter(),
  });

  final RunSummary summary;
  final VoidCallback onBackToHome;
  final VoidCallback onOpenHistory;

  /// Display-only conversions. Swap for the stats formatters when merged.
  final LiveRunFormatter formatter;

  static const Key homeButtonKey = Key('summary.home');
  static const Key historyButtonKey = Key('summary.history');
  static const Key routeAreaKey = Key('summary.route');
  static const Key dateKey = Key('summary.date');
  static Key splitRowKey(int km) => Key('summary.split.$km');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SkyHeader(
              title: AppStrings.appName,
              subtitle: AppStrings.summaryTitle,
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.medium,
                  0,
                  AppSpacing.medium,
                  AppSpacing.medium,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DateLine(startedAt: summary.startedAt),
                    const SizedBox(height: AppSpacing.itemGap),
                    _StatsCard(summary: summary, formatter: formatter),
                    const SizedBox(height: AppSpacing.medium),
                    _RouteCard(route: summary.route),
                    const SizedBox(height: AppSpacing.medium),
                    _SplitsCard(splits: summary.splits, formatter: formatter),
                    const SizedBox(height: AppSpacing.large),
                    FilledButton.icon(
                      key: homeButtonKey,
                      onPressed: onBackToHome,
                      icon: const Icon(Icons.home_outlined),
                      label: const Text(AppStrings.backToHome),
                    ),
                    const SizedBox(height: AppSpacing.itemGap),
                    OutlinedButton.icon(
                      key: historyButtonKey,
                      onPressed: onOpenHistory,
                      icon: const Icon(Icons.bar_chart),
                      label: const Text(AppStrings.viewHistory),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Date ───────────────────────────────────────────────────────────────────

class _DateLine extends StatelessWidget {
  const _DateLine({required this.startedAt});

  final DateTime? startedAt;

  @override
  Widget build(BuildContext context) {
    final DateTime? at = startedAt?.toLocal();
    String text = AppStrings.summaryDateUnavailable;
    if (at != null) {
      final MaterialLocalizations l10n = MaterialLocalizations.of(context);
      text = AppStrings.summaryDateTime(
        l10n.formatFullDate(at),
        l10n.formatTimeOfDay(
          TimeOfDay.fromDateTime(at),
          alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
        ),
      );
    }
    return Row(
      children: [
        const ExcludeSemantics(
          child: Icon(
            Icons.calendar_today_outlined,
            size: 18,
            color: AppColors.canyonBrownMuted,
          ),
        ),
        const SizedBox(width: AppSpacing.small),
        Expanded(
          child: Text(
            text,
            key: SummaryScreen.dateKey,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ─── Stats ──────────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.summary, required this.formatter});

  final RunSummary summary;
  final LiveRunFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final List<(IconData, String, String)> stats = [
      (
        Icons.place_outlined,
        '${formatter.distanceKm(summary.distanceM)} ${AppStrings.unitKm}',
        AppStrings.statDistance,
      ),
      (
        Icons.timer_outlined,
        formatter.elapsed(summary.movingMs),
        AppStrings.statMovingTime,
      ),
      (
        Icons.speed,
        '${formatter.pace(summary.averagePaceSecPerKm)}${AppStrings.unitPerKm}',
        AppStrings.statAveragePaceLong,
      ),
      (
        Icons.directions_run,
        '${formatter.speedKmh(summary.averageSpeedMps)} '
            '${AppStrings.unitKmPerHour}',
        AppStrings.statAverageSpeed,
      ),
    ];
    final TextScaler scaler = MediaQuery.textScalerOf(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Two columns when every value fits on one line; else one.
            final double column =
                (constraints.maxWidth - AppSpacing.medium) / 2;
            final bool twoColumns = stats.every(
              (s) =>
                  measureStatWidth(
                    value: s.$2,
                    style: AppTextStyles.statValue,
                    textScaler: scaler,
                  ) <=
                  column,
            );
            final List<Widget> tiles = [
              for (final s in stats)
                _StatTile(icon: s.$1, value: s.$2, label: s.$3),
            ];
            if (!twoColumns) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < tiles.length; i++) ...[
                    if (i > 0) const Divider(height: AppSpacing.large),
                    tiles[i],
                  ],
                ],
              );
            }
            return Column(
              children: [
                for (int row = 0; row < 2; row++) ...[
                  if (row > 0) const Divider(height: AppSpacing.large),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: tiles[row * 2]),
                      const SizedBox(width: AppSpacing.medium),
                      Expanded(child: tiles[row * 2 + 1]),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: AppStrings.statSemantics(label, value),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: AppColors.burntOrangeDeep),
            const SizedBox(height: 4),
            Text(value, style: AppTextStyles.statValue),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

// ─── Route ──────────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final String? sub = subtitle;
    return Row(
      children: [
        IconTile(icon: icon),
        const SizedBox(width: AppSpacing.itemGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: AppTextStyles.sectionHeading),
              ),
              if (sub != null) Text(sub, style: AppTextStyles.caption),
            ],
          ),
        ),
      ],
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.route});

  final List<RoutePoint> route;

  @override
  Widget build(BuildContext context) {
    final bool drawable = RouteGeometry.canDraw(route);
    final bool speed = drawable && RouteGeometry.hasSpeed(route);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CardHeader(
              icon: Icons.route_outlined,
              title: AppStrings.routeTitle,
              subtitle: AppStrings.routeSubtitle,
            ),
            const SizedBox(height: AppSpacing.itemGap),
            LayoutBuilder(
              builder: (context, c) {
                // Large and close to square, so the route stays readable.
                final double height = (c.maxWidth * 0.85).clamp(220.0, 360.0);
                return ClipRRect(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(AppSpacing.radiusTile),
                  ),
                  child: Container(
                    key: SummaryScreen.routeAreaKey,
                    height: height,
                    color: AppColors.sand,
                    child: drawable
                        ? Semantics(
                            image: true,
                            label: speed
                                ? '${AppStrings.routeSemantics} '
                                      '${AppStrings.routeSemanticsSpeed}'
                                : AppStrings.routeSemantics,
                            child: CustomPaint(
                              painter: RoutePainter(points: route),
                              size: Size.infinite,
                            ),
                          )
                        : const _RouteTooShort(),
                  ),
                );
              },
            ),
            if (drawable) ...[
              const SizedBox(height: AppSpacing.itemGap),
              _RouteLegend(speed: speed),
            ],
          ],
        ),
      ),
    );
  }
}

class _RouteTooShort extends StatelessWidget {
  const _RouteTooShort();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.wrong_location_outlined,
                size: 40,
                color: AppColors.canyonBrownMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              AppStrings.routeTooShort,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteLegend extends StatelessWidget {
  const _RouteLegend({required this.speed});

  final bool speed;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = AppTextStyles.caption.copyWith(
      color: AppColors.canyonBrown,
    );
    return ExcludeSemantics(
      child: Wrap(
        spacing: AppSpacing.medium,
        runSpacing: AppSpacing.small,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _LegendItem(
            marker: const _Marker(color: AppColors.tealDeep, circle: true),
            label: AppStrings.routeStart,
            style: style,
          ),
          _LegendItem(
            marker: const _Marker(
              color: AppColors.burntOrangeDeep,
              circle: false,
            ),
            label: AppStrings.routeFinish,
            style: style,
          ),
          if (speed)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(AppStrings.routeSlower, style: style),
                Container(
                  width: 56,
                  height: 8,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    gradient: LinearGradient(
                      colors: [
                        RouteGeometry.slowColor,
                        RouteGeometry.fastColor,
                      ],
                    ),
                  ),
                ),
                Text(AppStrings.routeFaster, style: style),
              ],
            )
          else
            Text(AppStrings.routeNoSpeed, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.marker,
    required this.label,
    required this.style,
  });

  final Widget marker;
  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        marker,
        const SizedBox(width: 6),
        Text(label, style: style),
      ],
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.color, required this.circle});

  final Color color;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle
            ? null
            : const BorderRadius.all(Radius.circular(2)),
      ),
    );
  }
}

// ─── Splits ─────────────────────────────────────────────────────────────────

class _SplitsCard extends StatelessWidget {
  const _SplitsCard({required this.splits, required this.formatter});

  final List<SplitSummary> splits;
  final LiveRunFormatter formatter;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CardHeader(
              icon: Icons.bar_chart,
              title: AppStrings.splitsTitle,
            ),
            const SizedBox(height: AppSpacing.small),
            if (splits.isEmpty)
              Semantics(
                container: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.small,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.splitsUnderOneKm,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        AppStrings.splitsUnderOneKmDetail,
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              )
            else
              for (int i = 0; i < splits.length; i++) ...[
                if (i > 0 && !splits[i].isFastest && !splits[i - 1].isFastest)
                  const Divider(height: 1),
                _SplitRow(split: splits[i], formatter: formatter),
              ],
          ],
        ),
      ),
    );
  }
}

class _SplitRow extends StatelessWidget {
  const _SplitRow({required this.split, required this.formatter});

  final SplitSummary split;
  final LiveRunFormatter formatter;

  @override
  Widget build(BuildContext context) {
    // ms → s is a unit conversion: one full km's duration is its pace.
    final String pace = formatter.pace(split.durationMs / 1000);
    final bool fastest = split.isFastest;
    return Semantics(
      key: SummaryScreen.splitRowKey(split.km),
      container: true,
      label: AppStrings.splitSemantics(split.km, pace, fastest),
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
          decoration: fastest
              ? BoxDecoration(
                  // tealDeep text on this tint: 4.8:1.
                  color: AppColors.tealDeep.withValues(alpha: 0.10),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                  border: Border.all(color: AppColors.tealDeep, width: 1.5),
                )
              : null,
          child: Row(
            children: [
              Expanded(
                // Label and FASTEST badge wrap, so the pace never overflows.
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Wrap(
                    spacing: AppSpacing.small,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        AppStrings.splitKm(split.km),
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (fastest)
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bolt,
                              size: 18,
                              color: AppColors.tealDeep,
                            ),
                            SizedBox(width: 2),
                            Flexible(
                              child: Text(
                                AppStrings.splitFastest,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: AppColors.tealDeep,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.small),
              Text(pace, style: AppTextStyles.statValue.copyWith(fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }
}

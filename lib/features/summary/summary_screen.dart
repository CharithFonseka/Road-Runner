// Road Runner — Run Summary screen (UI kit Revision 5, Phase 2B.1).
// Owner: Tharushi
// SRS reference: Section 8.4, FR-50, FR-51, FR-52, NFR-09, NFR-14
//
// Shows one completed run from an injected [RunSummary]. Values are only
// formatted for display; distance, pace, average speed, splits and the
// fastest split come from the data/stats layer via the integrator. The
// screen never calculates them. Navigation is the parent's job; there is
// no navigation drawer here (Summary is reached from a run or History).
//
// The route card is unchanged in this phase (its redesign is Phase 2B.2).

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../app_strings.dart';
import '../home/widgets/sky_header.dart' show HeaderIconButton;
import '../run/live_run_formatter.dart';
import '../shared/app_navigation_drawer.dart' show DrawerLandscapePainter;
import 'run_summary.dart';
import 'widgets/route_painter.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({
    super.key,
    required this.summary,
    required this.onBackToHome,
    required this.onOpenHistory,
    this.formatter = const LiveRunFormatter(),
    this.onBack,
    this.isLoading = false,
  });

  final RunSummary summary;
  final VoidCallback onBackToHome;
  final VoidCallback onOpenHistory;

  /// Display-only conversions. Swap for the stats formatters when merged.
  final LiveRunFormatter formatter;

  /// Header Back button. Null uses [onBackToHome], the existing contextual
  /// exit (after a run the integrator pops to Home).
  final VoidCallback? onBack;

  /// True while the parent is still loading the run. Shows static
  /// skeletons instead of the stats, route and splits. Only set this while
  /// a load is really in progress.
  final bool isLoading;

  static const Key homeButtonKey = Key('summary.home');
  static const Key historyButtonKey = Key('summary.history');
  static const Key routeAreaKey = Key('summary.route');
  static const Key dateKey = Key('summary.date');
  static const Key backButtonKey = Key('summary.back');
  static const Key statsCardKey = Key('summary.stats');
  static const Key splitsCardKey = Key('summary.splits');
  static const Key loadingKey = Key('summary.loading');
  static const Key partialSplitKey = Key('summary.split.partial');
  static Key splitRowKey(int km) => Key('summary.split.$km');
  static Key statKey(SummaryStat stat) => Key('summary.stat.${stat.name}');

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.sand,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryHeader(
            startedAt: summary.startedAt,
            onBack: onBack ?? onBackToHome,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.medium,
                4,
                AppSpacing.medium,
                AppSpacing.medium + bottomInset,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isLoading)
                    const _LoadingBody(key: loadingKey)
                  else ...[
                    _StatsCard(summary: summary, formatter: formatter),
                    const SizedBox(height: 10),
                    _RouteCard(route: summary.route),
                    const SizedBox(height: 10),
                    _SplitsCard(summary: summary, formatter: formatter),
                  ],
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
    );
  }
}

/// The four statistics, in display order.
enum SummaryStat { distance, movingTime, averagePace, averageSpeed }

// ─── Header ─────────────────────────────────────────────────────────────────

/// Sky header from the kit: 48dp Back, "Run summary" and the run's date
/// and start time, over the slim (40dp) desert strip. Text on the sky uses
/// [AppColors.canyonBrown] (5.56:1 or better).
class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.startedAt, required this.onBack});

  final DateTime? startedAt;
  final VoidCallback onBack;

  String _dateLine(BuildContext context) {
    final DateTime? at = startedAt?.toLocal();
    if (at == null) return AppStrings.summaryDateUnavailable;
    final MaterialLocalizations l10n = MaterialLocalizations.of(context);
    return AppStrings.summaryDateTime(
      AppStrings.runDate(at),
      l10n.formatTimeOfDay(
        TimeOfDay.fromDateTime(at),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.paddingOf(context).top;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.skyTop, AppColors.skyMid, AppColors.sand],
          stops: [0.0, 0.52, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.medium,
              topInset + AppSpacing.small,
              AppSpacing.medium,
              0,
            ),
            child: Row(
              children: [
                HeaderIconButton(
                  key: SummaryScreen.backButtonKey,
                  icon: Icons.arrow_back_rounded,
                  tooltip: AppStrings.summaryBack,
                  onPressed: onBack,
                ),
                const SizedBox(width: AppSpacing.itemGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: const Text(
                          AppStrings.summaryTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                            color: AppColors.canyonBrown,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _dateLine(context),
                        key: SummaryScreen.dateKey,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                          color: AppColors.canyonBrown,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const ExcludeSemantics(
            child: SizedBox(
              height: 40,
              width: double.infinity,
              child: CustomPaint(painter: DrawerLandscapePainter()),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats ──────────────────────────────────────────────────────────────────

/// One formatted statistic: number, unit and whether it is a placeholder.
class _Stat {
  const _Stat(this.stat, this.number, this.unit, this.label, this.available);

  final SummaryStat stat;
  final String number;
  final String unit;
  final String label;
  final bool available;

  /// The full visible text, e.g. "4.21 km" or "6:12/km".
  String get text => '$number$unit';
}

const TextStyle _statNumberStyle = TextStyle(
  fontSize: 19,
  fontWeight: FontWeight.w700,
  height: 1.2,
  color: AppColors.tealDeep,
  fontFeatures: [FontFeature.tabularFigures()],
);
const TextStyle _statUnitStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  color: AppColors.canyonBrownMuted,
);
const TextStyle _statLabelStyle = TextStyle(
  fontSize: 12,
  height: 1.3,
  color: AppColors.canyonBrownMuted,
);

/// UI kit stat strip: four value/label pairs separated by hairlines. Falls
/// back to a 2 × 2 grid, then to one stat per line, when values would not
/// fit (narrow phones, large text). Never truncates a value.
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.summary, required this.formatter});

  final RunSummary summary;
  final LiveRunFormatter formatter;

  List<_Stat> _stats() {
    final String distance = formatter.distanceKm(summary.distanceM);
    final String moving = formatter.elapsed(summary.movingMs);
    final String pace = formatter.pace(summary.averagePaceSecPerKm);
    final String speed = formatter.speedKmh(summary.averageSpeedMps);
    return [
      _Stat(
        SummaryStat.distance,
        distance,
        ' ${AppStrings.unitKm}',
        AppStrings.statDistance,
        distance != LiveRunFormatter.distancePlaceholder,
      ),
      _Stat(
        SummaryStat.movingTime,
        moving,
        '',
        AppStrings.statMovingTime,
        moving != LiveRunFormatter.elapsedPlaceholder,
      ),
      _Stat(
        SummaryStat.averagePace,
        pace,
        AppStrings.unitPerKm,
        AppStrings.statAveragePaceLong,
        pace != LiveRunFormatter.pacePlaceholder,
      ),
      _Stat(
        SummaryStat.averageSpeed,
        speed,
        ' ${AppStrings.unitKmPerHour}',
        AppStrings.statAverageSpeed,
        speed != LiveRunFormatter.speedPlaceholder,
      ),
    ];
  }

  static double _width(String text, TextStyle style, TextScaler scaler) {
    final TextPainter p = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final double w = p.width;
    p.dispose();
    return w;
  }

  static double _valueWidth(_Stat s, TextScaler scaler) =>
      _width(s.number, _statNumberStyle, scaler) +
      _width(s.unit, _statUnitStyle, scaler);

  @override
  Widget build(BuildContext context) {
    final List<_Stat> stats = _stats();
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    return Card(
      key: SummaryScreen.statsCardKey,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: LayoutBuilder(
          builder: (context, c) {
            bool fits(int perRow) {
              final double column = (c.maxWidth - (perRow - 1)) / perRow - 8;
              return stats.every((s) => _valueWidth(s, scaler) <= column);
            }

            if (fits(4)) return _row(stats);
            if (fits(2)) {
              return Column(
                children: [
                  _row(stats.sublist(0, 2)),
                  const Divider(height: 17, indent: 12, endIndent: 12),
                  _row(stats.sublist(2)),
                ],
              );
            }
            return Column(
              children: [
                for (int i = 0; i < stats.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 13, indent: 12, endIndent: 12),
                  _StatLine(stat: stats[i]),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _row(List<_Stat> stats) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < stats.length; i++) ...[
            if (i > 0)
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.divider,
              ),
            Expanded(child: _StatTile(stat: stats[i])),
          ],
        ],
      ),
    );
  }
}

String _statSpeech(_Stat s) => AppStrings.statSemantics(
  s.label,
  s.available ? s.text : AppStrings.statUnavailable,
);

Widget _statValue(_Stat s, {TextAlign align = TextAlign.center}) => Text.rich(
  TextSpan(
    text: s.number,
    style: _statNumberStyle,
    children: [
      if (s.unit.isNotEmpty) TextSpan(text: s.unit, style: _statUnitStyle),
    ],
  ),
  textAlign: align,
  maxLines: 1,
  softWrap: false,
);

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});

  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: SummaryScreen.statKey(stat.stat),
      container: true,
      label: _statSpeech(stat),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _statValue(stat),
            const SizedBox(height: 3),
            Text(
              stat.label,
              textAlign: TextAlign.center,
              style: _statLabelStyle,
            ),
          ],
        ),
      ),
    );
  }
}

/// Narrowest layout: "Label ........ value".
class _StatLine extends StatelessWidget {
  const _StatLine({required this.stat});

  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: SummaryScreen.statKey(stat.stat),
      container: true,
      label: _statSpeech(stat),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: Text(stat.label, style: _statLabelStyle)),
            const SizedBox(width: AppSpacing.small),
            Flexible(
              flex: 2,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: _statValue(stat, align: TextAlign.end),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Route ──────────────────────────────────────────────────────────────────

/// UI kit "Your route" card: header, parchment map with scale grid, the
/// route on a white underlay, a scale pill, then the legend.
class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.route});

  final List<RoutePoint> route;

  /// Kit map is 328 × 232.
  static const double _mapAspect = 232 / 328;

  @override
  Widget build(BuildContext context) {
    final bool drawable = RouteGeometry.canDraw(route);
    final bool speed = drawable && RouteGeometry.hasSpeed(route);
    final bool gaps =
        drawable && RouteGeometry.gapSegments(route).contains(true);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.small,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    AppStrings.routeTitle,
                    style: AppTextStyles.sectionHeading,
                  ),
                ),
                const Text(
                  AppStrings.routeSubtitle,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.itemGap),
            LayoutBuilder(
              builder: (context, c) {
                final double height = (c.maxWidth * _mapAspect).clamp(
                  220.0,
                  360.0,
                );
                return ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(14)),
                  child: Container(
                    key: SummaryScreen.routeAreaKey,
                    height: height,
                    color: RouteGeometry.mapColor,
                    child: drawable
                        ? _RouteMap(
                            route: route,
                            size: Size(c.maxWidth, height),
                            speed: speed,
                          )
                        : const _RouteTooShort(),
                  ),
                );
              },
            ),
            if (drawable) ...[
              const SizedBox(height: AppSpacing.itemGap),
              _RouteLegend(speed: speed, gaps: gaps),
            ],
          ],
        ),
      ),
    );
  }
}

/// The drawn route plus its scale pill. The pill's bar length comes from
/// the same layout the painter uses, so it is true to the drawing.
class _RouteMap extends StatelessWidget {
  const _RouteMap({
    required this.route,
    required this.size,
    required this.speed,
  });

  final List<RoutePoint> route;
  final Size size;
  final bool speed;

  @override
  Widget build(BuildContext context) {
    final RouteScale? scale = RouteGeometry.layout(route, size)?.scaleBar();
    final StringBuffer label = StringBuffer(AppStrings.routeSemantics);
    if (speed) label.write(' ${AppStrings.routeSemanticsSpeed}');
    if (scale != null) {
      label.write(' ${AppStrings.routeSemanticsScale(scale.label)}');
    }
    return Semantics(
      image: true,
      label: label.toString(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: RoutePainter(points: route),
            size: Size.infinite,
          ),
          if (scale != null)
            Positioned(
              left: 10,
              bottom: 10,
              child: ExcludeSemantics(child: _ScalePill(scale: scale)),
            ),
        ],
      ),
    );
  }
}

class _ScalePill extends StatelessWidget {
  const _ScalePill({required this.scale});

  final RouteScale scale;

  static const Key barKey = Key('summary.route.scaleBar');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: const BoxDecoration(
        color: Color(0xF0FBF3E6),
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bar with end ticks, exactly scale.pixels long.
          SizedBox(
            key: barKey,
            width: scale.pixels,
            height: 8,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppColors.canyonBrown, width: 2),
                  right: BorderSide(color: AppColors.canyonBrown, width: 2),
                  bottom: BorderSide(color: AppColors.canyonBrown, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            scale.label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.canyonBrown,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// No route, or fewer than two distinct points. Nothing is simulated.
class _RouteTooShort extends StatelessWidget {
  const _RouteTooShort();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Semantics(
          container: true,
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
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                AppStrings.routeTooShortDetail,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kit legend: Start / Finish / grid note, then the three pace bands. The
/// swatch colours are the exact [RouteGeometry] band colours.
class _RouteLegend extends StatelessWidget {
  const _RouteLegend({required this.speed, required this.gaps});

  final bool speed;
  final bool gaps;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = AppTextStyles.caption.copyWith(
      color: AppColors.canyonBrown,
    );
    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.medium,
            runSpacing: AppSpacing.small,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _LegendItem(
                marker: const _Marker(
                  color: RouteGeometry.startColor,
                  circle: true,
                ),
                label: AppStrings.routeStart,
                style: style,
              ),
              _LegendItem(
                marker: const _Marker(
                  color: RouteGeometry.finishColor,
                  circle: false,
                ),
                label: AppStrings.routeFinish,
                style: style,
              ),
              const Text(
                AppStrings.routeGridNote,
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.small),
          Wrap(
            spacing: AppSpacing.medium,
            runSpacing: AppSpacing.small,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (speed)
                for (final RouteBand band in RouteBand.values)
                  _LegendItem(
                    marker: _Swatch(color: RouteGeometry.bandColor(band)),
                    label: switch (band) {
                      RouteBand.slower => AppStrings.routeSlower,
                      RouteBand.steady => AppStrings.routeSteady,
                      RouteBand.faster => AppStrings.routeFaster,
                    },
                    style: style,
                  )
              else
                const Text(
                  AppStrings.routeNoSpeed,
                  style: AppTextStyles.caption,
                ),
              if (gaps)
                _LegendItem(
                  marker: const _Swatch(
                    color: RouteGeometry.noSpeedColor,
                    dashed: true,
                  ),
                  label: AppStrings.routeGap,
                  style: style,
                ),
            ],
          ),
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

/// Start (circle with white centre) or finish (rounded square), as drawn.
class _Marker extends StatelessWidget {
  const _Marker({required this.color, required this.circle});

  final Color color;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle
            ? null
            : const BorderRadius.all(Radius.circular(2)),
      ),
      child: circle
          ? Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

/// 18 × 5 band swatch (kit), or a dashed one for GPS gaps.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, this.dashed = false});

  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    if (dashed) {
      return SizedBox(
        width: 18,
        height: 5,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (int i = 0; i < 3; i++)
              Container(width: 4, height: 2, color: color),
          ],
        ),
      );
    }
    return Container(
      width: 18,
      height: 5,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(Radius.circular(3)),
      ),
    );
  }
}

// ─── Splits ─────────────────────────────────────────────────────────────────

/// UI kit splits card: tile + "Splits" header, then one row per full
/// kilometre (the flagged fastest one highlighted), then the optional
/// partial split.
class _SplitsCard extends StatelessWidget {
  const _SplitsCard({required this.summary, required this.formatter});

  final RunSummary summary;
  final LiveRunFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final List<SplitSummary> splits = summary.splits;
    final PartialSplitSummary? partial = summary.partialSplit;
    final double? distance = summary.distanceM;
    final bool underOneKm = distance != null && distance < 1000;
    return Card(
      key: SummaryScreen.splitsCardKey,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Row(
                children: [
                  const _SmallTile(icon: Icons.bar_chart_rounded),
                  const SizedBox(width: AppSpacing.itemGap),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: const Text(
                        AppStrings.splitsTitle,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          color: AppColors.canyonBrown,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (splits.isEmpty && partial == null)
              _SplitsMessage(
                title: underOneKm
                    ? AppStrings.splitsUnderOneKm
                    : AppStrings.splitsUnavailable,
                detail: underOneKm
                    ? AppStrings.splitsUnderOneKmDetail
                    : AppStrings.splitsUnavailableDetail,
              )
            else ...[
              for (int i = 0; i < splits.length; i++) ...[
                if (i > 0 && !splits[i].isFastest && !splits[i - 1].isFastest)
                  const Divider(height: 1),
                _SplitRow(split: splits[i], formatter: formatter),
              ],
              if (partial != null) ...[
                if (splits.isNotEmpty && !splits.last.isFastest)
                  const Divider(height: 1),
                _PartialSplitRow(split: partial, formatter: formatter),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SmallTile extends StatelessWidget {
  const _SmallTile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: AppColors.iconTile,
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        child: Icon(icon, size: 20, color: AppColors.burntOrangeDeep),
      ),
    );
  }
}

class _SplitsMessage extends StatelessWidget {
  const _SplitsMessage({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: AppColors.canyonBrown,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: const TextStyle(
                fontSize: 13,
                height: 18 / 13,
                color: AppColors.canyonBrownMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const TextStyle _splitLabelStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w500,
  height: 1.3,
  color: AppColors.canyonBrown,
);
const TextStyle _splitTimeStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w700,
  height: 1.3,
  color: AppColors.tealDeep,
  fontFeatures: [FontFeature.tabularFigures()],
);

class _SplitRow extends StatelessWidget {
  const _SplitRow({required this.split, required this.formatter});

  final SplitSummary split;
  final LiveRunFormatter formatter;

  @override
  Widget build(BuildContext context) {
    // A full kilometre's time is its pace per km. Shown as a duration so a
    // very slow kilometre still reads as a real time, never a placeholder.
    final String time = formatter.elapsed(split.durationMs);
    final bool fastest = split.isFastest;
    return Semantics(
      key: SummaryScreen.splitRowKey(split.km),
      container: true,
      label: AppStrings.splitSemantics(split.km, time, fastest),
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        margin: fastest
            ? const EdgeInsets.symmetric(horizontal: 8)
            : EdgeInsets.zero,
        padding: EdgeInsets.symmetric(horizontal: fastest ? 8 : 16),
        decoration: fastest
            ? BoxDecoration(
                // tealDeep text on this tint over the card: 4.8:1.
                color: AppColors.tealDeep.withValues(alpha: 0.10),
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              )
            : null,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                // Label and FASTEST badge wrap, so the time never overflows.
                child: Wrap(
                  spacing: 10,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(AppStrings.splitKm(split.km), style: _splitLabelStyle),
                    if (fastest)
                      const Text(
                        AppStrings.splitFastest,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: AppColors.tealDeep,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.small),
            Text(time, style: _splitTimeStyle),
          ],
        ),
      ),
    );
  }
}

class _PartialSplitRow extends StatelessWidget {
  const _PartialSplitRow({required this.split, required this.formatter});

  final PartialSplitSummary split;
  final LiveRunFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final String km = formatter.distanceKm(split.distanceM);
    final String time = formatter.elapsed(split.durationMs);
    return Semantics(
      key: SummaryScreen.partialSplitKey,
      container: true,
      label: AppStrings.splitPartialSemantics(km, time),
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      AppStrings.splitPartialKm(km),
                      style: _splitLabelStyle,
                    ),
                    const Text(
                      AppStrings.splitPartial,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.canyonBrownMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.small),
              Text(time, style: _splitTimeStyle),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Loading ────────────────────────────────────────────────────────────────

/// Static skeletons the size of the real cards. No shimmer, so nothing
/// moves for users who asked for reduced motion. Read as "Loading run
/// summary".
class _LoadingBody extends StatelessWidget {
  const _LoadingBody({super.key});

  static Widget _block(double width, double height, {double radius = 8}) =>
      Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0x1A5B3A29), // canyonBrown 10%
          borderRadius: BorderRadius.all(Radius.circular(radius)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: AppStrings.summaryLoading,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
              child: Row(
                children: [
                  for (int i = 0; i < 4; i++)
                    Expanded(
                      child: Column(
                        children: [
                          _block(48, 18),
                          const SizedBox(height: 7),
                          _block(36, 10),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.medium),
              child: LayoutBuilder(
                builder: (context, c) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _block(110, 18),
                    const SizedBox(height: AppSpacing.itemGap),
                    _block(
                      c.maxWidth,
                      (c.maxWidth * 0.85).clamp(220.0, 360.0),
                      radius: AppSpacing.radiusTile,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.medium),
              child: Column(
                children: [
                  for (int i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: Row(
                        children: [
                          _block(46, 14),
                          const Spacer(),
                          _block(40, 14),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

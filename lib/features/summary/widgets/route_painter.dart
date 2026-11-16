// Road Runner — top-down route drawing (no map tiles, no network).
// Owner: Tharushi
// SRS reference: FR-51, Section 8.4
//
// Draws ONLY the supplied coordinates: no roads, landmarks or invented
// points. Projection, scale and colouring here are for drawing only; they
// are not running statistics.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../app_strings.dart';
import '../run_summary.dart';

/// Pace band of a route segment, from this run's own speed distribution.
enum RouteBand { slower, steady, faster }

/// A scale-bar length that matches the drawing exactly.
@immutable
class RouteScale {
  const RouteScale({required this.metres, required this.pixels});

  /// Ground distance the bar represents (a "nice" value: 1, 2, 2.5, 5 ×10ⁿ).
  final double metres;

  /// On-screen length of that distance at the current fit.
  final double pixels;

  /// "500 m", "1 km", "2.5 km".
  String get label => RouteGeometry.distanceLabel(metres);
}

/// Projected positions plus the ground scale of the fit.
@immutable
class RouteLayout {
  const RouteLayout({required this.positions, required this.metresPerPixel});

  final List<Offset> positions;

  /// Ground metres per logical pixel, identical in x and y.
  final double metresPerPixel;

  /// The largest nice scale-bar length that fits in [maxPixels].
  RouteScale scaleBar({double maxPixels = 110}) =>
      RouteGeometry.scaleFor(metresPerPixel, maxPixels: maxPixels);
}

/// Turns lat/lon into canvas positions.
///
/// Uses an equirectangular projection around the route's mean latitude:
/// x = lon · cos(meanLat), y = lat, both in degrees, then ×
/// [metresPerDegree]. At running-route scale this keeps distances and
/// shape (a 1 km square stays square). One uniform scale fits the route
/// inside the area, which is then centred; north is up.
class RouteGeometry {
  RouteGeometry._();

  /// Metres per degree of latitude on a sphere of mean Earth radius
  /// (6 371 008.8 m). Error versus WGS84 is under 0.6% at any latitude.
  static const double metresPerDegree = 6371008.8 * math.pi / 180;

  /// Very short routes are never magnified beyond this, so GPS jitter of a
  /// few metres does not fill the card like a real route.
  static const double minMetresPerPixel = 0.25;

  /// True when there is something to draw: at least two points that are
  /// not all at the same position.
  static bool canDraw(List<RoutePoint> points) {
    if (points.length < 2) return false;
    final RoutePoint first = points.first;
    return points.any((p) => p.lat != first.lat || p.lon != first.lon);
  }

  static double _cosMeanLat(List<RoutePoint> points) {
    double latSum = 0;
    for (final RoutePoint p in points) {
      latSum += p.lat;
    }
    return math.cos((latSum / points.length) * math.pi / 180);
  }

  /// Positions and ground scale for [points] in [size], keeping [padding]
  /// free on every side. Null if [canDraw] is false.
  static RouteLayout? layout(
    List<RoutePoint> points,
    Size size, {
    double padding = 24,
  }) {
    if (!canDraw(points)) return null;
    final double cosLat = _cosMeanLat(points);

    // Ground metres east (x) and north (y) from an arbitrary origin.
    final List<Offset> raw = [
      for (final RoutePoint p in points)
        Offset(p.lon * cosLat * metresPerDegree, p.lat * metresPerDegree),
    ];
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;
    for (final Offset o in raw) {
      minX = math.min(minX, o.dx);
      maxX = math.max(maxX, o.dx);
      minY = math.min(minY, o.dy);
      maxY = math.max(maxY, o.dy);
    }

    final double spanX = maxX - minX;
    final double spanY = maxY - minY;
    final double availW = math.max(1.0, size.width - 2 * padding);
    final double availH = math.max(1.0, size.height - 2 * padding);
    // Pixels per metre: one value for both axes keeps the aspect ratio.
    double scale = math.min(
      spanX > 0 ? availW / spanX : double.infinity,
      spanY > 0 ? availH / spanY : double.infinity,
    );
    scale = math.min(scale, 1 / minMetresPerPixel);

    final double left = padding + (availW - spanX * scale) / 2;
    final double top = padding + (availH - spanY * scale) / 2;
    return RouteLayout(
      positions: [
        for (final Offset o in raw)
          Offset(left + (o.dx - minX) * scale, top + (maxY - o.dy) * scale),
      ],
      metresPerPixel: 1 / scale,
    );
  }

  /// Canvas positions only (see [layout]). Null if [canDraw] is false.
  static List<Offset>? project(
    List<RoutePoint> points,
    Size size, {
    double padding = 24,
  }) => layout(points, size, padding: padding)?.positions;

  // ─── Scale bar ──────────────────────────────────────────────────────────

  static const List<double> _niceMetres = [
    1, 2, 2.5, 5, 10, 20, 25, 50, 100, 200, 250, 500, //
    1000, 2000, 2500, 5000, 10000, 20000, 25000, 50000, 100000,
  ];

  /// Largest nice distance whose bar is at most [maxPixels] long (the
  /// smallest one if even that is longer). Its pixel length is exact.
  static RouteScale scaleFor(double metresPerPixel, {double maxPixels = 110}) {
    double chosen = _niceMetres.first;
    for (final double m in _niceMetres) {
      if (m / metresPerPixel <= maxPixels) chosen = m;
    }
    return RouteScale(metres: chosen, pixels: chosen / metresPerPixel);
  }

  /// "250 m", "1 km", "2.5 km".
  static String distanceLabel(double metres) {
    if (metres < 1000) {
      final String m = metres == metres.roundToDouble()
          ? metres.toStringAsFixed(0)
          : metres.toStringAsFixed(1);
      return '$m ${AppStrings.unitM}';
    }
    final double km = metres / 1000;
    final String k = km == km.roundToDouble()
        ? km.toStringAsFixed(0)
        : km.toStringAsFixed(1);
    return '$k ${AppStrings.unitKm}';
  }

  // ─── Gaps ───────────────────────────────────────────────────────────────

  /// Ground length of segment i → i+1 in metres.
  static List<double> segmentLengths(List<RoutePoint> points) {
    if (points.length < 2) return const [];
    final double cosLat = _cosMeanLat(points);
    return [
      for (int i = 1; i < points.length; i++)
        math.sqrt(
              math.pow((points[i].lon - points[i - 1].lon) * cosLat, 2) +
                  math.pow(points[i].lat - points[i - 1].lat, 2),
            ) *
            metresPerDegree,
    ];
  }

  /// Segments that jump much further than the run's normal point spacing
  /// (likely lost GPS): longer than [gapMinMetres] AND [gapFactor] × the
  /// median segment. They are drawn dashed and uncoloured, because nothing
  /// was recorded along them. Needs at least 3 non-zero segments.
  static List<bool> gapSegments(List<RoutePoint> points) {
    final List<double> lengths = segmentLengths(points);
    final List<double> moving = [
      for (final double l in lengths)
        if (l > 0) l,
    ]..sort();
    if (moving.length < 3) return List<bool>.filled(lengths.length, false);
    final double median = moving[moving.length ~/ 2];
    final double limit = math.max(gapMinMetres, gapFactor * median);
    return [for (final double l in lengths) l > limit];
  }

  static const double gapMinMetres = 100;
  static const double gapFactor = 8;

  // ─── Pace bands ─────────────────────────────────────────────────────────

  /// True if any point has a usable speed.
  static bool hasSpeed(List<RoutePoint> points) =>
      points.any((p) => _usable(p.speedMps));

  static bool _usable(double? v) => v != null && v.isFinite && v >= 0;

  /// Band of each segment i → i+1 (length points − 1), or null without
  /// speed.
  ///
  /// A segment uses the speed recorded at its end point (or its start
  /// point if the end has none). Bands split THIS run's recorded point
  /// speeds into thirds (terciles): the slowest third is "slower", the
  /// fastest third "faster", the rest "steady". A run at one constant
  /// speed is all "steady".
  static List<RouteBand?> segmentBands(List<RoutePoint> points) {
    if (points.length < 2) return const [];
    final List<double> speeds = [
      for (final RoutePoint p in points)
        if (_usable(p.speedMps)) p.speedMps!,
    ]..sort();
    final double q1 = _quantile(speeds, 1 / 3);
    final double q2 = _quantile(speeds, 2 / 3);
    final bool flat = speeds.isEmpty || speeds.first == speeds.last;
    return [
      for (int i = 1; i < points.length; i++)
        _band(_segmentSpeed(points, i), q1, q2, flat),
    ];
  }

  static double? _segmentSpeed(List<RoutePoint> points, int i) {
    if (_usable(points[i].speedMps)) return points[i].speedMps;
    if (_usable(points[i - 1].speedMps)) return points[i - 1].speedMps;
    return null;
  }

  static RouteBand? _band(double? s, double q1, double q2, bool flat) {
    if (s == null) return null;
    if (flat) return RouteBand.steady;
    if (s < q1 || (s == q1 && s < q2)) return RouteBand.slower;
    if (s > q2 || (s == q2 && s > q1)) return RouteBand.faster;
    return RouteBand.steady;
  }

  /// Linear-interpolated quantile of sorted [v] (0 for an empty list).
  static double _quantile(List<double> v, double q) {
    if (v.isEmpty) return 0;
    final double pos = (v.length - 1) * q;
    final int lo = pos.floor();
    final int hi = pos.ceil();
    return v[lo] + (v[hi] - v[lo]) * (pos - lo);
  }

  /// Colour of each segment (see [segmentBands]); null without speed.
  static List<Color?> segmentColors(List<RoutePoint> points) => [
    for (final RouteBand? b in segmentBands(points))
      b == null ? null : bandColor(b),
  ];

  static Color bandColor(RouteBand band) => switch (band) {
    RouteBand.slower => slowColor,
    RouteBand.steady => steadyColor,
    RouteBand.faster => fastColor,
  };

  /// Position 0 (slower) … 1 (faster) mapped to its band colour.
  static Color speedColor(double t) => bandColor(
    t < 1 / 3
        ? RouteBand.slower
        : (t > 2 / 3 ? RouteBand.faster : RouteBand.steady),
  );

  // UI kit Revision 5 route colours (light mode). Each is ≥ 3:1 against the
  // map background ([mapColor]) as required for graphics. The kit's steady
  // orange (#EB6621) is 2.7:1 there, so a slightly deeper orange is used.
  static const Color slowColor = Color(0xFF5182D5);
  static const Color steadyColor = Color(0xFFD9581A);
  static const Color fastColor = Color(0xFF87211C);

  /// Route colour when no speed was recorded.
  static const Color plainColor = AppColors.canyonBrown;

  /// Segments without speed inside a coloured route, and GPS gaps.
  static const Color noSpeedColor = AppColors.canyonBrownMuted;

  /// Neutral map "parchment" from the kit.
  static const Color mapColor = Color(0xFFF3E6CF);

  /// Scale grid lines (canyonBrown at 8%).
  static const Color gridColor = Color(0x145B3A29);

  static const Color startColor = AppColors.liveBlue;
  static const Color finishColor = AppColors.burntOrangeDeep;
}

/// Paints the scale grid, the route on a white underlay, and the start
/// (blue circle) and finish (orange square) markers.
class RoutePainter extends CustomPainter {
  RoutePainter({required this.points, this.padding = 24});

  final List<RoutePoint> points;
  final double padding;

  static const double strokeWidth = 5.5;
  static const double underlayWidth = 10;
  static const double markerRadius = 8.5;

  /// Last positions painted, for tests.
  @visibleForTesting
  List<Offset>? lastPositions;

  /// Last grid spacing painted (px), for tests.
  @visibleForTesting
  double? lastGridSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final RouteLayout? layout = RouteGeometry.layout(
      points,
      size,
      padding: padding,
    );
    lastPositions = layout?.positions;
    lastGridSpacing = null;
    if (layout == null) return;
    final List<Offset> pos = layout.positions;

    // Grid: square cells exactly one scale-bar length wide, aligned to the
    // start point, so it shows true ground distance and nothing else.
    final double spacing = layout.scaleBar().pixels;
    if (spacing >= 12) {
      lastGridSpacing = spacing;
      final Paint grid = Paint()
        ..color = RouteGeometry.gridColor
        ..strokeWidth = 1;
      final Offset o = pos.first;
      for (double x = o.dx % spacing; x <= size.width; x += spacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      }
      for (double y = o.dy % spacing; y <= size.height; y += spacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      }
    }

    final List<bool> gaps = RouteGeometry.gapSegments(points);
    final bool coloured = RouteGeometry.hasSpeed(points);
    final List<Color?> colors = coloured
        ? RouteGeometry.segmentColors(points)
        : const [];

    // White underlay keeps the line readable over the grid.
    final Paint underlay = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = underlayWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Path recorded = Path();
    for (int i = 1; i < pos.length; i++) {
      if (gaps[i - 1]) continue;
      recorded
        ..moveTo(pos[i - 1].dx, pos[i - 1].dy)
        ..lineTo(pos[i].dx, pos[i].dy);
    }
    canvas.drawPath(recorded, underlay);

    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (int i = 1; i < pos.length; i++) {
      if (gaps[i - 1]) {
        _dashed(canvas, pos[i - 1], pos[i]);
        continue;
      }
      line.color = coloured
          ? (colors[i - 1] ?? RouteGeometry.noSpeedColor)
          : RouteGeometry.plainColor;
      canvas.drawLine(pos[i - 1], pos[i], line);
    }

    _drawStart(canvas, pos.first);
    _drawFinish(canvas, pos.last); // on top when start and finish meet
  }

  /// GPS gap: thin dashed line, no pace colour.
  void _dashed(Canvas canvas, Offset a, Offset b) {
    final Paint p = Paint()
      ..color = RouteGeometry.noSpeedColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final double length = (b - a).distance;
    if (length == 0) return;
    final Offset dir = (b - a) / length;
    for (double d = 0; d < length; d += 9) {
      canvas.drawLine(a + dir * d, a + dir * math.min(d + 4, length), p);
    }
  }

  void _drawStart(Canvas canvas, Offset c) {
    canvas.drawCircle(c, markerRadius + 3, Paint()..color = AppColors.white);
    canvas.drawCircle(
      c,
      markerRadius,
      Paint()..color = RouteGeometry.startColor,
    );
    canvas.drawCircle(c, 2.6, Paint()..color = AppColors.white);
  }

  void _drawFinish(Canvas canvas, Offset c) {
    const double r = 7;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: 2 * r + 5, height: 2 * r + 5),
        const Radius.circular(4),
      ),
      Paint()..color = AppColors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: 2 * r, height: 2 * r),
        const Radius.circular(2),
      ),
      Paint()..color = RouteGeometry.finishColor,
    );
  }

  @override
  bool shouldRepaint(RoutePainter oldDelegate) =>
      !identical(oldDelegate.points, points) || oldDelegate.padding != padding;
}

// Road Runner — top-down route drawing (no map tiles, no network).
// Owner: Tharushi
// SRS reference: FR-51, Section 8.4
//
// Draws ONLY the supplied coordinates: no roads, landmarks or invented
// points. Projection and colouring here are for drawing only; they are not
// running statistics.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../run_summary.dart';

/// Turns lat/lon into canvas positions.
///
/// Uses an equirectangular projection around the route's mean latitude:
/// x = lon · cos(meanLat), y = lat. At running-route scale this keeps the
/// shape's proportions (a 1 km square stays square). One uniform scale
/// fits the route inside the area, which is then centred; north is up.
class RouteGeometry {
  RouteGeometry._();

  /// True when there is something to draw: at least two points that are
  /// not all at the same position.
  static bool canDraw(List<RoutePoint> points) {
    if (points.length < 2) return false;
    final RoutePoint first = points.first;
    return points.any((p) => p.lat != first.lat || p.lon != first.lon);
  }

  /// Canvas positions for [points] in [size], keeping [padding] free on
  /// every side. Null if [canDraw] is false.
  static List<Offset>? project(
    List<RoutePoint> points,
    Size size, {
    double padding = 24,
  }) {
    if (!canDraw(points)) return null;

    double latSum = 0;
    for (final RoutePoint p in points) {
      latSum += p.lat;
    }
    final double cosLat = math.cos((latSum / points.length) * math.pi / 180);

    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;
    final List<Offset> raw = [
      for (final RoutePoint p in points) Offset(p.lon * cosLat, p.lat),
    ];
    for (final Offset o in raw) {
      minX = math.min(minX, o.dx);
      maxX = math.max(maxX, o.dx);
      minY = math.min(minY, o.dy);
      maxY = math.max(maxY, o.dy);
    }

    final double spanX = maxX - minX;
    final double spanY = maxY - minY;
    final double availW = math.max(0.0, size.width - 2 * padding);
    final double availH = math.max(0.0, size.height - 2 * padding);
    final double scale = math.min(
      spanX > 0 ? availW / spanX : double.infinity,
      spanY > 0 ? availH / spanY : double.infinity,
    );

    final double left = padding + (availW - spanX * scale) / 2;
    final double top = padding + (availH - spanY * scale) / 2;
    return [
      for (final Offset o in raw)
        Offset(left + (o.dx - minX) * scale, top + (maxY - o.dy) * scale),
    ];
  }

  /// True if any point has a usable speed.
  static bool hasSpeed(List<RoutePoint> points) =>
      points.any((p) => _usable(p.speedMps));

  static bool _usable(double? v) => v != null && v.isFinite && v >= 0;

  /// Colour of each segment i → i+1 (length points − 1).
  ///
  /// A segment uses the speed recorded at its end point (or its start
  /// point if the end has none), placed on this run's own slowest→fastest
  /// range. Segments with no speed at either end are null (drawn neutral).
  static List<Color?> segmentColors(List<RoutePoint> points) {
    if (points.length < 2) return const [];
    double lo = double.infinity, hi = -double.infinity;
    for (final RoutePoint p in points) {
      final double? s = p.speedMps;
      if (_usable(s)) {
        lo = math.min(lo, s!);
        hi = math.max(hi, s);
      }
    }
    return [
      for (int i = 1; i < points.length; i++)
        _colorFor(
          _usable(points[i].speedMps)
              ? points[i].speedMps
              : (_usable(points[i - 1].speedMps)
                    ? points[i - 1].speedMps
                    : null),
          lo,
          hi,
        ),
    ];
  }

  static Color? _colorFor(double? speed, double lo, double hi) {
    if (speed == null) return null;
    final double t = hi > lo ? ((speed - lo) / (hi - lo)) : 0.5;
    return speedColor(t);
  }

  /// Slower (0) → faster (1). Every step is ≥ 4.7:1 on sand.
  static Color speedColor(double t) =>
      Color.lerp(slowColor, fastColor, t.clamp(0.0, 1.0))!;

  static const Color slowColor = AppColors.burntOrangeDeep;
  static const Color fastColor = AppColors.tealDeep;

  /// Route colour when no speed was recorded.
  static const Color plainColor = AppColors.canyonBrown;

  /// Segments without speed inside a coloured route.
  static const Color noSpeedColor = AppColors.canyonBrownMuted;
}

/// Paints the route with start (circle) and finish (square) markers.
class RoutePainter extends CustomPainter {
  RoutePainter({required this.points, this.padding = 24});

  final List<RoutePoint> points;
  final double padding;

  static const double strokeWidth = 5;
  static const double markerRadius = 9;

  /// Last positions painted, for tests.
  @visibleForTesting
  List<Offset>? lastPositions;

  @override
  void paint(Canvas canvas, Size size) {
    final List<Offset>? pos = RouteGeometry.project(
      points,
      size,
      padding: padding,
    );
    lastPositions = pos;
    if (pos == null) return;

    final bool coloured = RouteGeometry.hasSpeed(points);
    final List<Color?> colors = coloured
        ? RouteGeometry.segmentColors(points)
        : const [];

    // White casing under the line keeps it readable on any background.
    final Paint casing = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Path whole = Path()..addPolygon(pos, false);
    canvas.drawPath(whole, casing);

    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (!coloured) {
      canvas.drawPath(whole, line..color = RouteGeometry.plainColor);
    } else {
      for (int i = 1; i < pos.length; i++) {
        line.color = colors[i - 1] ?? RouteGeometry.noSpeedColor;
        canvas.drawLine(pos[i - 1], pos[i], line);
      }
    }

    _drawStart(canvas, pos.first);
    _drawFinish(canvas, pos.last);
  }

  void _drawStart(Canvas canvas, Offset c) {
    canvas.drawCircle(c, markerRadius + 3, Paint()..color = AppColors.white);
    canvas.drawCircle(c, markerRadius, Paint()..color = AppColors.tealDeep);
  }

  void _drawFinish(Canvas canvas, Offset c) {
    final double r = markerRadius;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: 2 * r + 6, height: 2 * r + 6),
        const Radius.circular(5),
      ),
      Paint()..color = AppColors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: 2 * r, height: 2 * r),
        const Radius.circular(3),
      ),
      Paint()..color = AppColors.burntOrangeDeep,
    );
  }

  @override
  bool shouldRepaint(RoutePainter oldDelegate) =>
      !identical(oldDelegate.points, points) || oldDelegate.padding != padding;
}

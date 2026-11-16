// Road Runner — GPS route drawing in light and dark (Phase 3B.4).
// Owner: Tharushi
// SRS reference: FR-51, Section 8.4
//
// Checks that the night route uses the moonlit map palette, that every
// meaningful graphic stays ≥ 3:1 on the map, and that only colours change:
// projection, scale, grid, gap detection and pace banding are identical in
// both themes.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/app_colors.dart';
import 'package:road_runner/core/theme/app_palette.dart';
import 'package:road_runner/features/summary/run_summary.dart';
import 'package:road_runner/features/summary/widgets/route_painter.dart';

// Test coordinates only — not real runs.

/// ~10 m north per step at the equator.
const double _step = 10 / RouteGeometry.metresPerDegree;

List<RoutePoint> _line(int n, {double lat0 = 0, double? speed}) => [
  for (int i = 0; i < n; i++)
    RoutePoint(lat: lat0 + i * _step, lon: 0, speedMps: speed),
];

/// A wiggly route with three speeds, so every pace band is drawn.
final List<RoutePoint> _banded = [
  for (int i = 0; i < 30; i++)
    RoutePoint(lat: i * _step, lon: (i % 5) * _step, speedMps: 2.0 + i % 3),
];

/// Two runs of points separated by a GPS gap (~1 km jump).
final List<RoutePoint> _gapped = [
  ..._line(6, speed: 2),
  ..._line(6, lat0: 0.01, speed: 3),
];

/// No speed recorded at all.
final List<RoutePoint> _plain = _line(8);

const Size _mapSize = Size(328, 232);

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final double la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Records the colour of every draw call, grouped by kind.
///
/// `Paint` stores colours as 32-bit floats, so a colour read back from it
/// can differ from the original in the last bits. Everything is compared as
/// 8-bit ARGB instead (see [_c]).
class _RecordingCanvas extends Fake implements Canvas {
  final List<Color> lines = [];
  final List<double> lineWidths = [];
  final List<Color> paths = [];
  final List<Color> circles = [];
  final List<Color> rrects = [];

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    lines.add(_c(paint.color));
    lineWidths.add(paint.strokeWidth);
  }

  @override
  void drawPath(Path path, Paint paint) => paths.add(_c(paint.color));

  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      circles.add(_c(paint.color));

  @override
  void drawRRect(RRect rrect, Paint paint) => rrects.add(_c(paint.color));
}

/// Normalises a colour to its 8-bit ARGB value.
Color _c(Color c) => Color(c.toARGB32());

_RecordingCanvas _record(List<RoutePoint> pts, AppPalette? palette) {
  final _RecordingCanvas canvas = _RecordingCanvas();
  RoutePainter(points: pts, palette: palette).paint(canvas, _mapSize);
  return canvas;
}

void main() {
  final AppPalette night = AppPalette.dark;
  final AppPalette day = AppPalette.light;

  group('Night route colours', () {
    test('pace bands use the moonlit palette', () {
      expect(
        RouteGeometry.bandColorFor(RouteBand.slower, night),
        AppDarkColors.routeSlow,
      );
      expect(
        RouteGeometry.bandColorFor(RouteBand.steady, night),
        AppDarkColors.routeSteady,
      );
      expect(
        RouteGeometry.bandColorFor(RouteBand.faster, night),
        AppDarkColors.routeFast,
      );
    });

    test('day band colours are exactly the existing constants', () {
      for (final RouteBand b in RouteBand.values) {
        expect(RouteGeometry.bandColorFor(b, day), RouteGeometry.bandColor(b));
      }
      expect(
        RouteGeometry.segmentColorsFor(_banded, day),
        RouteGeometry.segmentColors(_banded),
      );
    });

    test('painter draws night grid, casing, bands and markers', () {
      final _RecordingCanvas c = _record(_banded, night);
      // Grid lines are 1px; route segments are the 5.5px stroke.
      final Set<Color> grid = {
        for (int i = 0; i < c.lines.length; i++)
          if (c.lineWidths[i] == 1) c.lines[i],
      };
      final Set<Color> route = {
        for (int i = 0; i < c.lines.length; i++)
          if (c.lineWidths[i] == RoutePainter.strokeWidth) c.lines[i],
      };
      expect(grid, {_c(night.mapGrid)});
      expect(route, {
        _c(night.routeSlow),
        _c(night.routeSteady),
        _c(night.routeFast),
      });
      expect(c.paths, [_c(night.routeCasing)]);
      expect(c.circles, [
        _c(night.routeCasing),
        _c(night.routeStart),
        _c(AppColors.white),
      ]);
      expect(c.rrects, [_c(night.routeCasing), _c(night.routeFinish)]);
    });

    test('route without speed is drawn in the night plain colour', () {
      final _RecordingCanvas c = _record(_plain, night);
      final Set<Color> route = {
        for (int i = 0; i < c.lines.length; i++)
          if (c.lineWidths[i] == RoutePainter.strokeWidth) c.lines[i],
      };
      expect(route, {_c(night.routePlain)});
    });

    test('GPS gaps are dashed in the night no-speed colour', () {
      final _RecordingCanvas c = _record(_gapped, night);
      final Set<Color> dashes = {
        for (int i = 0; i < c.lines.length; i++)
          if (c.lineWidths[i] == 2) c.lines[i],
      };
      expect(dashes, {_c(night.routeNoSpeed)});
    });

    test('null palette paints exactly the original day colours', () {
      final _RecordingCanvas legacy = _record(_banded, null);
      final _RecordingCanvas explicit = _record(_banded, day);
      expect(legacy.lines, explicit.lines);
      expect(legacy.paths, [_c(AppColors.white)]);
      expect(legacy.circles, [
        _c(AppColors.white),
        _c(RouteGeometry.startColor),
        _c(AppColors.white),
      ]);
      expect(legacy.rrects, [
        _c(AppColors.white),
        _c(RouteGeometry.finishColor),
      ]);
      final Set<Color> grid = {
        for (int i = 0; i < legacy.lines.length; i++)
          if (legacy.lineWidths[i] == 1) legacy.lines[i],
      };
      expect(grid, {_c(RouteGeometry.gridColor)});
    });

    test('a palette change triggers a repaint; same palette does not', () {
      final RoutePainter a = RoutePainter(points: _banded, palette: day);
      expect(
        RoutePainter(points: _banded, palette: night).shouldRepaint(a),
        isTrue,
      );
      expect(
        RoutePainter(points: _banded, palette: day).shouldRepaint(a),
        isFalse,
      );
    });
  });

  group('Night route contrast (graphics need 3:1)', () {
    final Map<String, Color> graphics = {
      'slower band': night.routeSlow,
      'steady band': night.routeSteady,
      'faster band': night.routeFast,
      'plain route': night.routePlain,
      'no-speed / gap': night.routeNoSpeed,
      'start marker': night.routeStart,
      'finish marker': night.routeFinish,
    };
    for (final MapEntry<String, Color> g in graphics.entries) {
      test('${g.key} is ≥ 3:1 on the night map and its casing', () {
        expect(
          _contrast(g.value, night.mapBackground),
          greaterThanOrEqualTo(3),
        );
        expect(_contrast(g.value, night.routeCasing), greaterThanOrEqualTo(3));
      });
    }

    test('bands are distinguishable from each other', () {
      final List<Color> bands = night.routeBands;
      expect(bands.toSet(), hasLength(3));
    });

    test('scale bar and label are readable on the night scale pill', () {
      final Color pill = Color.alphaBlend(
        night.surface.withAlpha(0xF0),
        night.mapBackground,
      );
      expect(_contrast(night.textPrimary, pill), greaterThanOrEqualTo(4.5));
    });

    test('day scale pill colour is unchanged (#F0FBF3E6)', () {
      expect(day.surface.withAlpha(0xF0), const Color(0xF0FBF3E6));
    });
  });

  group('Geometry is identical in both themes', () {
    for (final (String name, List<RoutePoint> pts) in [
      ('banded', _banded),
      ('gapped', _gapped),
      ('plain', _plain),
    ]) {
      test('$name route: same positions and grid spacing', () {
        final RoutePainter d = RoutePainter(points: pts, palette: day);
        final RoutePainter n = RoutePainter(points: pts, palette: night);
        for (final RoutePainter p in [d, n]) {
          final ui.PictureRecorder r = ui.PictureRecorder();
          p.paint(Canvas(r), _mapSize);
          r.endRecording().dispose();
        }
        expect(n.lastPositions, d.lastPositions);
        expect(n.lastGridSpacing, d.lastGridSpacing);
        expect(
          n.lastPositions,
          RouteGeometry.layout(pts, _mapSize, padding: 24)!.positions,
        );
      });
    }

    test('scale bar still matches ground distance', () {
      final RouteLayout layout = RouteGeometry.layout(_banded, _mapSize)!;
      final RouteScale s = layout.scaleBar();
      expect(s.pixels * layout.metresPerPixel, closeTo(s.metres, 1e-6));
    });

    test('gap detection and banding are palette-independent', () {
      expect(RouteGeometry.gapSegments(_gapped).where((g) => g), hasLength(1));
      expect(
        RouteGeometry.segmentColorsFor(_banded, night).length,
        RouteGeometry.segmentBands(_banded).length,
      );
      final List<RouteBand?> bands = RouteGeometry.segmentBands(_banded);
      final List<Color?> nightColours = RouteGeometry.segmentColorsFor(
        _banded,
        night,
      );
      for (int i = 0; i < bands.length; i++) {
        expect(
          nightColours[i],
          bands[i] == null
              ? isNull
              : RouteGeometry.bandColorFor(bands[i]!, night),
        );
      }
    });

    test('too-short routes paint nothing in either theme', () {
      for (final AppPalette p in [day, night]) {
        final _RecordingCanvas c = _record(const [
          RoutePoint(lat: 1, lon: 1),
          RoutePoint(lat: 1, lon: 1),
        ], p);
        expect(c.lines, isEmpty);
        expect(c.circles, isEmpty);
      }
    });
  });
}

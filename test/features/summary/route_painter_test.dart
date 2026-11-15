// Road Runner — route geometry and painter tests.
// Owner: Tharushi

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/features/summary/run_summary.dart';
import 'package:road_runner/features/summary/widgets/route_painter.dart';

/// Test coordinates only (not real runs).
const List<RoutePoint> _square = [
  RoutePoint(lat: 0.0, lon: 0.0),
  RoutePoint(lat: 0.0, lon: 0.01),
  RoutePoint(lat: 0.01, lon: 0.01),
  RoutePoint(lat: 0.01, lon: 0.0),
];

void _paint(RoutePainter painter, Size size) {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), size);
  recorder.endRecording().dispose();
}

void main() {
  group('canDraw', () {
    test('empty and single-point routes cannot be drawn', () {
      expect(RouteGeometry.canDraw(const []), isFalse);
      expect(
        RouteGeometry.canDraw(const [RoutePoint(lat: 1, lon: 1)]),
        isFalse,
      );
    });

    test('repeated identical points cannot be drawn', () {
      expect(
        RouteGeometry.canDraw(const [
          RoutePoint(lat: 1, lon: 1),
          RoutePoint(lat: 1, lon: 1),
        ]),
        isFalse,
      );
    });

    test('two distinct points can be drawn', () {
      expect(
        RouteGeometry.canDraw(const [
          RoutePoint(lat: 1, lon: 1),
          RoutePoint(lat: 1, lon: 1.001),
        ]),
        isTrue,
      );
    });
  });

  group('project', () {
    test('keeps every point inside the padded area and centres it', () {
      const Size size = Size(300, 200);
      final List<Offset> pos = RouteGeometry.project(
        _square,
        size,
        padding: 20,
      )!;
      expect(pos, hasLength(4));
      final double minX = pos.map((o) => o.dx).reduce(math.min);
      final double maxX = pos.map((o) => o.dx).reduce(math.max);
      final double minY = pos.map((o) => o.dy).reduce(math.min);
      final double maxY = pos.map((o) => o.dy).reduce(math.max);

      // A square at the equator stays square: height-limited to 160.
      expect(maxY - minY, closeTo(160, 0.01));
      expect(maxX - minX, closeTo(160, 0.01));
      // Centred horizontally.
      expect(minX, closeTo((300 - 160) / 2, 0.01));
      expect(minY, closeTo(20, 0.01));
    });

    test('north is up: higher latitude is drawn higher', () {
      final List<Offset> pos = RouteGeometry.project(
        _square,
        const Size(200, 200),
      )!;
      expect(pos[2].dy, lessThan(pos[1].dy));
    });

    test('longitude is scaled by cos(latitude) to keep proportions', () {
      // 0.01° lon × 0.01° lat at 60° N is twice as tall as wide.
      const List<RoutePoint> north = [
        RoutePoint(lat: 60.0, lon: 10.0),
        RoutePoint(lat: 60.0, lon: 10.01),
        RoutePoint(lat: 60.01, lon: 10.01),
      ];
      final List<Offset> pos = RouteGeometry.project(
        north,
        const Size(400, 400),
        padding: 0,
      )!;
      final double w = (pos[1].dx - pos[0].dx).abs();
      final double h = (pos[2].dy - pos[1].dy).abs();
      expect(h / w, closeTo(1 / math.cos(60.005 * math.pi / 180), 0.01));
    });

    test('a straight east-west line is centred vertically', () {
      final List<Offset> pos = RouteGeometry.project(
        const [RoutePoint(lat: 5, lon: 5), RoutePoint(lat: 5, lon: 5.01)],
        const Size(200, 100),
        padding: 10,
      )!;
      expect(pos[0].dy, closeTo(50, 0.01));
      expect(pos[0].dx, closeTo(10, 0.01));
      expect(pos[1].dx, closeTo(190, 0.01));
    });

    test('returns null when nothing can be drawn', () {
      expect(RouteGeometry.project(const [], const Size(100, 100)), isNull);
    });
  });

  group('segment colours', () {
    test('slowest segment is orange, fastest is teal', () {
      const List<RoutePoint> pts = [
        RoutePoint(lat: 0, lon: 0, speedMps: 2),
        RoutePoint(lat: 0, lon: 0.001, speedMps: 2),
        RoutePoint(lat: 0, lon: 0.002, speedMps: 4),
      ];
      final List<Color?> c = RouteGeometry.segmentColors(pts);
      expect(c, [RouteGeometry.slowColor, RouteGeometry.fastColor]);
    });

    test('segments without any speed are null (neutral)', () {
      const List<RoutePoint> pts = [
        RoutePoint(lat: 0, lon: 0, speedMps: 3),
        RoutePoint(lat: 0, lon: 0.001, speedMps: 5),
        RoutePoint(lat: 0, lon: 0.002),
        RoutePoint(lat: 0, lon: 0.003),
      ];
      final List<Color?> c = RouteGeometry.segmentColors(pts);
      expect(c[0], RouteGeometry.fastColor);
      // Falls back to the start point's speed.
      expect(c[1], RouteGeometry.fastColor);
      expect(c[2], isNull);
    });

    test('equal speeds use the middle colour', () {
      const List<RoutePoint> pts = [
        RoutePoint(lat: 0, lon: 0, speedMps: 3),
        RoutePoint(lat: 0, lon: 0.001, speedMps: 3),
      ];
      expect(
        RouteGeometry.segmentColors(pts).single,
        RouteGeometry.speedColor(0.5),
      );
    });

    test('no speed data at all is detected', () {
      expect(RouteGeometry.hasSpeed(_square), isFalse);
      expect(
        RouteGeometry.hasSpeed(const [
          RoutePoint(lat: 0, lon: 0, speedMps: double.nan),
        ]),
        isFalse,
      );
    });
  });

  group('RoutePainter', () {
    test('paints a multi-point route using the projected positions', () {
      final RoutePainter painter = RoutePainter(points: _square);
      _paint(painter, const Size(300, 300));
      expect(painter.lastPositions, hasLength(4));
    });

    test('paints nothing (and does not throw) for too-short routes', () {
      for (final List<RoutePoint> pts in [
        const <RoutePoint>[],
        const [RoutePoint(lat: 1, lon: 1)],
      ]) {
        final RoutePainter painter = RoutePainter(points: pts);
        _paint(painter, const Size(300, 300));
        expect(painter.lastPositions, isNull);
      }
    });

    test('repaints only when points change', () {
      final RoutePainter a = RoutePainter(points: _square);
      expect(a.shouldRepaint(RoutePainter(points: _square)), isFalse);
      expect(a.shouldRepaint(RoutePainter(points: const [])), isTrue);
    });
  });
}

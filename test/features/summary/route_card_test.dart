// Road Runner — Revision 5 route card (Phase 2B.2): projection accuracy,
// scale bar, pace bands, GPS gaps, legend.
// Owner: Tharushi
// SRS reference: FR-51, NFR-14

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/app_theme.dart';
import 'package:road_runner/features/app_strings.dart';
import 'package:road_runner/features/summary/run_summary.dart';
import 'package:road_runner/features/summary/summary_screen.dart';
import 'package:road_runner/features/summary/widgets/route_painter.dart';

// Test coordinates only — not real runs.

/// ~10 m north per step at the equator.
const double _step = 10 / RouteGeometry.metresPerDegree;

List<RoutePoint> _line(int n, {double lat0 = 0, double? speed}) => [
  for (int i = 0; i < n; i++)
    RoutePoint(lat: lat0 + i * _step, lon: 0, speedMps: speed),
];

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final double la = _lum(a), lb = _lum(b);
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

Future<void> _pump(WidgetTester tester, List<RoutePoint> route) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = const Size(360, 800) * 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: SummaryScreen(
        summary: RunSummary(runId: 'r', route: route),
        onBackToHome: () {},
        onOpenHistory: () {},
      ),
    ),
  );
}

void main() {
  group('projection accuracy', () {
    test('pixel distances × metres-per-pixel give true ground distance', () {
      // 0.01° east then 0.01° north at 60° N: 556 m east, 1112 m north.
      const List<RoutePoint> pts = [
        RoutePoint(lat: 60, lon: 10),
        RoutePoint(lat: 60, lon: 10.01),
        RoutePoint(lat: 60.01, lon: 10.01),
      ];
      final RouteLayout l = RouteGeometry.layout(pts, const Size(328, 232))!;
      final double east = (l.positions[1] - l.positions[0]).distance;
      final double north = (l.positions[2] - l.positions[1]).distance;
      expect(east * l.metresPerPixel, closeTo(556.0, 556 * 0.005));
      expect(north * l.metresPerPixel, closeTo(1111.95, 1111.95 * 0.005));
      // North is up, east is right.
      expect(l.positions[2].dy, lessThan(l.positions[1].dy));
      expect(l.positions[1].dx, greaterThan(l.positions[0].dx));
    });

    test('aspect ratio is kept (2:1 route draws 2:1)', () {
      final double d = 1000 / RouteGeometry.metresPerDegree;
      final List<RoutePoint> pts = [
        const RoutePoint(lat: 0, lon: 0),
        RoutePoint(lat: 0, lon: 2 * d),
        RoutePoint(lat: d, lon: 2 * d),
      ];
      final List<Offset> p = RouteGeometry.project(pts, const Size(328, 232))!;
      final double w = (p[1] - p[0]).distance;
      final double h = (p[2] - p[1]).distance;
      expect(w / h, closeTo(2, 0.001));
    });

    test('tiny jitter is not magnified past the zoom cap', () {
      // Two points 1 m apart.
      const List<RoutePoint> pts = [
        RoutePoint(lat: 0, lon: 0),
        RoutePoint(lat: 1 / RouteGeometry.metresPerDegree, lon: 0),
      ];
      final RouteLayout l = RouteGeometry.layout(pts, const Size(328, 232))!;
      expect(l.metresPerPixel, RouteGeometry.minMetresPerPixel);
      expect((l.positions[1] - l.positions[0]).distance, closeTo(4, 0.01));
    });
  });

  group('scale bar', () {
    test('picks the largest nice distance that fits, with exact length', () {
      final RouteScale s500 = RouteGeometry.scaleFor(5); // 500 m = 100 px
      expect(s500.metres, 500);
      expect(s500.pixels, 100);
      expect(s500.label, '500 m');

      final RouteScale s1k = RouteGeometry.scaleFor(10);
      expect(s1k.metres, 1000);
      expect(s1k.label, '1 km');

      final RouteScale s100 = RouteGeometry.scaleFor(1);
      expect(s100.metres, 100);
      expect(s100.pixels, 100);
    });

    test('bar length always equals metres ÷ metres-per-pixel', () {
      for (final double mpp in [0.25, 0.7, 3.3, 7.9, 42.0, 260.0]) {
        final RouteScale s = RouteGeometry.scaleFor(mpp);
        expect(s.pixels * mpp, closeTo(s.metres, 1e-9));
        expect(s.pixels, lessThanOrEqualTo(110));
      }
    });

    test('labels', () {
      expect(RouteGeometry.distanceLabel(250), '250 m');
      expect(RouteGeometry.distanceLabel(2.5), '2.5 m');
      expect(RouteGeometry.distanceLabel(2500), '2.5 km');
      expect(RouteGeometry.distanceLabel(10000), '10 km');
    });

    test('painter grid spacing equals the scale-bar length', () {
      final List<RoutePoint> pts = _line(40);
      const Size size = Size(328, 232);
      final RoutePainter p = RoutePainter(points: pts);
      final ui.PictureRecorder r = ui.PictureRecorder();
      p.paint(Canvas(r), size);
      r.endRecording().dispose();
      expect(
        p.lastGridSpacing,
        RouteGeometry.layout(pts, size)!.scaleBar().pixels,
      );
    });
  });

  group('pace bands', () {
    test('terciles of this run’s speeds give slower / steady / faster', () {
      final List<RoutePoint> pts = [
        for (int i = 0; i < 6; i++)
          RoutePoint(lat: i * _step, lon: 0, speedMps: i + 1.0),
      ];
      expect(RouteGeometry.segmentBands(pts), [
        RouteBand.slower,
        RouteBand.steady,
        RouteBand.steady,
        RouteBand.faster,
        RouteBand.faster,
      ]);
      expect(
        RouteGeometry.segmentColors(pts),
        RouteGeometry.segmentBands(pts).map((b) => RouteGeometry.bandColor(b!)),
      );
    });

    test('constant speed is all steady; no speed is null', () {
      expect(RouteGeometry.segmentBands(_line(4, speed: 3)).toSet(), {
        RouteBand.steady,
      });
      expect(RouteGeometry.segmentBands(_line(3)), [null, null]);
    });

    test('band colours are distinct and readable on the map (≥ 3:1)', () {
      final List<Color> c = RouteBand.values
          .map(RouteGeometry.bandColor)
          .toList();
      expect(c.toSet().length, 3);
      for (final Color color in c) {
        expect(_contrast(color, RouteGeometry.mapColor), greaterThan(3.0));
      }
    });
  });

  group('GPS gaps', () {
    test('a jump far beyond normal spacing is flagged', () {
      final List<RoutePoint> pts = [
        ..._line(5),
        ..._line(5, lat0: 5 * _step + 500 / RouteGeometry.metresPerDegree),
      ];
      final List<bool> g = RouteGeometry.gapSegments(pts);
      expect(g.where((x) => x).length, 1);
      expect(g[4], isTrue);
    });

    test('short routes and steady spacing have no gaps', () {
      expect(RouteGeometry.gapSegments(_line(3)), [false, false]);
      expect(RouteGeometry.gapSegments(_line(20)).contains(true), isFalse);
      expect(RouteGeometry.gapSegments(const []), isEmpty);
    });

    test('painting a route with a gap does not throw', () {
      final List<RoutePoint> pts = [
        ..._line(5, speed: 2),
        ..._line(5, lat0: 0.01, speed: 3),
      ];
      final RoutePainter p = RoutePainter(points: pts);
      final ui.PictureRecorder r = ui.PictureRecorder();
      p.paint(Canvas(r), const Size(328, 232));
      r.endRecording().dispose();
      expect(p.lastPositions, hasLength(10));
    });
  });

  group('route card', () {
    final List<RoutePoint> route = [
      for (int i = 0; i < 30; i++)
        RoutePoint(lat: i * _step, lon: (i % 5) * _step, speedMps: 2.0 + i % 3),
    ];

    testWidgets('kit header, legend and band swatches match the drawing', (
      tester,
    ) async {
      await _pump(tester, route);
      expect(find.text(AppStrings.routeTitle), findsOneWidget);
      expect(find.text(AppStrings.routeSubtitle), findsOneWidget);
      expect(find.text(AppStrings.routeGridNote), findsOneWidget);
      for (final String s in [
        AppStrings.routeSlower,
        AppStrings.routeSteady,
        AppStrings.routeFaster,
      ]) {
        expect(find.text(s), findsOneWidget);
      }
      for (final RouteBand b in RouteBand.values) {
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).color ==
                    RouteGeometry.bandColor(b),
          ),
          findsOneWidget,
        );
      }
      expect(find.text(AppStrings.routeGap), findsNothing);
    });

    testWidgets('scale pill shows the computed scale at its true length', (
      tester,
    ) async {
      await _pump(tester, route);
      final Size area = tester.getSize(find.byKey(SummaryScreen.routeAreaKey));
      final RouteScale s = RouteGeometry.layout(route, area)!.scaleBar();
      expect(find.text(s.label), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('summary.route.scaleBar'))).width,
        closeTo(s.pixels, 0.01),
      );
      expect(
        find.bySemanticsLabel(
          RegExp(RegExp.escape(AppStrings.routeSemanticsScale(s.label))),
        ),
        findsOneWidget,
      );
      // ~290 m route: never labelled with an unrelated 500 m.
      expect(s.metres, lessThan(500));
    });

    testWidgets('GPS gap legend appears only when a gap is drawn', (
      tester,
    ) async {
      await _pump(tester, [
        ..._line(6, speed: 2),
        ..._line(6, lat0: 0.01, speed: 3),
      ]);
      expect(find.text(AppStrings.routeGap), findsOneWidget);
    });

    testWidgets('identical points show the too-short state, no scale', (
      tester,
    ) async {
      await _pump(tester, const [
        RoutePoint(lat: 1, lon: 1),
        RoutePoint(lat: 1, lon: 1),
        RoutePoint(lat: 1, lon: 1),
      ]);
      expect(find.text(AppStrings.routeTooShort), findsOneWidget);
      expect(find.byKey(const Key('summary.route.scaleBar')), findsNothing);
      expect(find.text(AppStrings.routeGridNote), findsNothing);
    });
  });
}

// Road Runner — Run Summary in light and dark (Phase 3B.4).
// Owner: Tharushi
// SRS reference: FR-50–52, NFR-09, NFR-14, Section 8.4
//
// Checks the moonlit styling of the header, stats, route card, splits,
// short-run and loading states, the delete flow and navigation, and that
// the day styling is unchanged.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/app_colors.dart';
import 'package:road_runner/core/theme/app_palette.dart';
import 'package:road_runner/core/theme/app_theme.dart';
import 'package:road_runner/features/app_strings.dart';
import 'package:road_runner/features/shared/app_navigation_drawer.dart';
import 'package:road_runner/features/summary/run_summary.dart';
import 'package:road_runner/features/summary/summary_screen.dart';
import 'package:road_runner/features/summary/widgets/route_painter.dart';

// Test fixtures only — not real application data.

const double _step = 10 / RouteGeometry.metresPerDegree;

final List<RoutePoint> _route = [
  for (int i = 0; i < 30; i++)
    RoutePoint(lat: i * _step, lon: (i % 5) * _step, speedMps: 2.0 + i % 3),
];

/// Route with a ~1 km GPS gap in the middle.
final List<RoutePoint> _gapRoute = [
  for (int i = 0; i < 6; i++) RoutePoint(lat: i * _step, lon: 0, speedMps: 2),
  for (int i = 0; i < 6; i++)
    RoutePoint(lat: 0.01 + i * _step, lon: 0, speedMps: 3),
];

final RunSummary _full = RunSummary(
  runId: 'r1',
  startedAt: DateTime(2026, 11, 14, 6, 42),
  distanceM: 5020,
  movingMs: (32 * 60 + 15) * 1000,
  averagePaceSecPerKm: 385,
  averageSpeedMps: 2.594,
  route: _route,
  splits: const [
    SplitSummary(km: 1, durationMs: 380000),
    SplitSummary(km: 2, durationMs: 391000),
    SplitSummary(km: 3, durationMs: 378000, isFastest: true),
    SplitSummary(km: 4, durationMs: 387000),
    SplitSummary(km: 5, durationMs: 389000),
  ],
  partialSplit: const PartialSplitSummary(distanceM: 20, durationMs: 8000),
);

/// Short run: under 1 km, fewer than two GPS points, no pace or speed.
final RunSummary _short = RunSummary(
  runId: 'short',
  startedAt: DateTime(2026, 11, 14, 6, 42),
  distanceM: 0,
  movingMs: 42000,
  route: const [RoutePoint(lat: 1, lon: 1)],
);

class _Calls {
  int home = 0;
  int history = 0;
  int back = 0;
  final List<String> deleted = [];
}

Future<_Calls> _pump(
  WidgetTester tester, {
  required ThemeData theme,
  RunSummary? summary,
  bool loading = false,
  bool reduceMotion = false,
  Size size = const Size(360, 800),
  double textScale = 1.0,
  Future<void> Function(String runId)? onDeleteRun,
  bool withDelete = true,
}) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = size * 3.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final _Calls c = _Calls();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: SummaryScreen(
          summary: summary ?? _full,
          isLoading: loading,
          onBackToHome: () => c.home++,
          onOpenHistory: () => c.history++,
          onBack: () => c.back++,
          onDeleteRun: withDelete
              ? (onDeleteRun ?? (id) async => c.deleted.add(id))
              : null,
        ),
      ),
    ),
  );
  return c;
}

TextStyle _spanStyle(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).textSpan!.style!;

Color _textColour(WidgetTester tester, Finder f) =>
    tester.widget<Text>(f).style!.color!;

Finder _swatch(Color colour) => find.byWidgetPredicate(
  (w) =>
      w is Container &&
      w.decoration is BoxDecoration &&
      (w.decoration! as BoxDecoration).color == colour,
);

BoxDecoration _fastestDecoration(WidgetTester tester) {
  final Container row = tester.widget<Container>(
    find
        .descendant(
          of: find.byKey(SummaryScreen.splitRowKey(3)),
          matching: find.byType(Container),
        )
        .first,
  );
  return row.decoration! as BoxDecoration;
}

void main() {
  final AppPalette night = AppPalette.dark;

  group('Dark Summary styling', () {
    testWidgets('header: sky, slim landscape, title and date', (tester) async {
      await _pump(tester, theme: AppTheme.dark());
      final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, night.background);
      final DecoratedBox sky = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.byKey(SummaryScreen.dateKey),
              matching: find.byType(DecoratedBox),
            )
            .last,
      );
      expect((sky.decoration as BoxDecoration).gradient, night.skyGradient);
      final CustomPaint strip = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is DrawerLandscapePainter,
        ),
      );
      expect((strip.painter! as DrawerLandscapePainter).palette, same(night));
      expect(
        _textColour(tester, find.text(AppStrings.summaryTitle)),
        night.textPrimary,
      );
      expect(
        _textColour(tester, find.byKey(SummaryScreen.dateKey)),
        night.textPrimary,
      );
    });

    testWidgets('stats: mint values, secondary units and labels', (
      tester,
    ) async {
      await _pump(tester, theme: AppTheme.dark());
      final TextStyle distance = _spanStyle(tester, '5.02 km');
      expect(distance.color, night.stat);
      final TextSpan span =
          tester.widget<Text>(find.text('5.02 km')).textSpan! as TextSpan;
      expect(span.children!.single.style!.color, night.textSecondary);
      expect(
        _textColour(tester, find.text(AppStrings.statDistance)),
        night.textSecondary,
      );
      final Material card = tester.widget<Material>(
        find
            .descendant(
              of: find.byKey(SummaryScreen.statsCardKey),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(card.color, night.surface);
    });

    testWidgets('route card: navy map, night painter, legend, scale pill', (
      tester,
    ) async {
      await _pump(tester, theme: AppTheme.dark());
      final Container map = tester.widget<Container>(
        find.byKey(SummaryScreen.routeAreaKey),
      );
      expect(map.color, night.mapBackground);
      final CustomPaint paint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is RoutePainter,
        ),
      );
      expect((paint.painter! as RoutePainter).palette, same(night));
      for (final RouteBand b in RouteBand.values) {
        expect(
          _swatch(RouteGeometry.bandColorFor(b, night)),
          findsWidgets,
          reason: 'legend swatch for $b',
        );
      }
      expect(_swatch(night.routeStart), findsWidgets);
      expect(_swatch(night.routeFinish), findsWidgets);
      expect(
        _textColour(tester, find.text(AppStrings.routeSlower)),
        night.textPrimary,
      );
      expect(
        _textColour(tester, find.text(AppStrings.routeGridNote)),
        night.textSecondary,
      );

      // Scale pill: same true length as the drawing; night surface fill.
      final Size area = tester.getSize(find.byKey(SummaryScreen.routeAreaKey));
      final RouteScale s = RouteGeometry.layout(_route, area)!.scaleBar();
      expect(
        tester.getSize(find.byKey(const Key('summary.route.scaleBar'))).width,
        closeTo(s.pixels, 0.01),
      );
      expect(_textColour(tester, find.text(s.label)), night.textPrimary);
      expect(_swatch(night.surface.withAlpha(0xF0)), findsOneWidget);
    });

    testWidgets('GPS gap legend uses the night no-speed colour', (
      tester,
    ) async {
      await _pump(
        tester,
        theme: AppTheme.dark(),
        summary: RunSummary(runId: 'g', route: _gapRoute),
      );
      expect(find.text(AppStrings.routeGap), findsOneWidget);
      final Finder dash = find.descendant(
        of: find.ancestor(
          of: find.text(AppStrings.routeGap),
          matching: find.byType(Row),
        ),
        matching: find.byWidgetPredicate(
          (w) => w is Container && w.color == night.routeNoSpeed,
        ),
      );
      expect(dash, findsNWidgets(3));
    });

    testWidgets('splits: full rows, fastest highlight and partial split', (
      tester,
    ) async {
      await _pump(tester, theme: AppTheme.dark(), size: const Size(360, 1400));
      expect(_fastestDecoration(tester).color, night.highlight);
      Color inRow(Key row, String text) => _textColour(
        tester,
        find.descendant(of: find.byKey(row), matching: find.text(text)),
      );
      expect(inRow(SummaryScreen.splitRowKey(3), '6:18'), night.stat);
      expect(
        inRow(SummaryScreen.splitRowKey(3), AppStrings.splitFastest),
        night.stat,
      );
      expect(
        inRow(SummaryScreen.splitRowKey(1), AppStrings.splitKm(1)),
        night.textPrimary,
      );
      expect(
        inRow(SummaryScreen.partialSplitKey, AppStrings.splitPartial),
        night.textSecondary,
      );
      expect(inRow(SummaryScreen.partialSplitKey, '0:08'), night.stat);
      expect(
        _textColour(tester, find.text(AppStrings.splitsTitle)),
        night.textPrimary,
      );
    });

    testWidgets('short run / no GPS: too-short map and under-1-km splits', (
      tester,
    ) async {
      await _pump(tester, theme: AppTheme.dark(), summary: _short);
      expect(find.text(AppStrings.routeTooShort), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.wrong_location_outlined)).color,
        night.textSecondary,
      );
      expect(
        _textColour(tester, find.text(AppStrings.routeTooShort)),
        night.textPrimary,
      );
      expect(
        tester.widget<Container>(find.byKey(SummaryScreen.routeAreaKey)).color,
        night.mapBackground,
      );
      expect(find.text(AppStrings.splitsUnderOneKm), findsOneWidget);
      expect(
        _textColour(tester, find.text(AppStrings.splitsUnderOneKm)),
        night.textPrimary,
      );
      expect(find.byKey(const Key('summary.route.scaleBar')), findsNothing);
    });

    testWidgets('loading skeletons use the night skeleton fill', (
      tester,
    ) async {
      await _pump(tester, theme: AppTheme.dark(), loading: true);
      expect(find.byKey(SummaryScreen.loadingKey), findsOneWidget);
      expect(_swatch(night.skeleton), findsWidgets);
      expect(find.byType(ShaderMask), findsWidgets);
    });

    testWidgets('reduced motion: static skeletons, no shimmer (dark)', (
      tester,
    ) async {
      await _pump(
        tester,
        theme: AppTheme.dark(),
        loading: true,
        reduceMotion: true,
      );
      expect(_swatch(night.skeleton), findsWidgets);
      expect(find.byType(ShaderMask), findsNothing);
    });
  });

  group('Delete run in dark', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(SummaryScreen.deleteButtonKey));
      await tester.tap(find.byKey(SummaryScreen.deleteButtonKey));
      // The pending spinner animates while the dialog is open, so pump a
      // fixed time instead of settling (as the existing delete tests do).
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('delete button uses the readable night error colour', (
      tester,
    ) async {
      await _pump(tester, theme: AppTheme.dark());
      final OutlinedButton button = tester.widget<OutlinedButton>(
        find.byKey(SummaryScreen.deleteButtonKey),
      );
      expect(
        button.style!.foregroundColor!.resolve(<WidgetState>{}),
        night.error,
      );
      expect(button.style!.side!.resolve(<WidgetState>{})!.color, night.error);
    });

    testWidgets('confirmation dialog on the night surface; confirm deletes', (
      tester,
    ) async {
      final _Calls c = await _pump(tester, theme: AppTheme.dark());
      await openDialog(tester);
      expect(find.text(AppStrings.summaryDeleteTitle), findsOneWidget);
      final Material dialog = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(dialog.color, night.surface);
      await tester.tap(find.byKey(SummaryScreen.deleteConfirmButtonKey));
      await tester.pumpAndSettle();
      expect(c.deleted, ['r1']);
    });

    testWidgets('cancel keeps the run', (tester) async {
      final _Calls c = await _pump(tester, theme: AppTheme.dark());
      await openDialog(tester);
      await tester.tap(find.byKey(SummaryScreen.deleteCancelButtonKey));
      await tester.pumpAndSettle();
      expect(c.deleted, isEmpty);
      expect(find.byKey(SummaryScreen.deleteButtonKey), findsOneWidget);
    });

    testWidgets('failure shows the error snackbar and re-enables delete', (
      tester,
    ) async {
      await _pump(
        tester,
        theme: AppTheme.dark(),
        onDeleteRun: (_) async => throw Exception('disk full'),
      );
      await openDialog(tester);
      await tester.tap(find.byKey(SummaryScreen.deleteConfirmButtonKey));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.summaryDeleteFailed), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(SummaryScreen.deleteButtonKey))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('pending delete disables the button until it completes', (
      tester,
    ) async {
      final Completer<void> done = Completer<void>();
      await _pump(
        tester,
        theme: AppTheme.dark(),
        onDeleteRun: (_) => done.future,
      );
      await openDialog(tester);
      await tester.tap(find.byKey(SummaryScreen.deleteConfirmButtonKey));
      await tester.pump();
      expect(find.text(AppStrings.summaryDeleting), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(SummaryScreen.deleteButtonKey))
            .onPressed,
        isNull,
      );
      done.complete();
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.summaryDeleteRun), findsOneWidget);
    });
  });

  group('Navigation callbacks in both themes', () {
    for (final Brightness b in Brightness.values) {
      testWidgets('back, home and history (${b.name})', (tester) async {
        final _Calls c = await _pump(tester, theme: AppTheme.forBrightness(b));
        await tester.tap(find.byKey(SummaryScreen.backButtonKey));
        await tester.ensureVisible(find.byKey(SummaryScreen.homeButtonKey));
        await tester.tap(find.byKey(SummaryScreen.homeButtonKey));
        await tester.ensureVisible(find.byKey(SummaryScreen.historyButtonKey));
        await tester.tap(find.byKey(SummaryScreen.historyButtonKey));
        expect((c.back, c.home, c.history), (1, 1, 1));
      });
    }
  });

  group('Light Summary is unchanged', () {
    testWidgets('day colours for background, stats, map and splits', (
      tester,
    ) async {
      await _pump(tester, theme: AppTheme.light(), size: const Size(360, 1400));
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AppColors.sand,
      );
      expect(_spanStyle(tester, '5.02 km').color, AppColors.tealDeep);
      expect(
        tester.widget<Container>(find.byKey(SummaryScreen.routeAreaKey)).color,
        RouteGeometry.mapColor,
      );
      expect(
        _fastestDecoration(tester).color,
        AppColors.tealDeep.withValues(alpha: 0.10),
      );
      for (final RouteBand b in RouteBand.values) {
        expect(_swatch(RouteGeometry.bandColor(b)), findsWidgets);
      }
      expect(_swatch(const Color(0xF0FBF3E6)), findsOneWidget);
      final OutlinedButton delete = tester.widget<OutlinedButton>(
        find.byKey(SummaryScreen.deleteButtonKey),
      );
      expect(
        delete.style!.foregroundColor!.resolve(<WidgetState>{}),
        AppColors.error,
      );
      final CustomPaint paint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is RoutePainter,
        ),
      );
      expect((paint.painter! as RoutePainter).palette, same(AppPalette.light));
    });

    testWidgets('light loading skeleton keeps canyonBrown 10%', (tester) async {
      await _pump(tester, theme: AppTheme.light(), loading: true);
      expect(_swatch(AppPalette.light.skeleton), findsWidgets);
      expect(
        AppPalette.light.skeleton.toARGB32(),
        const Color(0x1A5B3A29).toARGB32(),
      );
    });
  });

  group('Layouts: no overflow in any state', () {
    for (final Brightness b in Brightness.values) {
      for (final Size size in const [Size(320, 568), Size(360, 800)]) {
        for (final double scale in const [1.0, 1.3]) {
          for (final (String name, RunSummary s, bool loading) in [
            ('full', _full, false),
            ('short', _short, false),
            ('gap route', RunSummary(runId: 'g', route: _gapRoute), false),
            ('loading', _full, true),
          ]) {
            testWidgets('${b.name} $name at ${size.width.toInt()}×'
                '${size.height.toInt()} text ${scale}x', (tester) async {
              await _pump(
                tester,
                theme: AppTheme.forBrightness(b),
                summary: s,
                loading: loading,
                size: size,
                textScale: scale,
              );
              await tester.pump(const Duration(milliseconds: 300));
              expect(tester.takeException(), isNull);
            });
          }
        }
      }
    }
  });
}

// Road Runner — History screen in light and dark (Phase 3B.4).
// Owner: Tharushi
// SRS reference: FR-61, FR-62, NFR-09, NFR-14, Section 8.4
//
// Checks the moonlit styling (sky, filters, monthly card, run cards,
// skeletons, empty and error states), that the day styling is unchanged,
// and that filtering, ordering and callbacks behave the same in both themes.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/app_colors.dart';
import 'package:road_runner/core/theme/app_palette.dart';
import 'package:road_runner/core/theme/app_theme.dart';
import 'package:road_runner/features/app_strings.dart';
import 'package:road_runner/features/history/history_run.dart';
import 'package:road_runner/features/history/history_screen.dart';
import 'package:road_runner/features/home/widgets/sky_header.dart';
import 'package:road_runner/features/shared/app_navigation_drawer.dart';

// Test fixtures only — not real application data.
final HistoryRun _nov14 = HistoryRun(
  runId: 'nov-14',
  startedAt: DateTime(2026, 11, 14, 7, 42),
  distanceM: 5020,
  movingMs: (32 * 60 + 15) * 1000,
  averagePaceSecPerKm: 385,
);
final HistoryRun _nov1 = HistoryRun(
  runId: 'nov-1',
  startedAt: DateTime(2026, 11, 1), // first instant of the month
  distanceM: 3480,
  movingMs: (21 * 60 + 5) * 1000,
  averagePaceSecPerKm: 363,
);
final HistoryRun _oct31 = HistoryRun(
  runId: 'oct-31',
  startedAt: DateTime(2026, 10, 31, 23, 59), // last minute of last month
  distanceM: 2400,
  movingMs: 900000,
  averagePaceSecPerKm: 375,
);
final HistoryRun _sep = HistoryRun(
  runId: 'sep',
  startedAt: DateTime(2026, 9, 20, 6),
  distanceM: 7100,
  movingMs: (46 * 60 + 52) * 1000,
  averagePaceSecPerKm: 396,
);
final List<HistoryRun> _runs = [_oct31, _nov1, _sep, _nov14];
final DateTime _today = DateTime(2026, 11, 16, 9);

const HistoryMonthlySummary _novSummary = HistoryMonthlySummary(
  monthLabel: 'Nov 2026',
  totalRuns: 2,
  totalDistanceM: 8500,
  totalMovingMs: (53 * 60 + 20) * 1000,
);

class _Calls {
  final List<String> selected = [];
  int back = 0;
  int start = 0;
  int retry = 0;
  int home = 0;
  int settings = 0;
}

Future<_Calls> _pump(
  WidgetTester tester, {
  required ThemeData theme,
  List<HistoryRun>? runs,
  Size size = const Size(360, 800),
  double textScale = 1.0,
  HistoryRunFilter initialFilter = HistoryRunFilter.allRuns,
  bool isLoading = false,
  bool hasError = false,
  bool reduceMotion = false,
}) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = size * 3.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  final _Calls calls = _Calls();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: HistoryScreen(
          runs: runs ?? _runs,
          onRunSelected: calls.selected.add,
          onBackToHome: () => calls.back++,
          referenceDate: _today,
          initialFilter: initialFilter,
          thisMonthSummary: _novSummary,
          isLoading: isLoading,
          hasError: hasError,
          onRetry: () => calls.retry++,
          onStartRun: () => calls.start++,
          onOpenHome: () => calls.home++,
          onOpenSettings: () => calls.settings++,
        ),
      ),
    ),
  );
  return calls;
}

Finder _chip(HistoryRunFilter f) => find.byKey(HistoryScreen.filterChipKey(f));
Finder _tile(String id) => find.byKey(HistoryScreen.runTileKey(id));

List<String> _visibleRunIds(WidgetTester tester) {
  final List<String> ids = [];
  for (final HistoryRun r in [_nov14, _nov1, _oct31, _sep]) {
    if (_tile(r.runId).evaluate().isNotEmpty) ids.add(r.runId);
  }
  ids.sort(
    (a, b) => tester
        .getTopLeft(_tile(a))
        .dy
        .compareTo(tester.getTopLeft(_tile(b)).dy),
  );
  return ids;
}

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final double la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Color _blockColor(WidgetTester tester) {
  final Container block = tester.widget<Container>(
    find
        .descendant(
          of: find.byKey(HistoryScreen.loadingStateKey),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).borderRadius != null,
          ),
        )
        .first,
  );
  return (block.decoration! as BoxDecoration).color!;
}

void main() {
  final AppPalette night = AppPalette.dark;

  group('Dark History styling', () {
    testWidgets('sky header, background and landscape use the night palette', (
      tester,
    ) async {
      await _pump(tester, theme: AppTheme.dark());
      final BuildContext ctx = tester.element(find.byType(HistoryScreen));
      expect(Theme.of(ctx).scaffoldBackgroundColor, night.background);

      final DecoratedBox header = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(CompactSkyHeader),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((header.decoration as BoxDecoration).gradient, night.skyGradient);
      final CustomPaint landscape = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is CompactLandscapePainter,
        ),
      );
      expect(
        (landscape.painter! as CompactLandscapePainter).palette,
        same(night),
      );
      expect(
        tester.widget<Text>(find.text(AppStrings.historyTitle)).style!.color,
        night.textPrimary,
      );
    });

    testWidgets('run cards: surface, date, stats, labels and chevron', (
      tester,
    ) async {
      await _pump(tester, theme: AppTheme.dark());
      final Material card = tester.widget<Material>(
        find
            .descendant(of: _tile('nov-14'), matching: find.byType(Material))
            .first,
      );
      expect(card.color, night.surface);
      Color colourOf(String text) => tester
          .widget<Text>(
            find.descendant(of: _tile('nov-14'), matching: find.text(text)),
          )
          .style!
          .color!;
      expect(colourOf('14 Nov 2026'), night.textPrimary);
      expect(colourOf('5.02 km'), night.stat);
      expect(colourOf(AppStrings.statDistance), night.textSecondary);
      final Icon chevron = tester.widget<Icon>(
        find.descendant(
          of: _tile('nov-14'),
          matching: find.byIcon(Icons.chevron_right),
        ),
      );
      expect(chevron.color, night.textSecondary);
      final Icon tileIcon = tester.widget<Icon>(
        find.descendant(
          of: _tile('nov-14'),
          matching: find.byIcon(Icons.directions_run_rounded),
        ),
      );
      expect(tileIcon.color, night.accent);
      expect(
        tester
            .widget<Text>(find.text(AppStrings.historyRunCount(4)))
            .style!
            .color,
        night.textSecondary,
      );
    });

    testWidgets('filters: selected is the primary fill, others outlined', (
      tester,
    ) async {
      await _pump(tester, theme: AppTheme.dark());
      final ChoiceChip all = tester.widget<ChoiceChip>(
        _chip(HistoryRunFilter.allRuns),
      );
      final ChoiceChip month = tester.widget<ChoiceChip>(
        _chip(HistoryRunFilter.thisMonth),
      );
      expect(all.selected, isTrue);
      expect(all.selectedColor, night.primaryFill);
      expect(all.side!.color, night.primaryFill);
      expect(all.labelStyle!.color, night.onPrimaryFill);
      expect(month.backgroundColor, Colors.transparent);
      expect(month.side!.color, night.buttonOutline);
      expect(month.labelStyle!.color, night.textPrimary);
      // Labels readable on what they sit on.
      expect(
        _contrast(night.onPrimaryFill, night.primaryFill),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(night.textPrimary, night.background),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(night.buttonOutline, night.background),
        greaterThanOrEqualTo(3),
      );
    });

    testWidgets('monthly summary card uses night stat and text colours', (
      tester,
    ) async {
      await _pump(
        tester,
        theme: AppTheme.dark(),
        initialFilter: HistoryRunFilter.thisMonth,
      );
      final Finder card = find.byKey(HistoryScreen.summaryCardKey);
      expect(card, findsOneWidget);
      Color colourOf(String t) => tester
          .widget<Text>(find.descendant(of: card, matching: find.text(t)))
          .style!
          .color!;
      expect(colourOf('Nov 2026'), night.textPrimary);
      expect(colourOf('53:20'), night.stat);
      expect(colourOf(AppStrings.historyTotalTime), night.textSecondary);
    });

    testWidgets(
      'monthly summary card average pace caption contrast in both themes',
      (tester) async {
        const HistoryMonthlySummary summaryWithPace = HistoryMonthlySummary(
          monthLabel: 'Nov 2026',
          totalRuns: 2,
          totalDistanceM: 8500,
          totalMovingMs: (53 * 60 + 20) * 1000,
          averagePaceSecPerKm: 376, // 6:16/km
        );
        final String paceText = '${AppStrings.statAveragePace} 6:16/km';

        // 1. Dark theme: caption must use textSecondary with >= 4.5:1 contrast
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark(),
            home: Scaffold(
              body: HistoryScreen(
                runs: _runs,
                onRunSelected: (_) {},
                onBackToHome: () {},
                referenceDate: _today,
                initialFilter: HistoryRunFilter.thisMonth,
                thisMonthSummary: summaryWithPace,
              ),
            ),
          ),
        );

        final Finder darkCard = find.byKey(HistoryScreen.summaryCardKey);
        final Text darkPaceText = tester.widget<Text>(
          find.descendant(of: darkCard, matching: find.text(paceText)),
        );
        expect(darkPaceText.style!.color, night.textSecondary);
        expect(
          _contrast(darkPaceText.style!.color!, night.surface),
          greaterThanOrEqualTo(4.5),
        );

        // 2. Light theme: caption must use textSecondary with >= 4.5:1 contrast
        final AppPalette day = AppPalette.light;
        await tester.pumpWidget(
          MaterialApp(
            key: const Key('light-app'),
            theme: AppTheme.light(),
            home: Scaffold(
              body: HistoryScreen(
                runs: _runs,
                onRunSelected: (_) {},
                onBackToHome: () {},
                referenceDate: _today,
                initialFilter: HistoryRunFilter.thisMonth,
                thisMonthSummary: summaryWithPace,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Finder lightCard = find.byKey(HistoryScreen.summaryCardKey);
        final Text lightPaceText = tester.widget<Text>(
          find.descendant(of: lightCard, matching: find.text(paceText)),
        );
        expect(lightPaceText.style!.color, day.textSecondary);
        expect(
          _contrast(lightPaceText.style!.color!, day.surface),
          greaterThanOrEqualTo(4.5),
        );
      },
    );

    testWidgets('loading skeletons use the night skeleton fill', (
      tester,
    ) async {
      await _pump(tester, theme: AppTheme.dark(), isLoading: true);
      expect(_blockColor(tester), night.skeleton);
      expect(find.byType(ShaderMask), findsWidgets);
    });

    testWidgets('reduced motion: skeletons stay, shimmer stops (dark)', (
      tester,
    ) async {
      await _pump(
        tester,
        theme: AppTheme.dark(),
        isLoading: true,
        reduceMotion: true,
      );
      expect(find.byKey(HistoryScreen.loadingStateKey), findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);
      expect(_blockColor(tester), night.skeleton);
    });

    testWidgets('empty state: accent icon, night text, Start a run works', (
      tester,
    ) async {
      final _Calls calls = await _pump(
        tester,
        theme: AppTheme.dark(),
        runs: const [],
      );
      expect(
        tester
            .widget<Icon>(find.byIcon(Icons.directions_run_rounded).first)
            .color,
        night.accent,
      );
      expect(
        tester
            .widget<Text>(find.text(AppStrings.historyEmptyTitle))
            .style!
            .color,
        night.textPrimary,
      );
      await tester.tap(find.text(AppStrings.historyStartRun));
      expect(calls.start, 1);
    });

    testWidgets('error state: night error icon, Try again works', (
      tester,
    ) async {
      final _Calls calls = await _pump(
        tester,
        theme: AppTheme.dark(),
        hasError: true,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.error_outline_rounded)).color,
        night.error,
      );
      expect(
        tester
            .widget<Text>(find.text(AppStrings.historyErrorTitle))
            .style!
            .color,
        night.textPrimary,
      );
      await tester.tap(find.text(AppStrings.historyRetry));
      expect(calls.retry, 1);
    });
  });

  group('Light History is unchanged', () {
    testWidgets('chips, cards, stats and skeleton keep their day colours', (
      tester,
    ) async {
      await _pump(tester, theme: AppTheme.light());
      final ChoiceChip all = tester.widget<ChoiceChip>(
        _chip(HistoryRunFilter.allRuns),
      );
      final ChoiceChip month = tester.widget<ChoiceChip>(
        _chip(HistoryRunFilter.thisMonth),
      );
      expect(all.selectedColor, AppColors.burntOrangeDeep);
      expect(all.side!.color, AppColors.burntOrangeDeep);
      expect(all.labelStyle!.color, AppColors.white);
      expect(month.backgroundColor, AppColors.sandLight);
      expect(month.side!.color, AppColors.burntOrangeDeep);
      expect(month.labelStyle!.color, AppColors.canyonBrown);
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: _tile('nov-14'),
                matching: find.text('5.02 km'),
              ),
            )
            .style!
            .color,
        AppColors.tealDeep,
      );
      final Material card = tester.widget<Material>(
        find
            .descendant(of: _tile('nov-14'), matching: find.byType(Material))
            .first,
      );
      expect(card.color, AppColors.sandLight);
    });

    testWidgets('light skeleton keeps the icon-tile fill', (tester) async {
      await _pump(tester, theme: AppTheme.light(), isLoading: true);
      expect(_blockColor(tester), AppColors.iconTile);
    });
  });

  group('Filtering and ordering are theme-independent', () {
    for (final Brightness b in Brightness.values) {
      testWidgets('month boundaries and newest-first order (${b.name})', (
        tester,
      ) async {
        // Tall viewport so the lazy list builds every card.
        await _pump(
          tester,
          theme: AppTheme.forBrightness(b),
          size: const Size(360, 1600),
        );
        expect(_visibleRunIds(tester), ['nov-14', 'nov-1', 'oct-31', 'sep']);

        await tester.tap(_chip(HistoryRunFilter.thisMonth));
        await tester.pump();
        expect(_visibleRunIds(tester), ['nov-14', 'nov-1']);

        await tester.tap(_chip(HistoryRunFilter.lastMonth));
        await tester.pump();
        expect(_visibleRunIds(tester), ['oct-31']);
      });

      testWidgets('run tap, back and drawer callbacks (${b.name})', (
        tester,
      ) async {
        final _Calls calls = await _pump(
          tester,
          theme: AppTheme.forBrightness(b),
        );
        await tester.tap(_tile('oct-31'));
        expect(calls.selected, ['oct-31']);
        await tester.tap(find.byKey(HistoryScreen.backButtonKey));
        expect(calls.back, 1);

        await tester.tap(find.byKey(HistoryScreen.menuButtonKey));
        await tester.pumpAndSettle();
        expect(find.byType(AppNavigationDrawer), findsOneWidget);
        await tester.tap(
          find.byKey(
            AppNavigationDrawer.destinationKey(AppDestination.settings),
          ),
        );
        await tester.pumpAndSettle();
        expect(calls.settings, 1);

        await tester.tap(find.byKey(HistoryScreen.menuButtonKey));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(AppNavigationDrawer.destinationKey(AppDestination.home)),
        );
        await tester.pumpAndSettle();
        expect(calls.home, 1);
      });
    }

    testWidgets('dark drawer uses the night surface and scrim', (tester) async {
      await _pump(tester, theme: AppTheme.dark());
      await tester.tap(find.byKey(HistoryScreen.menuButtonKey));
      await tester.pumpAndSettle();
      final Drawer drawer = tester.widget<Drawer>(find.byType(Drawer));
      expect(drawer.backgroundColor, night.surface);
      final BuildContext ctx = tester.element(find.byType(HistoryScreen));
      expect(Theme.of(ctx).drawerTheme.scrimColor, night.scrim);
    });
  });

  group('Layouts: no overflow in any state', () {
    final Map<
      String,
      Future<void> Function(WidgetTester, ThemeData, Size, double)
    >
    states = {
      'all runs': (t, th, s, x) => _pump(t, theme: th, size: s, textScale: x),
      'this month + summary': (t, th, s, x) => _pump(
        t,
        theme: th,
        size: s,
        textScale: x,
        initialFilter: HistoryRunFilter.thisMonth,
      ),
      'empty last month': (t, th, s, x) => _pump(
        t,
        theme: th,
        size: s,
        textScale: x,
        runs: [_nov14],
        initialFilter: HistoryRunFilter.lastMonth,
      ),
      'loading': (t, th, s, x) =>
          _pump(t, theme: th, size: s, textScale: x, isLoading: true),
      'error': (t, th, s, x) =>
          _pump(t, theme: th, size: s, textScale: x, hasError: true),
    };
    for (final Brightness b in Brightness.values) {
      for (final Size size in const [Size(320, 568), Size(360, 800)]) {
        for (final double scale in const [1.0, 1.3]) {
          for (final MapEntry<
                String,
                Future<void> Function(WidgetTester, ThemeData, Size, double)
              >
              state
              in states.entries) {
            testWidgets('${b.name} ${state.key} at ${size.width.toInt()}×'
                '${size.height.toInt()} text ${scale}x', (tester) async {
              await state.value(tester, AppTheme.forBrightness(b), size, scale);
              await tester.pump(const Duration(milliseconds: 300));
              expect(tester.takeException(), isNull);
            });
          }
        }
      }
    }
  });
}

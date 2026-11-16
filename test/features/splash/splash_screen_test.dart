// Road Runner — Splash screen widget tests.
// Owner: Tharushi
// SRS reference: Section 8.4, FR-70, FR-71, NFR-09, NFR-14

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/app_palette.dart';
import 'package:road_runner/core/theme/app_theme.dart';
import 'package:road_runner/features/app_strings.dart';
import 'package:road_runner/features/splash/splash_screen.dart';

class _CountingObserver extends NavigatorObserver {
  int pushes = 0;
  int pops = 0;
  int replaces = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => pops++;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      replaces++;
}

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(360, 800),
  double textScale = 1.0,
  bool reduceMotion = false,
  ThemeData? theme,
  NavigatorObserver? observer,
}) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = size * 3.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.light(),
      navigatorObservers: [?observer],
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: const SplashScreen(),
      ),
    ),
  );
  await tester.pump();
}

CircularProgressIndicator _indicator(WidgetTester tester) => tester
    .widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator));

double _spinnerTurns(WidgetTester tester) => tester
    .widget<RotationTransition>(find.byKey(SplashScreen.spinnerKey))
    .turns
    .value;

void main() {
  testWidgets('dark Splash uses the moonlit palette and artwork', (
    tester,
  ) async {
    await _pump(tester, theme: AppTheme.dark());
    final AppPalette palette = AppPalette.dark;

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      palette.background,
    );
    final BoxDecoration sky = tester
        .widget<DecoratedBox>(find.byType(DecoratedBox).first)
        .decoration as BoxDecoration;
    expect(sky.gradient, palette.splashGradient);
    final Text name = tester.widget<Text>(find.text(AppStrings.appName));
    expect(name.style!.color, palette.textPrimary);
    final Icon runner = tester.widget<Icon>(
      find.byIcon(Icons.directions_run_rounded),
    );
    expect(runner.color, palette.accent);
    final CircularProgressIndicator spinner = _indicator(tester);
    expect(spinner.color, palette.accent);
    expect(spinner.backgroundColor, palette.hairline);

    final CustomPaint stars = tester.widget<CustomPaint>(
      find.byKey(SplashScreen.skyKey),
    );
    expect((stars.painter as SplashSkyPainter).palette, same(palette));
    final CustomPaint landscape = tester.widget<CustomPaint>(
      find.byKey(SplashScreen.landscapeKey),
    );
    expect(
      (landscape.painter as SplashLandscapePainter).palette,
      same(palette),
    );
  });

  group('Branding', () {
    testWidgets('shows the runner icon, the name and the landscape', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.byIcon(Icons.directions_run_rounded), findsOneWidget);
      expect(find.byKey(SplashScreen.landscapeKey), findsOneWidget);
      expect(find.byType(Image), findsNothing); // no image assets
    });

    testWidgets('the spinner sits under the name', (tester) async {
      await _pump(tester);
      final Rect name = tester.getRect(find.text(AppStrings.appName));
      final Rect spinner = tester.getRect(
        find.byType(CircularProgressIndicator),
      );
      expect(spinner.top, greaterThan(name.bottom));
      expect(spinner.center.dx, closeTo(name.center.dx, 1));
    });
  });

  group('Loading indicator', () {
    testWidgets('spinner completes one revolution per second', (tester) async {
      await _pump(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(_indicator(tester).value, 0.25);
      expect(tester.binding.hasScheduledFrame, isTrue); // animating

      final double start = _spinnerTurns(tester);
      await tester.pump(const Duration(milliseconds: 250));
      expect(_spinnerTurns(tester) - start, closeTo(0.25, 0.02));
    });

    testWidgets('reduced motion keeps rotating at a slower speed', (
      tester,
    ) async {
      await _pump(
        tester,
        reduceMotion: true,
        theme: AppTheme.dark(),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(_indicator(tester).value, 0.25);
      expect(tester.binding.hasScheduledFrame, isTrue);

      final double start = _spinnerTurns(tester);
      await tester.pump(const Duration(milliseconds: 600));
      expect(_spinnerTurns(tester) - start, closeTo(0.25, 0.02));
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('spinner controller disposes when SplashScreen is removed', (
      tester,
    ) async {
      await _pump(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('Semantics', () {
    testWidgets('indicator is announced as loading, never as a percentage', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      for (final bool reduceMotion in [false, true]) {
        await _pump(tester, reduceMotion: reduceMotion);
        final SemanticsNode node = tester.getSemantics(
          find.byKey(SplashScreen.progressKey),
        );
        expect(node.label, AppStrings.splashLoading);
        expect(node.value, isEmpty, reason: 'reduceMotion: $reduceMotion');
      }
      handle.dispose();
    });

    testWidgets('the name is a heading; artwork is not read out', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester);
      expect(
        tester.getSemantics(find.text(AppStrings.appName)),
        containsSemantics(label: AppStrings.appName, isHeader: true),
      );
      expect(
        find.bySemanticsLabel(RegExp('run', caseSensitive: false)),
        findsNWidgets(2), // "Road Runner" heading + "Loading Road Runner"
      );
      handle.dispose();
    });
  });

  group('No artificial delay or navigation', () {
    testWidgets('stays put for as long as the parent shows it', (tester) async {
      final _CountingObserver observer = _CountingObserver();
      await _pump(tester, observer: observer);
      final int initialPushes = observer.pushes;

      // Ten simulated minutes: nothing happens on its own.
      for (int i = 0; i < 60; i++) {
        await tester.pump(const Duration(seconds: 10));
      }
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(observer.pushes, initialPushes);
      expect(observer.pops, 0);
      expect(observer.replaces, 0);
    });

    testWidgets('the parent replaces it whenever start-up really ends', (
      tester,
    ) async {
      final ValueNotifier<bool> ready = ValueNotifier<bool>(false);
      addTearDown(ready.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<bool>(
            valueListenable: ready,
            builder: (context, done, _) =>
                done ? const Text('home') : const SplashScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(find.byType(SplashScreen), findsOneWidget);

      ready.value = true;
      await tester.pump();
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.text('home'), findsOneWidget);
      // No timers are left behind: flutter_test fails the test otherwise.
    });
  });

  group('Layout: no overflow, brand fully visible', () {
    final Map<String, (Size, double)> cases = {
      '360x800': (const Size(360, 800), 1.0),
      '320x568': (const Size(320, 568), 1.0),
      '360x800 at 1.3x text': (const Size(360, 800), 1.3),
      '320x568 at 1.3x text': (const Size(320, 568), 1.3),
      '412x915 (Galaxy A33)': (const Size(412, 915), 1.0),
    };
    for (final MapEntry<String, (Size, double)> c in cases.entries) {
      testWidgets(c.key, (tester) async {
        final Size size = c.value.$1;
        await _pump(tester, size: size, textScale: c.value.$2);
        expect(tester.takeException(), isNull);

        final Rect brand = tester.getRect(find.byKey(SplashScreen.brandKey));
        expect(brand.left, greaterThanOrEqualTo(0));
        expect(brand.top, greaterThanOrEqualTo(0));
        expect(brand.right, lessThanOrEqualTo(size.width));
        expect(brand.bottom, lessThanOrEqualTo(size.height));

        // The landscape is anchored to the bottom edge.
        final Rect land = tester.getRect(find.byKey(SplashScreen.landscapeKey));
        expect(land.bottom, closeTo(size.height, 0.5));
        expect(land.width, closeTo(size.width, 0.5));
        // The brand sits above the landscape area.
        expect(brand.bottom, lessThanOrEqualTo(land.top + 0.5));
      });
    }

    testWidgets('normal phone: brand is shown at full size', (tester) async {
      await _pump(tester);
      final Rect brand = tester.getRect(find.byKey(SplashScreen.brandKey));
      final Size natural = tester.getSize(find.byKey(SplashScreen.brandKey));
      expect(brand.height, closeTo(natural.height, 0.5)); // not shrunk
    });

    testWidgets('respects the status bar (top safe area)', (tester) async {
      const double statusBar = 32;
      tester.view.padding = const FakeViewPadding(top: statusBar * 3);
      addTearDown(tester.view.resetPadding);
      await _pump(tester, size: const Size(320, 568), textScale: 1.3);
      final Rect brand = tester.getRect(find.byKey(SplashScreen.brandKey));
      expect(brand.top, greaterThanOrEqualTo(statusBar));
      expect(tester.takeException(), isNull);
    });

    testWidgets('dark theme fits a narrow screen with larger text', (
      tester,
    ) async {
      await _pump(
        tester,
        size: const Size(320, 568),
        textScale: 1.3,
        theme: AppTheme.dark(),
      );
      expect(tester.takeException(), isNull);
    });
  });
}

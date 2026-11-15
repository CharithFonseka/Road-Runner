// Road Runner — Slide to Start widget tests.
// Owner: Tharushi
// SRS reference: Section 8.4, FR-01, NFR-09, NFR-14

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/app_theme.dart';
import 'package:road_runner/features/app_strings.dart';
import 'package:road_runner/features/home/widgets/slide_to_start.dart';

class _Counter {
  int starts = 0;
  void call() => starts++;
}

const Key _sliderKey = Key('slider');

/// 360dp screen with 16dp side padding: track 328dp, handle travel 256dp,
/// so the 70% threshold is 179.2dp.
const double _travel = 360 - 32 - SlideToStart.handleSize - 2 * 4;

Future<_Counter> _pump(
  WidgetTester tester, {
  bool enabled = true,
  bool starting = false,
  bool reduceMotion = false,
  double width = 360,
  double textScale = 1.0,
  _Counter? counter,
}) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = Size(width, 800) * 3.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  final _Counter c = counter ?? _Counter();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SlideToStart(
                key: _sliderKey,
                onStart: c.call,
                enabled: enabled,
                starting: starting,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return c;
}

Finder get _handle => find.byKey(SlideToStart.handleKey);

/// Handle offset from its resting place, in dp.
double _handleOffset(WidgetTester tester) =>
    tester.getRect(_handle).left -
    (tester.getRect(find.byKey(_sliderKey)).left + SlideToStart.inset);

Future<void> _dragHandle(WidgetTester tester, double dx) async {
  await tester.drag(_handle, Offset(dx, 0));
  await tester.pumpAndSettle();
}

void _semanticTap(WidgetTester tester) {
  final SemanticsNode node = tester.getSemantics(find.byKey(_sliderKey));
  tester.binding.pipelineOwner.semanticsOwner!.performAction(
    node.id,
    SemanticsAction.tap,
  );
}

void main() {
  group('Drag', () {
    testWidgets('released beyond 70% starts once and shows Starting', (
      tester,
    ) async {
      final _Counter c = await _pump(tester);
      await _dragHandle(tester, _travel * 0.78);
      expect(c.starts, 1);
      expect(find.text(AppStrings.slideStarting), findsOneWidget);
      // The handle locks at the end of the track.
      expect(_handleOffset(tester), closeTo(_travel, 0.5));
    });

    testWidgets('released below 70% snaps back and does not start', (
      tester,
    ) async {
      final _Counter c = await _pump(tester);
      final TestGesture g = await tester.startGesture(
        tester.getCenter(_handle),
      );
      await g.moveBy(const Offset(30, 0));
      await g.moveBy(Offset(_travel * 0.6 - 30, 0));
      await tester.pump();
      expect(_handleOffset(tester), closeTo(_travel * 0.6, 0.5)); // follows
      await g.up();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_handleOffset(tester), greaterThan(0)); // animating back
      await tester.pumpAndSettle();
      expect(_handleOffset(tester), closeTo(0, 0.5));
      expect(c.starts, 0);
      expect(find.text(AppStrings.slideStarting), findsNothing);
    });

    testWidgets('dragging past 70% then back before release does not start', (
      tester,
    ) async {
      final _Counter c = await _pump(tester);
      final TestGesture g = await tester.startGesture(
        tester.getCenter(_handle),
      );
      await g.moveBy(const Offset(30, 0));
      await g.moveBy(Offset(_travel * 0.9 - 30, 0));
      await g.moveBy(Offset(-_travel * 0.5, 0));
      await g.up();
      await tester.pumpAndSettle();
      expect(c.starts, 0);
    });

    testWidgets('exactly at the threshold starts', (tester) async {
      final _Counter c = await _pump(tester);
      await _dragHandle(tester, _travel * SlideToStart.threshold + 0.5);
      expect(c.starts, 1);
    });

    testWidgets('reduced motion: snaps back without animating', (tester) async {
      await _pump(tester, reduceMotion: true);
      await tester.drag(_handle, Offset(_travel * 0.5, 0));
      await tester.pump();
      expect(_handleOffset(tester), closeTo(0, 0.5));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('Tap and press-and-hold', () {
    testWidgets('an ordinary tap does not start', (tester) async {
      final _Counter c = await _pump(tester);
      await tester.tap(find.byKey(_sliderKey));
      await tester.tap(_handle);
      await tester.pump(const Duration(seconds: 3));
      expect(c.starts, 0);
      expect(find.text(AppStrings.slideStarting), findsNothing);
    });

    testWidgets('releasing a hold early does not start', (tester) async {
      final _Counter c = await _pump(tester);
      final TestGesture g = await tester.startGesture(
        tester.getCenter(find.byKey(_sliderKey)),
      );
      await tester.pump(); // first frame starts the hold timer
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(AppStrings.slideKeepHolding), findsOneWidget);
      await g.up();
      await tester.pump(const Duration(seconds: 2));
      expect(c.starts, 0);
      expect(find.text(AppStrings.slideOrHold), findsOneWidget);
    });

    testWidgets('holding for 1 s starts exactly once', (tester) async {
      final _Counter c = await _pump(tester);
      final TestGesture g = await tester.startGesture(
        tester.getCenter(find.byKey(_sliderKey)),
      );
      await tester.pump(); // first frame starts the hold timer
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 600));
      expect(c.starts, 1);
      await tester.pump(const Duration(seconds: 3)); // keep holding
      await g.up();
      await tester.pumpAndSettle();
      expect(c.starts, 1);
      expect(find.text(AppStrings.slideStarting), findsOneWidget);
    });

    testWidgets('moving the finger cancels a hold', (tester) async {
      final _Counter c = await _pump(tester);
      final TestGesture g = await tester.startGesture(
        tester.getCenter(find.byKey(_sliderKey)),
      );
      await tester.pump(); // first frame starts the hold timer
      await tester.pump(const Duration(milliseconds: 300));
      await g.moveBy(const Offset(0, 40)); // vertical: no drag, no hold
      await tester.pump(const Duration(seconds: 2));
      await g.up();
      await tester.pumpAndSettle();
      expect(c.starts, 0);
    });

    testWidgets('reduced motion keeps the full 1 s hold', (tester) async {
      final _Counter c = await _pump(tester, reduceMotion: true);
      final TestGesture g = await tester.startGesture(
        tester.getCenter(find.byKey(_sliderKey)),
      );
      await tester.pump(); // first frame starts the hold timer
      await tester.pump(const Duration(milliseconds: 500));
      expect(c.starts, 0);
      await tester.pump(const Duration(milliseconds: 600));
      expect(c.starts, 1);
      await g.up();
    });
  });

  group('Accessible activation', () {
    testWidgets('is one button with a label, hint and tap action', (
      tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester);
      expect(
        tester.getSemantics(find.byKey(_sliderKey)),
        containsSemantics(
          label: AppStrings.startRunSemanticsLabel,
          hint: AppStrings.startRunSemanticsHint,
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('screen-reader activation starts once', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final _Counter c = await _pump(tester);
      _semanticTap(tester);
      await tester.pumpAndSettle();
      expect(c.starts, 1);
      final SemanticsNode node = tester.getSemantics(find.byKey(_sliderKey));
      expect(
        node,
        containsSemantics(
          label: AppStrings.slideStarting,
          isLiveRegion: true,
          hasTapAction: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('keyboard Enter starts once; Space afterwards is ignored', (
      tester,
    ) async {
      final _Counter c = await _pump(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(c.starts, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(c.starts, 1);
    });

    testWidgets('keyboard Space starts', (tester) async {
      final _Counter c = await _pump(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(c.starts, 1);
    });
  });

  group('One start only', () {
    testWidgets('rapid repeated gestures never start twice', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final _Counter c = await _pump(tester);
      await tester.drag(_handle, Offset(_travel * 0.8, 0));
      await tester.drag(find.byKey(_sliderKey), Offset(_travel * 0.8, 0));
      await tester.drag(_handle, const Offset(-200, 0));
      await tester.drag(_handle, Offset(_travel, 0));
      final TestGesture g = await tester.startGesture(
        tester.getCenter(find.byKey(_sliderKey)),
      );
      await tester.pump(); // first frame starts the hold timer
      await tester.pump(const Duration(seconds: 2));
      await g.up();
      _semanticTap(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(c.starts, 1);
      handle.dispose();
    });

    testWidgets('re-arms after another route covered the screen', (
      tester,
    ) async {
      final _Counter c = await _pump(tester);
      await _dragHandle(tester, _travel * 0.8);
      expect(c.starts, 1);

      final NavigatorState nav = tester.state(find.byType(Navigator));
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Run')),
        ),
      );
      await tester.pumpAndSettle();
      nav.pop();
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.slideStarting), findsNothing);
      expect(_handleOffset(tester), closeTo(0, 0.5));
      await _dragHandle(tester, _travel * 0.8);
      expect(c.starts, 2);
    });

    testWidgets('stays latched while the screen remains visible', (
      tester,
    ) async {
      final _Counter c = await _pump(tester);
      await _dragHandle(tester, _travel * 0.8);
      await tester.pump(const Duration(seconds: 30));
      await _dragHandle(tester, _travel * 0.8);
      expect(c.starts, 1);
      expect(find.text(AppStrings.slideStarting), findsOneWidget);
    });
  });

  group('States', () {
    testWidgets('starting (from the parent): shown and inert', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final _Counter c = await _pump(tester, starting: true);
      expect(find.text(AppStrings.slideStarting), findsOneWidget);
      expect(_handleOffset(tester), closeTo(_travel, 0.5));
      await tester.drag(find.byKey(_sliderKey), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byKey(_sliderKey)),
        containsSemantics(isEnabled: false, hasTapAction: false),
      );
      expect(c.starts, 0);
      handle.dispose();
    });

    testWidgets('parent clearing "starting" re-arms the control', (
      tester,
    ) async {
      final _Counter c = _Counter();
      await _pump(tester, counter: c);
      await _dragHandle(tester, _travel * 0.8);
      await _pump(tester, counter: c, starting: true);
      await _pump(tester, counter: c);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.slideStarting), findsNothing);
      await _dragHandle(tester, _travel * 0.8);
      expect(c.starts, 2);
    });

    testWidgets('disabled: no drag, hold or accessible start', (tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final _Counter c = await _pump(tester, enabled: false);
      await _dragHandle(tester, _travel);
      final TestGesture g = await tester.startGesture(
        tester.getCenter(find.byKey(_sliderKey)),
      );
      await tester.pump(); // first frame starts the hold timer
      await tester.pump(const Duration(seconds: 2));
      await g.up();
      expect(
        tester.getSemantics(find.byKey(_sliderKey)),
        containsSemantics(
          label: AppStrings.startRunSemanticsLabel,
          isButton: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      expect(c.starts, 0);
      handle.dispose();
    });
  });

  group('Layout', () {
    final Map<String, (double, double)> cases = {
      '360 wide': (360, 1.0),
      '320 wide': (320, 1.0),
      '320 wide at 1.3x text': (320, 1.3),
      '412 wide (Galaxy A33)': (412, 1.0),
      '360 wide at 2x text': (360, 2.0),
    };
    for (final MapEntry<String, (double, double)> e in cases.entries) {
      testWidgets('${e.key}: 72dp tall, 64dp handle, no overflow', (
        tester,
      ) async {
        await _pump(tester, width: e.value.$1, textScale: e.value.$2);
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byKey(_sliderKey)).height, 72);
        expect(tester.getSize(_handle), const Size.square(64));
        expect(tester.getSize(find.byKey(_sliderKey)).width, e.value.$1 - 32);
      });
    }
  });
}

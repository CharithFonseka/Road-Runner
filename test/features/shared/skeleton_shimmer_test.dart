import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/features/shared/skeleton_shimmer.dart';

const Key _blockKey = Key('skeleton.block');

Future<void> _pumpShimmer(
  WidgetTester tester, {
  bool reduceMotion = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(240, 100);
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SkeletonShimmer(
          child: SkeletonShimmerBlock(
            child: Container(
              key: _blockKey,
              width: 160,
              height: 24,
              color: const Color(0x1A5B3A29),
            ),
          ),
        ),
      ),
    ),
  );
}

double _shimmerProgress(WidgetTester tester) {
  final Listenable animation = tester
      .widget<AnimatedBuilder>(
        find.descendant(
          of: find.byType(SkeletonShimmerBlock),
          matching: find.byType(AnimatedBuilder),
        ),
      )
      .animation;
  return (animation as Animation<double>).value;
}

void main() {
  testWidgets('highlight sweeps across skeletons while loading', (
    tester,
  ) async {
    await _pumpShimmer(tester);
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isTrue);
    final double start = _shimmerProgress(tester);

    await tester.pump(const Duration(milliseconds: 700));
    expect(_shimmerProgress(tester) - start, closeTo(0.5, 0.02));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('reduced motion keeps the placeholder visible and static', (
    tester,
  ) async {
    await _pumpShimmer(tester, reduceMotion: true);
    expect(find.byKey(_blockKey), findsOneWidget);
    expect(find.byType(ShaderMask), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(_blockKey), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('removing the animated shimmer disposes its ticker', (
    tester,
  ) async {
    await _pumpShimmer(tester);
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}

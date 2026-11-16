import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/features/shared/smooth_progress_bar.dart';

void main() {
  testWidgets('progress fill follows updates and reduced motion', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: SmoothProgressBar(value: 0.25, label: 'Weekly goal'),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(AnimatedContainer)).width, 50);
    expect(
      tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).duration,
      Duration.zero,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: SmoothProgressBar(value: 0.75, label: 'Weekly goal'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.getSize(find.byType(AnimatedContainer)).width, 150);
  });
}

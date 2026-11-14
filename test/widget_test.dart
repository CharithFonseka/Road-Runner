// Road Runner — smoke test for the application shell.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:road_runner/main.dart';

void main() {
  testWidgets('RoadRunnerApp shell builds without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(const RoadRunnerApp());

    expect(find.text('Road Runner'), findsOneWidget);
    expect(
      find.text('Road Runner ready for integration.'),
      findsOneWidget,
    );
    expect(find.byType(ErrorWidget), findsNothing);
  });
}

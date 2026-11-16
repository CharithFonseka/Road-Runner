import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/app_theme.dart';
import 'package:road_runner/features/summary/run_summary.dart';
import 'package:road_runner/features/summary/widgets/street_route_map.dart';

void main() {
  testWidgets('saved route art stays visible if street style cannot load', (
    tester,
  ) async {
    final style = Completer<vt.Style>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 220,
            child: StreetRouteMap(
              route: const [
                RoutePoint(lat: -33.815, lon: 151.002),
                RoutePoint(lat: -33.816, lon: 151.003),
              ],
              fallback: const Center(child: Text('Offline route')),
              styleFuture: style.future,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Offline route'), findsOneWidget);
    style.completeError(const FormatException('offline'));
    await tester.pump();
    expect(find.text('Offline route'), findsOneWidget);
    expect(find.text('Street map unavailable'), findsOneWidget);
  });
}

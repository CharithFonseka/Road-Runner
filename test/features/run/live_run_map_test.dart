import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/bridge/tracking_bridge.dart';
import 'package:road_runner/features/run/live_run_map.dart';

void main() {
  testWidgets('waits for an accepted fix before showing the street map', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LiveRunMap(route: [], snapshot: null)),
      ),
    );
    expect(find.byType(FlutterMap), findsNothing);
  });

  testWidgets('draws the restored route and current position', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LiveRunMap(
            route: [
              TrackingPoint(seq: 0, lat: -33.8688, lon: 151.2093),
              TrackingPoint(seq: 1, lat: -33.8690, lon: 151.2100),
            ],
            snapshot: TrackingSnapshot(
              elapsedMs: 2000,
              movingMs: 2000,
              distanceM: 70,
              speedMps: 3,
              lat: -33.8690,
              lon: 151.2100,
              seq: 1,
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('activeRun.liveMap')), findsOneWidget);
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(find.textContaining('OpenStreetMap'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LiveRunMap(
            route: [
              TrackingPoint(seq: 0, lat: -33.8688, lon: 151.2093),
              TrackingPoint(seq: 1, lat: -33.8690, lon: 151.2100),
              TrackingPoint(seq: 2, lat: -33.8692, lon: 151.2105),
            ],
            snapshot: TrackingSnapshot(
              elapsedMs: 3000,
              movingMs: 3000,
              distanceM: 100,
              speedMps: 3,
              lat: -33.8692,
              lon: 151.2105,
              seq: 2,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:latlong2/latlong.dart';
import 'package:road_runner/data/planned_route.dart';
import 'package:road_runner/data/planned_route_repository.dart';
import 'package:road_runner/features/route_planning/ors_directions_client.dart';
import 'package:road_runner/features/route_planning/route_planning_screen.dart';

class _RecordingRoutes extends PlannedRouteRepository {
  PlannedRoute? saved;

  @override
  Future<void> save(PlannedRoute route) async => saved = route;
}

void main() {
  testWidgets('selects map endpoints, previews a route and saves its name', (
    tester,
  ) async {
    final routes = _RecordingRoutes();
    final directions = OrsDirectionsClient(
      apiKey: 'test-key',
      post: (_, _, _) async => {
        'features': [
          {
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [79.86, 6.92],
                [79.87, 6.93],
              ],
            },
          },
        ],
      },
    );
    // Keep the tile style pending so this test has no network activity.
    final style = Completer<vt.Style>();
    await tester.pumpWidget(
      MaterialApp(
        home: RoutePlanningScreen(
          repository: routes,
          directions: directions,
          initialCenter: const LatLng(6.9271, 79.8612),
          styleFuture: style.future,
        ),
      ),
    );

    final map = find.byKey(RoutePlanningScreen.mapKey);
    final topLeft = tester.getTopLeft(map);
    await tester.tapAt(topLeft + const Offset(80, 80));
    await tester.pump();
    await tester.tapAt(topLeft + const Offset(180, 140));
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(find.byKey(RoutePlanningScreen.findKey))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(RoutePlanningScreen.findKey));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Morning loop');
    await tester.tap(find.byKey(RoutePlanningScreen.saveKey));
    await tester.pump();

    expect(routes.saved?.name, 'Morning loop');
    expect(routes.saved?.points.length, 2);
    expect(routes.saved?.points.first.lat, 6.92);
  });

  testWidgets('disables route lookup when no service key is configured', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RoutePlanningScreen(
          repository: _RecordingRoutes(),
          directions: OrsDirectionsClient(apiKey: ''),
          initialCenter: const LatLng(0, 0),
          styleFuture: Completer<vt.Style>().future,
        ),
      ),
    );
    expect(
      find.text('Walking route service is not configured.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(RoutePlanningScreen.findKey))
          .onPressed,
      isNull,
    );
  });
}

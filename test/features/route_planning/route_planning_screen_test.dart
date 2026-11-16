import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:latlong2/latlong.dart';
import 'package:road_runner/data/planned_route.dart';
import 'package:road_runner/data/planned_route_repository.dart';
import 'package:road_runner/features/route_planning/ors_directions_client.dart';
import 'package:road_runner/features/route_planning/place_search_client.dart';
import 'package:road_runner/features/route_planning/route_planning_screen.dart';

class _RecordingRoutes extends PlannedRouteRepository {
  PlannedRoute? saved;

  @override
  Future<void> save(PlannedRoute route) async => saved = route;
}

void main() {
  testWidgets('current location can fill the selected start and end points', (
    tester,
  ) async {
    var fixes = 0;
    final directions = OrsDirectionsClient(
      apiKey: 'test-key',
      post: (_, _, body) async {
        expect(body['coordinates'], [
          [79.8612, 6.9271],
          [79.864, 6.93],
        ]);
        return {
          'features': [
            {
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  [79.8612, 6.9271],
                  [79.864, 6.93],
                ],
              },
            },
          ],
        };
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RoutePlanningScreen(
          repository: _RecordingRoutes(),
          directions: directions,
          initialCenter: const LatLng(6.9271, 79.8612),
          styleFuture: Completer<vt.Style>().future,
          weatherFetcher: (_) async => null,
          onCurrentLocation: () async => ++fixes == 1
              ? const LatLng(6.9271, 79.8612)
              : const LatLng(6.93, 79.864),
        ),
      ),
    );

    await tester.tap(find.byKey(RoutePlanningScreen.currentLocationKey));
    await tester.pumpAndSettle();
    expect(find.text('Start: Current location'), findsOneWidget);
    expect(find.text('Use my location as end'), findsOneWidget);

    await tester.tap(find.byKey(RoutePlanningScreen.currentLocationKey));
    await tester.pumpAndSettle();
    expect(find.text('End: Current location'), findsOneWidget);
    expect(find.textContaining('Route ready ·'), findsOneWidget);
  });

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
          weatherFetcher: (_) async => null,
        ),
      ),
    );

    final map = find.byKey(RoutePlanningScreen.mapKey);
    final topLeft = tester.getTopLeft(map);
    await tester.tapAt(topLeft + const Offset(80, 230));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tapAt(topLeft + const Offset(180, 300));
    await tester.pump(const Duration(milliseconds: 300));

    if (find.byKey(RoutePlanningScreen.findKey).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(RoutePlanningScreen.findKey));
      await tester.pump();
    }
    await tester.enterText(
      find.byKey(RoutePlanningScreen.nameFieldKey),
      'Morning loop',
    );
    await tester.tap(find.byKey(RoutePlanningScreen.saveKey));
    await tester.pump();

    expect(routes.saved?.name, 'Morning loop');
    expect(routes.saved?.points.length, 2);
    expect(routes.saved?.points.first.lat, 6.92);
  });

  testWidgets('auto-plans road route without ORS key and saves & starts run', (
    tester,
  ) async {
    final routes = _RecordingRoutes();
    PlannedRoute? startedRoute;
    final directions = OrsDirectionsClient(
      apiKey: '',
      fetchOsrm: (_) async => {
        'routes': [
          {
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [79.86, 6.92],
                [79.865, 6.925],
                [79.87, 6.93],
              ],
            },
          },
        ],
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RoutePlanningScreen(
          repository: routes,
          directions: directions,
          initialCenter: const LatLng(6.9271, 79.8612),
          styleFuture: Completer<vt.Style>().future,
          weatherFetcher: (_) async => null,
          onStartRun: (route) => startedRoute = route,
        ),
      ),
    );

    // Recording can begin even before a route is planned.
    expect(
      tester
          .widget<FilledButton>(find.byKey(RoutePlanningScreen.startRunKey))
          .onPressed,
      isNotNull,
    );

    final map = find.byKey(RoutePlanningScreen.mapKey);
    final topLeft = tester.getTopLeft(map);
    await tester.tapAt(topLeft + const Offset(80, 230));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tapAt(topLeft + const Offset(180, 300));
    await tester.pumpAndSettle();

    // Auto-fetched route enables Save & Start run and displays road points.
    expect(find.textContaining('Route ready ·'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(RoutePlanningScreen.startRunKey))
          .onPressed,
      isNotNull,
    );

    await tester.enterText(
      find.byKey(RoutePlanningScreen.nameFieldKey),
      'Road loop',
    );
    await tester.tap(find.byKey(RoutePlanningScreen.startRunKey));
    await tester.pumpAndSettle();

    expect(routes.saved?.name, 'Road loop');
    expect(routes.saved?.points.length, 3);
    expect(startedRoute?.id, routes.saved?.id);
    expect(startedRoute?.name, 'Road loop');
  });

  testWidgets('searches a destination, sets start on map, and starts run', (
    tester,
  ) async {
    final routes = _RecordingRoutes();
    PlannedRoute? startedRoute;
    final placeSearch = PlaceSearchClient(
      fetch: (_) async => {
        'features': [
          {
            'geometry': {
              'type': 'Point',
              'coordinates': [79.8617, 6.9147],
            },
            'properties': {
              'name': 'Viharamahadevi Park',
              'city': 'Colombo',
              'country': 'Sri Lanka',
            },
          },
        ],
      },
    );
    final directions = OrsDirectionsClient(
      apiKey: '',
      fetchOsrm: (_) async => {
        'routes': [
          {
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [79.86, 6.92],
                [79.861, 6.917],
                [79.8617, 6.9147],
              ],
            },
          },
        ],
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RoutePlanningScreen(
          repository: routes,
          directions: directions,
          placeSearch: placeSearch,
          initialCenter: const LatLng(6.9271, 79.8612),
          styleFuture: Completer<vt.Style>().future,
          weatherFetcher: (_) async => null,
          onStartRun: (route) => startedRoute = route,
        ),
      ),
    );

    // Set start on map first, then search destination and start run.
    final map = find.byKey(RoutePlanningScreen.mapKey);
    final topLeft = tester.getTopLeft(map);
    await tester.tapAt(topLeft + const Offset(80, 230));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(RoutePlanningScreen.searchFieldKey),
      'Viharamahadevi',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Viharamahadevi Park'), findsOneWidget);
    await tester.tap(find.text('Viharamahadevi Park'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Route ready ·'), findsOneWidget);
    await tester.tap(find.byKey(RoutePlanningScreen.startRunKey));
    await tester.pumpAndSettle();

    expect(routes.saved?.name, 'Run to Viharamahadevi Park');
    expect(routes.saved?.points.length, 3);
    expect(startedRoute?.name, 'Run to Viharamahadevi Park');
  });

  testWidgets('starts an unplanned run directly from the planner', (
    tester,
  ) async {
    PlannedRoute? received = PlannedRoute(
      id: 'marker',
      name: 'marker',
      createdAtUtcMs: 0,
      points: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RoutePlanningScreen(
          repository: _RecordingRoutes(),
          directions: OrsDirectionsClient(apiKey: ''),
          initialCenter: const LatLng(0, 0),
          styleFuture: Completer<vt.Style>().future,
          onStartRun: (route) => received = route,
        ),
      ),
    );
    await tester.tap(find.byKey(RoutePlanningScreen.startRunKey));
    await tester.pump();
    expect(received, isNull);
  });
}

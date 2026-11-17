import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/data/planned_route.dart';
import 'package:road_runner/data/planned_route_repository.dart';
import 'package:road_runner/features/route_planning/saved_routes_screen.dart';
import 'package:road_runner/features/shared/app_bottom_navigation.dart';

class _Routes extends PlannedRouteRepository {
  _Routes(this.routes);
  final List<PlannedRoute> routes;

  @override
  Future<List<PlannedRoute>> list() async => routes;
}

const _route = PlannedRoute(
  id: 'park',
  name: 'Park loop',
  createdAtUtcMs: 1731800000000,
  activity: RouteActivity.run,
  points: [
    PlannedRoutePoint(lat: 6.9271, lon: 79.8612),
    PlannedRoutePoint(lat: 6.93, lon: 79.864),
  ],
);

void main() {
  testWidgets('Routes home shows planning and saved routes together', (
    tester,
  ) async {
    PlannedRoute? selected;
    var openedPlanner = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SavedRoutesScreen(
          repository: _Routes([_route]),
          onPlanRoute: () async => openedPlanner = true,
          onRouteSelected: (route) async => selected = route,
          onHome: () {},
          onRun: () {},
          onHistory: () {},
          onProfile: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plan a new route'), findsOneWidget);
    expect(find.text('Saved routes'), findsOneWidget);
    expect(find.text('Park loop'), findsOneWidget);
    expect(
      find.byKey(AppBottomNavigation.destinationKey(MainDestination.routes)),
      findsOneWidget,
    );
    await tester.tap(find.byKey(SavedRoutesScreen.planKey));
    await tester.pumpAndSettle();
    expect(openedPlanner, isTrue);
    await tester.tap(find.byKey(const Key('savedRoutes.park')));
    await tester.pumpAndSettle();
    expect(selected?.id, 'park');
  });

  testWidgets('empty Routes home explains where saved routes appear', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SavedRoutesScreen(
          repository: _Routes([]),
          onPlanRoute: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No saved routes yet'), findsOneWidget);
    expect(find.byKey(SavedRoutesScreen.planKey), findsOneWidget);
  });
}

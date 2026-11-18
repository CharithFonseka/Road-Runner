class PlannedRoutePoint {
  const PlannedRoutePoint({required this.lat, required this.lon});
  final double lat;
  final double lon;
}

/// How a planned path should be routed. Walk and run use pedestrian paths;
/// cycling uses the bicycle routing profile.
enum RouteActivity { walk, run, cycle }

extension RouteActivityLabel on RouteActivity {
  String get label => switch (this) {
    RouteActivity.walk => 'Walk',
    RouteActivity.run => 'Run',
    RouteActivity.cycle => 'Cycle',
  };

  static RouteActivity fromStorage(String? value) =>
      RouteActivity.values.where((mode) => mode.name == value).firstOrNull ??
      RouteActivity.run;
}

class PlannedRoute {
  const PlannedRoute({
    required this.id,
    required this.name,
    required this.createdAtUtcMs,
    required this.points,
    this.activity = RouteActivity.run,
  });

  final String id;
  final String name;
  final int createdAtUtcMs;
  final List<PlannedRoutePoint> points;
  final RouteActivity activity;
}

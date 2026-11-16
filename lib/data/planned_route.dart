class PlannedRoutePoint {
  const PlannedRoutePoint({required this.lat, required this.lon});
  final double lat;
  final double lon;
}

class PlannedRoute {
  const PlannedRoute({
    required this.id,
    required this.name,
    required this.createdAtUtcMs,
    required this.points,
  });

  final String id;
  final String name;
  final int createdAtUtcMs;
  final List<PlannedRoutePoint> points;
}

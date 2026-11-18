import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_palette.dart';
import '../../data/planned_route.dart';
import '../../data/planned_route_repository.dart';
import '../shared/app_bottom_navigation.dart';

/// A library of routes saved on this device. Selecting one returns it to the
/// planner, where it can be reviewed, edited, or used for a run.
class SavedRoutesScreen extends StatefulWidget {
  const SavedRoutesScreen({
    super.key,
    required this.repository,
    this.onPlanRoute,
    this.onRouteSelected,
    this.onHome,
    this.onRun,
    this.onHistory,
    this.onProfile,
  });

  final PlannedRouteRepository repository;
  final Future<void> Function()? onPlanRoute;
  final Future<void> Function(PlannedRoute)? onRouteSelected;
  final VoidCallback? onHome;
  final VoidCallback? onRun;
  final VoidCallback? onHistory;
  final VoidCallback? onProfile;

  static const Key emptyPlanKey = Key('savedRoutes.plan');
  static const Key planKey = Key('savedRoutes.planNew');

  @override
  State<SavedRoutesScreen> createState() => _SavedRoutesScreenState();
}

class _SavedRoutesScreenState extends State<SavedRoutesScreen> {
  late Future<List<PlannedRoute>> _routes = widget.repository.list();

  void _retry() => setState(() {
    _routes = widget.repository.list();
  });

  Future<void> _plan() async {
    final open = widget.onPlanRoute;
    if (open == null) {
      Navigator.of(context).pop();
      return;
    }
    await open();
    if (mounted) _retry();
  }

  Future<void> _select(PlannedRoute route) async {
    final open = widget.onRouteSelected;
    if (open == null) {
      Navigator.of(context).pop(route);
      return;
    }
    await open(route);
    if (mounted) _retry();
  }

  static double _distanceKm(PlannedRoute route) {
    const distance = Distance();
    var meters = 0.0;
    for (var i = 1; i < route.points.length; i++) {
      meters += distance.as(
        LengthUnit.Meter,
        LatLng(route.points[i - 1].lat, route.points[i - 1].lon),
        LatLng(route.points[i].lat, route.points[i].lon),
      );
    }
    return meters / 1000;
  }

  IconData _icon(RouteActivity activity) => switch (activity) {
    RouteActivity.walk => Icons.directions_walk_rounded,
    RouteActivity.run => Icons.directions_run_rounded,
    RouteActivity.cycle => Icons.directions_bike_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.onPlanRoute == null ? 'Saved routes' : 'Routes'),
      ),
      bottomNavigationBar:
          widget.onHome != null &&
              widget.onRun != null &&
              widget.onHistory != null &&
              widget.onProfile != null
          ? AppBottomNavigation(
              selected: MainDestination.routes,
              onHome: widget.onHome!,
              onRoutes: () {},
              onRun: widget.onRun!,
              onHistory: widget.onHistory!,
              onProfile: widget.onProfile!,
            )
          : null,
      body: FutureBuilder<List<PlannedRoute>>(
        future: _routes,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load saved routes.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _retry,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            );
          }
          final routes = snapshot.data ?? const <PlannedRoute>[];
          if (routes.isEmpty && widget.onPlanRoute == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bookmark_border_rounded,
                      size: 48,
                      color: palette.accent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No saved routes yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Plan a route and tap Save route to keep it here.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: SavedRoutesScreen.emptyPlanKey,
                      onPressed: _plan,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Plan a route'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              if (widget.onPlanRoute != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.alt_route_rounded,
                              color: palette.accent,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Plan a new route',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Choose a start, destination, and activity.',
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          key: SavedRoutesScreen.planKey,
                          onPressed: _plan,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Plan route'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Saved routes',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
              ],
              if (routes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No saved routes yet. Your routes will appear here after you save one.',
                    textAlign: TextAlign.center,
                  ),
                ),
              if (routes.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${routes.length} ${routes.length == 1 ? 'route' : 'routes'} saved on this device',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                for (final route in routes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: ListTile(
                        key: Key('savedRoutes.${route.id}'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: palette.iconTile,
                          child: Icon(
                            _icon(route.activity),
                            color: palette.accent,
                          ),
                        ),
                        title: Text(
                          route.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${route.activity.label} · ${_distanceKm(route).toStringAsFixed(2)} km\n'
                          '${MaterialLocalizations.of(context).formatMediumDate(DateTime.fromMillisecondsSinceEpoch(route.createdAtUtcMs))}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _select(route),
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

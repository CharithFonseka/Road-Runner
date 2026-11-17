import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_palette.dart';
import '../../data/current_weather_client.dart';
import '../../data/planned_route.dart';
import '../../data/planned_route_repository.dart';
import '../../data/run_weather_client.dart';
import 'ors_directions_client.dart';
import 'place_search_client.dart';
import 'route_point_picker_sheet.dart';
import 'saved_routes_screen.dart';

/// Pick two map points or search a destination, preview the walking route,
/// then save or start a run.
class RoutePlanningScreen extends StatefulWidget {
  const RoutePlanningScreen({
    super.key,
    required this.repository,
    required this.directions,
    required this.initialCenter,
    this.initialZoom = 13,
    this.styleFuture,
    this.placeSearch,
    this.onStartRun,
    this.weatherFetcher,
    this.onCurrentLocation,
    this.initialRoute,
  });

  final PlannedRouteRepository repository;
  final OrsDirectionsClient directions;
  final LatLng initialCenter;
  final double initialZoom;
  final Future<vt.Style>? styleFuture;
  final PlaceSearchClient? placeSearch;
  final ValueChanged<PlannedRoute?>? onStartRun;
  final Future<RunWeather?> Function(LatLng)? weatherFetcher;
  final Future<LatLng?> Function()? onCurrentLocation;
  final PlannedRoute? initialRoute;

  static const Key mapKey = Key('routePlanning.map');
  static const Key searchFieldKey = RoutePointPickerSheet.searchFieldKey;
  static const Key nameFieldKey = Key('routePlanning.name');
  static const Key findKey = Key('routePlanning.find');
  static const Key saveKey = Key('routePlanning.save');
  static const Key startRunKey = Key('routePlanning.startRun');
  static const Key startPointKey = Key('routePlanning.startPoint');
  static const Key endPointKey = Key('routePlanning.endPoint');
  static const Key currentLocationKey =
      RoutePointPickerSheet.currentLocationKey;
  static const Key activitySelectorKey = Key('routePlanning.activity');
  static const Key inputPanelKey = Key('routePlanning.inputPanel');
  static const Key savedRoutesKey = Key('routePlanning.savedRoutes');

  @override
  State<RoutePlanningScreen> createState() => _RoutePlanningScreenState();
}

class _RoutePlanningScreenState extends State<RoutePlanningScreen> {
  final MapController _controller = MapController();
  final TextEditingController _name = TextEditingController(
    text: 'Planned route',
  );
  late final PlaceSearchClient _placeSearch =
      widget.placeSearch ?? PlaceSearchClient();
  late final Future<vt.Style> _style =
      widget.styleFuture ??
      vt.StyleReader(uri: 'https://tiles.openfreemap.org/styles/liberty')
          .read();

  LatLng? _start;
  LatLng? _finish;
  String _startLabel = 'Choose start';
  String _finishLabel = 'Choose end';
  bool _choosingStart = true;
  int _routeGeneration = 0;
  RouteActivity _activity = RouteActivity.run;
  List<PlannedRoutePoint>? _preview;
  bool _busy = false;
  bool _mapReady = false;
  RunWeather? _weather;
  String? _weatherArea;
  int _weatherRequest = 0;
  PlannedRoute? _loadedRoute;

  @override
  void initState() {
    super.initState();
    final route = widget.initialRoute;
    if (route != null) {
      _loadedRoute = route;
      _activity = route.activity;
      _start = LatLng(route.points.first.lat, route.points.first.lon);
      _finish = LatLng(route.points.last.lat, route.points.last.lon);
      _startLabel = 'Saved start';
      _finishLabel = 'Saved destination';
      _choosingStart = false;
      _preview = route.points;
      _name.text = route.name;
      _loadWeather(_start!, 'Saved start');
      return;
    }
    if (widget.initialCenter.latitude != 0 ||
        widget.initialCenter.longitude != 0) {
      _loadWeather(widget.initialCenter, 'Map area');
    }
  }

  Future<void> _loadWeather(LatLng point, String area) async {
    final request = ++_weatherRequest;
    final fetcher = widget.weatherFetcher;
    final weather = fetcher != null
        ? await fetcher(point)
        : await const CurrentWeatherClient().fetch(
            point.latitude,
            point.longitude,
          );
    if (mounted && request == _weatherRequest) {
      setState(() {
        _weather = weather;
        _weatherArea = area;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _name.dispose();
    _style.then((style) => style.dispose()).ignore();
    super.dispose();
  }

  void _selectPoint(LatLng point, {String label = 'Map point'}) {
    final choosingStart = _choosingStart;
    setState(() {
      _routeGeneration++;
      if (choosingStart) {
        _start = point;
        _startLabel = label;
        _choosingStart = false;
      } else {
        _finish = point;
        _finishLabel = label;
      }
      _preview = null;
    });
    if (choosingStart) {
      unawaited(
        _loadWeather(
          point,
          label == 'Current location' ? 'Near you' : 'Selected start',
        ),
      );
    }
    if (_start != null && _finish != null) {
      unawaited(_findRoute());
    }
  }

  void _selectActivity(RouteActivity activity) {
    if (_activity == activity) return;
    setState(() {
      _activity = activity;
      _routeGeneration++;
      _preview = null;
    });
    if (_start != null && _finish != null && !_busy) {
      unawaited(_findRoute());
    }
  }

  Future<void> _openPointPicker(bool start) async {
    setState(() => _choosingStart = start);
    final choice = await showModalBottomSheet<RoutePointChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => RoutePointPickerSheet(
        isStart: start,
        placeSearch: _placeSearch,
        biasCenter: _mapReady
            ? _controller.camera.center
            : widget.initialCenter,
        currentLocationGetter: widget.onCurrentLocation,
      ),
    );
    if (!mounted || choice?.point == null) return;
    _selectPoint(choice!.point!, label: choice.label ?? 'Selected place');
    if (!start &&
        choice.label != 'Current location' &&
        (_name.text.trim().isEmpty || _name.text == 'Planned route')) {
      _name.text = '${_activity.label} to ${choice.label}';
    }
    if (_mapReady) {
      _controller.move(choice.point!, math.max(_controller.camera.zoom, 14));
    }
  }

  Future<void> _openSavedRoutes() async {
    final route = await Navigator.of(context).push<PlannedRoute>(
      MaterialPageRoute(
        builder: (_) => SavedRoutesScreen(repository: widget.repository),
      ),
    );
    if (!mounted || route == null) return;
    setState(() {
      _routeGeneration++;
      _loadedRoute = route;
      _activity = route.activity;
      _start = LatLng(route.points.first.lat, route.points.first.lon);
      _finish = LatLng(route.points.last.lat, route.points.last.lon);
      _startLabel = 'Saved start';
      _finishLabel = 'Saved destination';
      _choosingStart = false;
      _preview = route.points;
      _name.text = route.name;
    });
    _fitRoute(route.points);
    unawaited(_loadWeather(_start!, 'Saved start'));
  }

  void _fitRoute(List<PlannedRoutePoint> points) {
    if (!mounted || !_mapReady) return;
    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: [for (final p in points) LatLng(p.lat, p.lon)],
        padding: const EdgeInsets.all(28),
        maxZoom: 17,
      ),
    );
  }

  Future<void> _findRoute() async {
    if (_start == null || _finish == null || _busy) return;
    final generation = _routeGeneration;
    setState(() => _busy = true);
    try {
      final points = await widget.directions.route(
        _start!,
        _finish!,
        activity: _activity,
      );
      if (!mounted || generation != _routeGeneration) return;
      setState(() => _preview = points);
      if (_mapReady) {
        _controller.fitCamera(
          CameraFit.coordinates(
            coordinates: [for (final p in points) LatLng(p.lat, p.lon)],
            padding: const EdgeInsets.all(28),
            maxZoom: 17,
          ),
        );
      }
    } catch (error) {
      if (mounted && generation == _routeGeneration) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not plan route: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (generation != _routeGeneration &&
            _start != null &&
            _finish != null) {
          unawaited(_findRoute());
        }
      }
    }
  }

  Future<PlannedRoute?> _saveRoute() async {
    final points = _preview;
    if (points == null || _busy) return null;
    setState(() => _busy = true);
    try {
      final now = DateTime.now().toUtc();
      final route = PlannedRoute(
        id: _loadedRoute?.id ?? 'planned-${now.microsecondsSinceEpoch}',
        name: _name.text,
        createdAtUtcMs:
            _loadedRoute?.createdAtUtcMs ?? now.millisecondsSinceEpoch,
        points: points,
        activity: _activity,
      );
      await widget.repository.save(route);
      return route;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save route: $error')));
      }
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final route = await _saveRoute();
    if (route != null && mounted) {
      Navigator.of(context).pop(route);
    }
  }

  Future<void> _saveAndStart() async {
    if (_preview == null) {
      widget.onStartRun?.call(null);
      return;
    }
    final route = await _saveRoute();
    if (route == null || !mounted) return;
    final onStartRun = widget.onStartRun;
    if (onStartRun != null) {
      onStartRun(route);
    } else {
      Navigator.of(context).pop(route);
    }
  }

  static double _routeDistanceKm(List<PlannedRoutePoint> points) {
    const distance = Distance();
    var meters = 0.0;
    for (var i = 1; i < points.length; i++) {
      meters += distance.as(
        LengthUnit.Meter,
        LatLng(points[i - 1].lat, points[i - 1].lon),
        LatLng(points[i].lat, points[i].lon),
      );
    }
    return meters / 1000.0;
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final routeCredit = widget.directions.usesOpenRouteService
        ? 'Route © openrouteservice.org by HeiGIT'
        : 'Route © Project OSRM';
    final palette = AppPalette.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan a route'),
        actions: [
          TextButton.icon(
            key: RoutePlanningScreen.savedRoutesKey,
            onPressed: _openSavedRoutes,
            icon: const Icon(Icons.bookmark_outline_rounded),
            label: const Text('Saved'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<vt.Style>(
              future: _style,
              builder: (context, styleSnapshot) => Stack(
                children: [
                  FlutterMap(
                    key: RoutePlanningScreen.mapKey,
                    mapController: _controller,
                    options: MapOptions(
                      initialCenter: widget.initialCenter,
                      initialZoom: widget.initialZoom,
                      maxZoom: 20,
                      backgroundColor: palette.mapBackground,
                      onMapReady: () {
                        _mapReady = true;
                        final points = _preview;
                        if (points != null) {
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _fitRoute(points),
                          );
                        }
                      },
                      onTap: (_, point) => _selectPoint(point),
                    ),
                    children: [
                      if (styleSnapshot.hasData)
                        vt.VectorTileLayer(
                          theme: styleSnapshot.data!.theme,
                          tileProviders: styleSnapshot.data!.providers,
                          rasterSources: styleSnapshot.data!.rasterSources,
                          sprites: styleSnapshot.data!.sprites,
                          glyphs: styleSnapshot.data!.glyphs,
                        ),
                      if (preview != null)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: [
                                for (final p in preview) LatLng(p.lat, p.lon),
                              ],
                              color: palette.routePlain,
                              strokeWidth: 5,
                              borderColor: palette.routeCasing,
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          if (_start != null)
                            Marker(
                              point: _start!,
                              width: 32,
                              height: 32,
                              child: Icon(
                                Icons.trip_origin,
                                color: palette.routeStart,
                              ),
                            ),
                          if (_finish != null)
                            Marker(
                              point: _finish!,
                              width: 32,
                              height: 32,
                              child: Icon(
                                Icons.flag,
                                color: palette.routeFinish,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (styleSnapshot.hasError)
                    Positioned(
                      top: 68,
                      left: 12,
                      child: _MapNote(
                        'Street map unavailable',
                        palette: palette,
                      ),
                    ),
                  Positioned(
                    top: 10,
                    left: 12,
                    right: 12,
                    child: Material(
                      key: RoutePlanningScreen.inputPanelKey,
                      elevation: 3,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      color: palette.surface,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                                child: SegmentedButton<RouteActivity>(
                                  key: RoutePlanningScreen.activitySelectorKey,
                                  style: ButtonStyle(
                                    backgroundColor:
                                        WidgetStateProperty.resolveWith(
                                          (states) =>
                                              states.contains(
                                                WidgetState.selected,
                                              )
                                              ? palette.iconTile
                                              : palette.surface,
                                        ),
                                    foregroundColor:
                                        WidgetStateProperty.resolveWith(
                                          (states) =>
                                              states.contains(
                                                WidgetState.selected,
                                              )
                                              ? palette.accent
                                              : palette.textPrimary,
                                        ),
                                    side: WidgetStatePropertyAll(
                                      BorderSide(color: palette.buttonOutline),
                                    ),
                                  ),
                                  segments: const [
                                    ButtonSegment(
                                      value: RouteActivity.walk,
                                      icon: Icon(
                                        Icons.directions_walk_rounded,
                                        size: 18,
                                      ),
                                      label: Text('Walk'),
                                    ),
                                    ButtonSegment(
                                      value: RouteActivity.run,
                                      icon: Icon(
                                        Icons.directions_run_rounded,
                                        size: 18,
                                      ),
                                      label: Text('Run'),
                                    ),
                                    ButtonSegment(
                                      value: RouteActivity.cycle,
                                      icon: Icon(
                                        Icons.directions_bike_rounded,
                                        size: 18,
                                      ),
                                      label: Text('Cycle'),
                                    ),
                                  ],
                                  selected: {_activity},
                                  onSelectionChanged: (selection) =>
                                      _selectActivity(selection.first),
                                ),
                              ),
                              ListTile(
                                key: RoutePlanningScreen.startPointKey,
                                dense: true,
                                leading: Icon(
                                  Icons.trip_origin_rounded,
                                  color: palette.routeStart,
                                ),
                                title: const Text('Start'),
                                subtitle: Text(
                                  _startLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                                onTap: () => _openPointPicker(true),
                              ),
                              Divider(height: 1, color: palette.hairline),
                              ListTile(
                                key: RoutePlanningScreen.endPointKey,
                                dense: true,
                                leading: Icon(
                                  Icons.flag_rounded,
                                  color: palette.routeFinish,
                                ),
                                title: const Text('Destination'),
                                subtitle: Text(
                                  _finishLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                                onTap: () => _openPointPicker(false),
                              ),
                              if (_weather != null)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    8,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.wb_cloudy_outlined,
                                        size: 18,
                                        color: palette.accent,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${_weatherArea ?? 'Selected area'} · ${_weather!.temperatureC?.round() ?? '—'}°C · ${weatherDescription(_weather)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    left: 6,
                    right: 6,
                    child: Center(
                      child: _MapNote(
                        'OpenFreeMap © OpenMapTiles · Data from © OpenStreetMap\n'
                        '$routeCredit',
                        palette: palette,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    preview != null
                        ? '${_activity.label} route ready · ${_routeDistanceKm(preview).toStringAsFixed(2)} km'
                        : 'Choose a start and destination above, or tap the map to set each point.',
                  ),
                  if (preview != null) ...[
                    const SizedBox(height: 8),
                    TextField(
                      key: RoutePlanningScreen.nameFieldKey,
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Route name',
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () {
                                setState(() {
                                  _routeGeneration++;
                                  _start = null;
                                  _finish = null;
                                  _startLabel = 'Choose start';
                                  _finishLabel = 'Choose end';
                                  _choosingStart = true;
                                  _preview = null;
                                  _loadedRoute = null;
                                });
                              },
                        child: const Text('Clear'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: preview == null
                            ? FilledButton(
                                key: RoutePlanningScreen.findKey,
                                onPressed:
                                    _start != null && _finish != null && !_busy
                                    ? _findRoute
                                    : null,
                                child: Text(
                                  'Find ${_activity.label.toLowerCase()} route',
                                ),
                              )
                            : OutlinedButton(
                                key: RoutePlanningScreen.saveKey,
                                onPressed: _busy ? null : _save,
                                child: Text(
                                  _loadedRoute == null
                                      ? 'Save route'
                                      : 'Update route',
                                ),
                              ),
                      ),
                    ],
                  ),
                  if (_activity == RouteActivity.run &&
                      widget.onStartRun != null) ...[
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      key: RoutePlanningScreen.startRunKey,
                      onPressed: _busy ? null : _saveAndStart,
                      icon: const Icon(Icons.directions_run_rounded),
                      label: Text(
                        preview == null ? 'Start run' : 'Save & start run',
                      ),
                    ),
                  ] else if (_activity != RouteActivity.run) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Save this ${_activity.label.toLowerCase()} route. GPS tracking and badges are for runs.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapNote extends StatelessWidget {
  const _MapNote(this.label, {required this.palette});

  final String label;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: palette.surface.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, color: palette.textPrimary),
      ),
    ),
  );
}

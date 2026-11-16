import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_palette.dart';
import '../../data/planned_route.dart';
import '../../data/planned_route_repository.dart';
import 'ors_directions_client.dart';

/// Pick two map points, preview the walking route, then save or start a run.
class RoutePlanningScreen extends StatefulWidget {
  const RoutePlanningScreen({
    super.key,
    required this.repository,
    required this.directions,
    required this.initialCenter,
    this.initialZoom = 13,
    this.styleFuture,
    this.onStartRun,
  });

  final PlannedRouteRepository repository;
  final OrsDirectionsClient directions;
  final LatLng initialCenter;
  final double initialZoom;
  final Future<vt.Style>? styleFuture;
  final ValueChanged<PlannedRoute>? onStartRun;

  static const Key mapKey = Key('routePlanning.map');
  static const Key findKey = Key('routePlanning.find');
  static const Key saveKey = Key('routePlanning.save');
  static const Key startRunKey = Key('routePlanning.startRun');

  @override
  State<RoutePlanningScreen> createState() => _RoutePlanningScreenState();
}

class _RoutePlanningScreenState extends State<RoutePlanningScreen> {
  final MapController _controller = MapController();
  final TextEditingController _name = TextEditingController(
    text: 'Planned route',
  );
  late final Future<vt.Style> _style =
      widget.styleFuture ??
      vt.StyleReader(uri: 'https://tiles.openfreemap.org/styles/liberty')
          .read();

  LatLng? _start;
  LatLng? _finish;
  List<PlannedRoutePoint>? _preview;
  bool _busy = false;
  bool _mapReady = false;

  @override
  void dispose() {
    _controller.dispose();
    _name.dispose();
    _style.then((style) => style.dispose()).ignore();
    super.dispose();
  }

  void _selectPoint(LatLng point) {
    final shouldFetch = _start != null && _finish == null;
    setState(() {
      if (_start == null || _finish != null) {
        _start = point;
        _finish = null;
      } else {
        _finish = point;
      }
      _preview = null;
    });
    if (shouldFetch) {
      unawaited(_findRoute());
    }
  }

  Future<void> _findRoute() async {
    if (_start == null || _finish == null || _busy) return;
    setState(() => _busy = true);
    try {
      final points = await widget.directions.walkingRoute(_start!, _finish!);
      if (!mounted) return;
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not plan route: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<PlannedRoute?> _saveRoute() async {
    final points = _preview;
    if (points == null || _busy) return null;
    setState(() => _busy = true);
    try {
      final now = DateTime.now().toUtc();
      final route = PlannedRoute(
        id: 'planned-${now.microsecondsSinceEpoch}',
        name: _name.text,
        createdAtUtcMs: now.millisecondsSinceEpoch,
        points: points,
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
      appBar: AppBar(title: const Text('Plan a route')),
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
                      onMapReady: () => _mapReady = true,
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
                      top: 8,
                      left: 8,
                      child: _MapNote(
                        'Street map unavailable',
                        palette: palette,
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
                children: [
                  Text(
                    preview != null
                        ? 'Route ready · ${_routeDistanceKm(preview).toStringAsFixed(2)} km'
                        : 'Tap the map for start, then tap for finish.',
                  ),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Route name'),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _start = null;
                                _finish = null;
                                _preview = null;
                              }),
                        child: const Text('Clear'),
                      ),
                      FilledButton.tonal(
                        key: RoutePlanningScreen.findKey,
                        onPressed: _start != null && _finish != null && !_busy
                            ? _findRoute
                            : null,
                        child: const Text('Find walking route'),
                      ),
                      FilledButton.tonal(
                        key: RoutePlanningScreen.saveKey,
                        onPressed: preview != null && !_busy ? _save : null,
                        child: const Text('Save route'),
                      ),
                      FilledButton(
                        key: RoutePlanningScreen.startRunKey,
                        onPressed: preview != null && !_busy
                            ? _saveAndStart
                            : null,
                        child: const Text('Save & Start run'),
                      ),
                    ],
                  ),
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

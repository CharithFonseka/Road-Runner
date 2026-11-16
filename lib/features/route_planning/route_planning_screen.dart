import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_palette.dart';
import '../../data/planned_route.dart';
import '../../data/planned_route_repository.dart';
import '../app_strings.dart';
import 'ors_directions_client.dart';

/// Pick two map points, preview the walking route, then save it locally.
class RoutePlanningScreen extends StatefulWidget {
  const RoutePlanningScreen({
    super.key,
    required this.repository,
    required this.directions,
    required this.initialCenter,
    this.initialZoom = 13,
    this.styleFuture,
  });

  final PlannedRouteRepository repository;
  final OrsDirectionsClient directions;
  final LatLng initialCenter;
  final double initialZoom;
  final Future<vt.Style>? styleFuture;

  static const Key mapKey = Key('routePlanning.map');
  static const Key findKey = Key('routePlanning.find');
  static const Key saveKey = Key('routePlanning.save');

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
    setState(() {
      if (_start == null || _finish != null) {
        _start = point;
        _finish = null;
      } else {
        _finish = point;
      }
      _preview = null;
    });
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.routeFindFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final points = _preview;
    if (points == null || _busy) return;
    setState(() => _busy = true);
    try {
      final now = DateTime.now().toUtc();
      await widget.repository.save(
        PlannedRoute(
          id: 'planned-${now.microsecondsSinceEpoch}',
          name: _name.text,
          createdAtUtcMs: now.millisecondsSinceEpoch,
          points: points,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.routeSaveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final hasRouteService = widget.directions.apiKey.trim().isNotEmpty;
    final palette = AppPalette.of(context);
    final step = _start == null ? 1 : (_finish == null ? 2 : 3);
    final instruction = _start == null
        ? AppStrings.routeChooseStart
        : _finish == null
        ? AppStrings.routeChooseFinish
        : preview == null
        ? AppStrings.routePreviewPrompt
        : AppStrings.routeSavePrompt;
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.planRoute)),
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
                  if (styleSnapshot.connectionState == ConnectionState.waiting)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _MapNote(
                        AppStrings.routeStreetMapLoading,
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
                        'Route © openrouteservice.org by HeiGIT',
                        palette: palette,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: palette.primaryFill,
                          foregroundColor: palette.onPrimaryFill,
                          child: Text('$step'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            instruction,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    if (!hasRouteService)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(AppStrings.routeServiceUnavailable),
                      ),
                    if (_start != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _finish == null
                            ? AppStrings.routeStartSelected
                            : AppStrings.routeBothSelected,
                      ),
                    ],
                    if (preview != null) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _name,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: AppStrings.routeName,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (_start != null) ...[
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                    _start = null;
                                    _finish = null;
                                    _preview = null;
                                  }),
                            child: const Text(AppStrings.routeClear),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: preview == null
                              ? FilledButton(
                                  key: RoutePlanningScreen.findKey,
                                  onPressed:
                                      hasRouteService &&
                                          _start != null &&
                                          _finish != null &&
                                          !_busy
                                      ? _findRoute
                                      : null,
                                  child: _busy
                                      ? const SizedBox.square(
                                          dimension: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(AppStrings.routeFind),
                                )
                              : FilledButton(
                                  key: RoutePlanningScreen.saveKey,
                                  onPressed: _busy ? null : _save,
                                  child: _busy
                                      ? const SizedBox.square(
                                          dimension: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(AppStrings.routeSave),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
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

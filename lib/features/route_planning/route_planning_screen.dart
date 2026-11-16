import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

import '../../core/theme/app_palette.dart';
import '../../data/planned_route.dart';
import '../../data/planned_route_repository.dart';
import '../../data/current_weather_client.dart';
import '../../data/run_weather_client.dart';
import '../app_strings.dart';
import 'ors_directions_client.dart';

/// Search an area, check current weather, pick map points and save or start.
class RoutePlanningScreen extends StatefulWidget {
  const RoutePlanningScreen({
    super.key,
    required this.repository,
    required this.directions,
    required this.initialCenter,
    this.initialZoom = 13,
    this.styleFuture,
    this.onStartRun,
    this.weatherFetcher,
  });

  final PlannedRouteRepository repository;
  final OrsDirectionsClient directions;
  final LatLng initialCenter;
  final double initialZoom;
  final Future<vt.Style>? styleFuture;
  final VoidCallback? onStartRun;
  final Future<RunWeather?> Function(LatLng)? weatherFetcher;

  static const Key mapKey = Key('routePlanning.map');
  static const Key findKey = Key('routePlanning.find');
  static const Key saveKey = Key('routePlanning.save');
  static const Key searchKey = Key('routePlanning.search');
  static const Key nameKey = Key('routePlanning.name');
  static const Key startRunKey = Key('routePlanning.startRun');

  @override
  State<RoutePlanningScreen> createState() => _RoutePlanningScreenState();
}

class _RoutePlanningScreenState extends State<RoutePlanningScreen> {
  final MapController _controller = MapController();
  final TextEditingController _name = TextEditingController(
    text: 'Planned route',
  );
  final TextEditingController _search = TextEditingController();
  late final Future<vt.Style> _style =
      widget.styleFuture ??
      vt.StyleReader(uri: 'https://tiles.openfreemap.org/styles/liberty')
          .read();

  LatLng? _start;
  LatLng? _finish;
  List<PlannedRoutePoint>? _preview;
  bool _busy = false;
  bool _mapReady = false;
  bool _searchBusy = false;
  String? _areaName;
  RunWeather? _weather;
  int _weatherRequest = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialCenter.latitude != 0 ||
        widget.initialCenter.longitude != 0) {
      _areaName = 'Near your last run';
      _loadWeather(widget.initialCenter);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _name.dispose();
    _search.dispose();
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
    if (_finish == null) {
      _areaName = 'Selected start';
      _loadWeather(point);
    }
  }

  Future<void> _loadWeather(LatLng point) async {
    final request = ++_weatherRequest;
    final weather =
        await (widget.weatherFetcher?.call(point) ??
            const CurrentWeatherClient().fetch(
              point.latitude,
              point.longitude,
            ));
    if (mounted && request == _weatherRequest) {
      setState(() => _weather = weather);
    }
  }

  Future<void> _searchPlace() async {
    final query = _search.text.trim();
    if (query.length < 2 || _searchBusy) return;
    setState(() => _searchBusy = true);
    try {
      final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': query,
        'count': '1',
        'language': 'en',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) {
        throw const FormatException('Search unavailable');
      }
      final result =
          (jsonDecode(response.body) as Map<String, dynamic>)['results'];
      if (result is! List || result.isEmpty) {
        throw const FormatException('No places found');
      }
      final place = result.first as Map<String, dynamic>;
      final center = LatLng(
        (place['latitude'] as num).toDouble(),
        (place['longitude'] as num).toDouble(),
      );
      if (!mounted) return;
      setState(() => _areaName = place['name'] as String? ?? query);
      if (_mapReady) _controller.move(center, 14);
      _loadWeather(center);
      FocusManager.instance.primaryFocus?.unfocus();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Place not found. Try a nearby city or town.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _searchBusy = false);
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

  Future<void> _save({bool startAfter = false}) async {
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
      if (mounted) {
        Navigator.of(context).pop();
        if (startAfter) widget.onStartRun?.call();
      }
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

  Future<void> _startRun() async {
    if (_busy || widget.onStartRun == null) return;
    if (_preview != null) {
      await _save(startAfter: true);
    } else {
      Navigator.of(context).pop();
      widget.onStartRun?.call();
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
                  Positioned(
                    top: 8,
                    left: 12,
                    right: 12,
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          Material(
                            color: palette.surface,
                            elevation: 3,
                            borderRadius: BorderRadius.circular(14),
                            child: TextField(
                              key: RoutePlanningScreen.searchKey,
                              controller: _search,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _searchPlace(),
                              decoration: InputDecoration(
                                hintText: 'Search city or place',
                                prefixIcon: const Icon(Icons.search_rounded),
                                suffixIcon: IconButton(
                                  tooltip: 'Find place',
                                  onPressed: _searchBusy ? null : _searchPlace,
                                  icon: _searchBusy
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.arrow_forward_rounded),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          if (_weather != null) ...[
                            const SizedBox(height: 8),
                            Material(
                              color: palette.surface,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.wb_cloudy_outlined,
                                      color: palette.accent,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${_areaName ?? 'Selected area'} · ${_weather!.temperatureC?.round() ?? '—'}°C · ${weatherDescription(_weather)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
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
                        key: RoutePlanningScreen.nameKey,
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
                              : OutlinedButton(
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
                    if (widget.onStartRun != null) ...[
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        key: RoutePlanningScreen.startRunKey,
                        onPressed: _busy ? null : _startRun,
                        icon: const Icon(Icons.directions_run_rounded),
                        label: Text(
                          preview == null ? 'Start run' : 'Save & start run',
                        ),
                      ),
                    ],
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

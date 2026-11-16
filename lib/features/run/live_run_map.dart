import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:latlong2/latlong.dart';

import '../../bridge/tracking_bridge.dart';
import '../../core/theme/app_palette.dart';

/// Street map for an active run. Coordinates are always local; only map tiles
/// are fetched from OpenFreeMap. The route remains visible when tiles cannot load.
class LiveRunMap extends StatefulWidget {
  const LiveRunMap({super.key, required this.route, required this.snapshot});

  final List<TrackingPoint> route;
  final TrackingSnapshot? snapshot;

  @override
  State<LiveRunMap> createState() => _LiveRunMapState();
}

class _LiveRunMapState extends State<LiveRunMap> {
  final MapController _controller = MapController();
  Future<vt.Style>? _style;
  bool _mapReady = false;
  bool _following = true;

  static LatLng? _validPosition(double? lat, double? lon) {
    if (lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      return null;
    }
    return LatLng(lat, lon);
  }

  LatLng? get _position =>
      _validPosition(widget.snapshot?.lat, widget.snapshot?.lon) ??
      (widget.route.isEmpty
          ? null
          : _validPosition(widget.route.last.lat, widget.route.last.lon));

  @override
  void didUpdateWidget(covariant LiveRunMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous =
        _validPosition(oldWidget.snapshot?.lat, oldWidget.snapshot?.lon) ??
        (oldWidget.route.isEmpty
            ? null
            : _validPosition(
                oldWidget.route.last.lat,
                oldWidget.route.last.lon,
              ));
    final current = _position;
    if (_mapReady && _following && current != null && current != previous) {
      _controller.move(current, _controller.camera.zoom);
    }
  }

  @override
  void dispose() {
    _style?.then((style) => style.dispose()).ignore();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final position = _position;
    final route = widget.route
        .map((point) => _validPosition(point.lat, point.lon))
        .whereType<LatLng>()
        .toList(growable: false);

    if (position == null) {
      // Keep the existing stat layout until the first accepted GPS fix.
      return const SizedBox.shrink();
    }

    _style ??= vt.StyleReader(
      uri: 'https://tiles.openfreemap.org/styles/liberty',
    ).read();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        key: const Key('activeRun.liveMap'),
        height: 160,
        child: FutureBuilder<vt.Style>(
          future: _style,
          builder: (context, styleSnapshot) => Stack(
            children: [
              FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: position,
                  initialZoom: 16,
                  maxZoom: 20,
                  backgroundColor: palette.mapBackground,
                  onMapReady: () => _mapReady = true,
                  onPositionChanged: (_, hasGesture) {
                    if (hasGesture) _following = false;
                  },
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
                  if (route.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: route,
                          color: palette.routePlain,
                          strokeWidth: 5,
                          borderColor: palette.routeCasing,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (route.isNotEmpty)
                        Marker(
                          point: route.first,
                          width: 18,
                          height: 18,
                          child: Icon(
                            Icons.circle,
                            color: palette.routeStart,
                            size: 17,
                          ),
                        ),
                      Marker(
                        point: position,
                        width: 34,
                        height: 34,
                        child: Icon(
                          Icons.my_location,
                          color: palette.accent,
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (styleSnapshot.hasError)
                const Positioned(
                  top: 8,
                  left: 8,
                  child: _MapNote(
                    'Street map unavailable; route is still shown',
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filledTonal(
                  tooltip: 'Follow my position',
                  onPressed: () {
                    _following = true;
                    _controller.move(position, _controller.camera.zoom);
                  },
                  icon: const Icon(Icons.my_location),
                ),
              ),
              const Positioned(
                bottom: 4,
                left: 4,
                right: 4,
                child: Center(
                  child: _MapNote('© OpenMapTiles · Data from © OpenStreetMap'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapNote extends StatelessWidget {
  const _MapNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.palette.surface.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: context.palette.textPrimary),
      ),
    ),
  );
}

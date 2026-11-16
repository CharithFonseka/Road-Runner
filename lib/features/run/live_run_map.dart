import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:latlong2/latlong.dart';

import '../../bridge/tracking_bridge.dart';
import '../../core/theme/app_palette.dart';

/// Street map for an active run. Coordinates are always local; only map tiles
/// are fetched from OpenFreeMap. The route remains visible when tiles cannot load.
class LiveRunMap extends StatefulWidget {
  const LiveRunMap({
    super.key,
    required this.route,
    required this.snapshot,
    this.height = 160,
    this.showSearchingPlaceholder = false,
  });

  final List<TrackingPoint> route;
  final TrackingSnapshot? snapshot;

  /// Height of the map. Defaults to 160 in portrait; null allows the map to
  /// expand to fill the available height in landscape mode.
  final double? height;

  /// Whether to display a styled placeholder when waiting for a GPS fix.
  final bool showSearchingPlaceholder;

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
      if (widget.showSearchingPlaceholder) {
        return _buildSearchingPlaceholder(context, palette);
      }
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
        height: widget.height,
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

  Widget _buildSearchingPlaceholder(BuildContext context, AppPalette palette) {
    final Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        key: const Key('activeRun.liveMap.placeholder'),
        decoration: BoxDecoration(
          color: palette.mapBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: palette.isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_searching_rounded,
                  size: 38,
                  color: palette.accent,
                ),
                const SizedBox(height: 10),
                Text(
                  'Searching for GPS…',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Live map will appear once satellites are acquired',
                  style: TextStyle(fontSize: 12, color: palette.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.height != null) {
      return SizedBox(height: widget.height, child: content);
    }
    return SizedBox.expand(child: content);
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

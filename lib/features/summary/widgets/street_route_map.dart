import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_palette.dart';
import '../run_summary.dart';
import 'route_painter.dart';

/// Fits the saved route to OpenFreeMap streets. Local route art remains visible
/// while tiles load or if the device is offline.
class StreetRouteMap extends StatefulWidget {
  const StreetRouteMap({
    super.key,
    required this.route,
    required this.fallback,
    this.styleFuture,
  });

  final List<RoutePoint> route;
  final Widget fallback;
  final Future<vt.Style>? styleFuture;

  @override
  State<StreetRouteMap> createState() => _StreetRouteMapState();
}

class _StreetRouteMapState extends State<StreetRouteMap> {
  late final Future<vt.Style> _style =
      widget.styleFuture ??
      vt.StyleReader(uri: 'https://tiles.openfreemap.org/styles/liberty')
          .read();

  @override
  void dispose() {
    _style.then((style) => style.dispose()).ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = widget.route
        .where(
          (p) =>
              p.lat.isFinite &&
              p.lon.isFinite &&
              p.lat >= -90 &&
              p.lat <= 90 &&
              p.lon >= -180 &&
              p.lon <= 180,
        )
        .toList(growable: false);
    if (!RouteGeometry.canDraw(valid)) return widget.fallback;
    final positions = [for (final p in valid) LatLng(p.lat, p.lon)];
    final palette = AppPalette.of(context);
    final gaps = RouteGeometry.gapSegments(valid);
    final colors = RouteGeometry.segmentColorsFor(valid, palette);
    final lines = <Polyline>[
      for (var i = 0; i < positions.length - 1; i++)
        Polyline(
          points: [positions[i], positions[i + 1]],
          color: gaps[i] ? palette.routePlain : colors[i] ?? palette.routePlain,
          strokeWidth: 5,
          borderColor: palette.routeCasing,
          borderStrokeWidth: 2,
          pattern: gaps[i]
              ? StrokePattern.dashed(segments: [6, 6])
              : const StrokePattern.solid(),
        ),
    ];

    return FutureBuilder<vt.Style>(
      future: _style,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (!snapshot.hasError) return widget.fallback;
          return Stack(
            children: [
              Positioned.fill(child: widget.fallback),
              Positioned(
                top: 8,
                left: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    child: Text(
                      'Street map unavailable',
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        final style = snapshot.data!;
        return Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.coordinates(
                  coordinates: positions,
                  padding: const EdgeInsets.all(28),
                  maxZoom: 17,
                ),
                backgroundColor: palette.mapBackground,
                maxZoom: 20,
              ),
              children: [
                vt.VectorTileLayer(
                  theme: style.theme,
                  tileProviders: style.providers,
                  rasterSources: style.rasterSources,
                  sprites: style.sprites,
                  glyphs: style.glyphs,
                ),
                PolylineLayer(polylines: lines),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: positions.first,
                      width: 24,
                      height: 24,
                      child: Icon(
                        Icons.circle,
                        color: palette.routeStart,
                        size: 18,
                      ),
                    ),
                    Marker(
                      point: positions.last,
                      width: 24,
                      height: 24,
                      child: Icon(
                        Icons.flag_rounded,
                        color: palette.routeFinish,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 6,
              bottom: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  child: Text(
                    '© OpenMapTiles · Data from © OpenStreetMap',
                    style: TextStyle(fontSize: 10, color: palette.textPrimary),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

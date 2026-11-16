import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';

import '../../data/planned_route.dart';

typedef RoutePoster = Future<Map<String, dynamic>> Function(
  Uri uri,
  String apiKey,
  Map<String, Object> body,
);

/// Requests one walking route only when the user asks for a preview.
class OrsDirectionsClient {
  OrsDirectionsClient({required this.apiKey, RoutePoster? post})
    : _post = post ?? _postJson;

  final String apiKey;
  final RoutePoster _post;

  static final Uri endpoint = Uri.parse(
    'https://api.heigit.org/openrouteservice/v2/'
    'directions/foot-walking/geojson',
  );

  Future<List<PlannedRoutePoint>> walkingRoute(
    LatLng start,
    LatLng finish,
  ) async {
    if (apiKey.trim().isEmpty) {
      throw StateError('Configure an OpenRouteService API key.');
    }
    if (!_valid(start) || !_valid(finish) || start == finish) {
      throw ArgumentError('Select two distinct valid map positions.');
    }

    final response = await _post(endpoint, apiKey, {
      // ORS and GeoJSON coordinates are longitude, latitude.
      'coordinates': [
        [start.longitude, start.latitude],
        [finish.longitude, finish.latitude],
      ],
    });

    final features = response['features'];
    if (features is! List || features.isEmpty) {
      throw const FormatException('No walking route was returned.');
    }
    final feature = features.first;
    if (feature is! Map || feature['geometry'] is! Map) {
      throw const FormatException('Invalid route geometry.');
    }
    final geometry = feature['geometry'] as Map;
    final coordinates = geometry['coordinates'];
    if (geometry['type'] != 'LineString' || coordinates is! List) {
      throw const FormatException('Expected a GeoJSON LineString.');
    }

    final points = <PlannedRoutePoint>[];
    for (final pair in coordinates) {
      if (pair is! List ||
          pair.length < 2 ||
          pair[0] is! num ||
          pair[1] is! num) {
        throw const FormatException('Invalid route coordinate.');
      }
      final lon = (pair[0] as num).toDouble();
      final lat = (pair[1] as num).toDouble();
      if (!lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180) {
        throw const FormatException('Route coordinate is out of range.');
      }
      points.add(PlannedRoutePoint(lat: lat, lon: lon));
    }
    if (points.length < 2 ||
        points.every(
          (point) =>
              point.lat == points.first.lat && point.lon == points.first.lon,
        )) {
      throw const FormatException('Route is too short.');
    }
    return List.unmodifiable(points);
  }

  static bool _valid(LatLng point) =>
      point.latitude.isFinite &&
      point.longitude.isFinite &&
      point.latitude.abs() <= 90 &&
      point.longitude.abs() <= 180;

  static Future<Map<String, dynamic>> _postJson(
    Uri uri,
    String apiKey,
    Map<String, Object> body,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 8));
      request.headers
        ..set('Authorization', apiKey)
        ..set('Accept', 'application/geo+json')
        ..contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Route request failed: HTTP ${response.statusCode}',
        );
      }
      final text = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 8));
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a GeoJSON object.');
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';

typedef PlaceFetcher = Future<Map<String, dynamic>> Function(Uri uri);

/// A geocoded place returned by [PlaceSearchClient].
class PlaceSearchResult {
  const PlaceSearchResult({
    required this.name,
    required this.subtitle,
    required this.location,
  });

  final String name;
  final String subtitle;
  final LatLng location;
}

/// Searches places via the free OpenStreetMap-based Photon API (no API key).
class PlaceSearchClient {
  PlaceSearchClient({PlaceFetcher? fetch}) : _fetch = fetch ?? _getJson;

  final PlaceFetcher _fetch;

  static Uri buildUri(String query, {LatLng? biasCenter, int limit = 5}) {
    final params = <String, String>{
      'q': query.trim(),
      'limit': '$limit',
      'lang': 'en',
    };
    if (biasCenter != null &&
        biasCenter.latitude.isFinite &&
        biasCenter.longitude.isFinite &&
        !(biasCenter.latitude == 0 && biasCenter.longitude == 0)) {
      params['lat'] = biasCenter.latitude.toStringAsFixed(5);
      params['lon'] = biasCenter.longitude.toStringAsFixed(5);
    }
    return Uri.https('photon.komoot.io', '/api/', params);
  }

  Future<List<PlaceSearchResult>> search(
    String query, {
    LatLng? biasCenter,
    int limit = 5,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      return const [];
    }

    final json = await _fetch(
      buildUri(trimmed, biasCenter: biasCenter, limit: limit),
    );
    final features = json['features'];
    if (features is! List) {
      return const [];
    }

    final results = <PlaceSearchResult>[];
    for (final item in features) {
      if (item is! Map) continue;
      final geometry = item['geometry'];
      final properties = item['properties'];
      if (geometry is! Map || properties is! Map) continue;

      final coords = geometry['coordinates'];
      if (coords is! List ||
          coords.length < 2 ||
          coords[0] is! num ||
          coords[1] is! num) {
        continue;
      }
      final lon = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();
      if (!lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180) {
        continue;
      }

      final rawName = _stringProp(properties, 'name');
      final street = _stringProp(properties, 'street');
      final city =
          _stringProp(properties, 'city') ??
          _stringProp(properties, 'town') ??
          _stringProp(properties, 'village');
      final state = _stringProp(properties, 'state');
      final country = _stringProp(properties, 'country');

      final title = rawName ?? street ?? city ?? country;
      if (title == null) continue;

      final subtitleParts = <String>[];
      for (final part in [street, city, state, country]) {
        if (part != null && part != title && !subtitleParts.contains(part)) {
          subtitleParts.add(part);
        }
      }

      results.add(
        PlaceSearchResult(
          name: title,
          subtitle: subtitleParts.join(', '),
          location: LatLng(lat, lon),
        ),
      );
    }
    return List.unmodifiable(results);
  }

  static String? _stringProp(Map properties, String key) {
    final value = properties[key];
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 6));
      request.headers.set('Accept', 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 6),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Place search failed: HTTP ${response.statusCode}');
      }
      final text = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 6));
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

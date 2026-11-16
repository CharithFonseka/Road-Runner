// Road Runner — Nominatim Reverse Geocoding Place Client
// Owner: Nadeesha
// SRS reference: Section 8.5

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:road_runner/data/place_cache.dart';
import 'package:road_runner/data/run_repository.dart';
import 'package:road_runner/domain/stats/models.dart';

class RunPlaceClient {
  const RunPlaceClient({
    required this.client,
    required this.cache,
    required this.contactEmail,
  });

  final http.Client client;
  final PlaceCache cache;
  final String contactEmail;

  Future<String?> lookup(Point point) async {
    final cached = await cache.get(point);
    if (cached != null) return cached;

    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': point.lat.toString(),
      'lon': point.lon.toString(),
      'format': 'jsonv2',
      'zoom': '10',
      'addressdetails': '1',
    });

    try {
      final response = await client
          .get(
            uri,
            headers: {'User-Agent': 'RoadRunner/0.1 (contact: $contactEmail)'},
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;

      final address = body['address'];
      if (address is! Map<String, dynamic>) return null;

      String? place;
      for (final key in [
        'suburb',
        'city',
        'town',
        'village',
        'municipality',
        'county',
      ]) {
        final value = address[key];
        if (value is String && value.trim().isNotEmpty) {
          place = value.trim();
          break;
        }
      }

      if (place != null) await cache.put(point, place);
      return place;
    } catch (_) {
      // A failed place lookup must not affect the saved run.
      return null;
    }
  }
}

/// Enriches a saved run with reverse-geocoded place name and generates a customized run name.
///
/// If offline or if there is no accepted point, the run receives the fallback
/// time-of-day name ("Morning run", "Afternoon run", or "Evening run").
Future<void> enrichRunPlace(
  String runId, {
  required RunRepository repository,
  required RunPlaceClient placeClient,
}) async {
  try {
    final run = await repository.get(runId);
    if (run == null) return;

    final points = await repository.getPoints(runId);
    Point? startPoint;
    for (final point in points) {
      if (point.accepted) {
        startPoint = point;
        break;
      }
    }

    final place = startPoint == null
        ? null
        : await placeClient.lookup(startPoint);

    final localStart = DateTime.fromMillisecondsSinceEpoch(
      run.startedAtUtcMs,
      isUtc: true,
    ).toLocal();

    await repository.updateDetails(
      runId,
      placeName: place,
      runName: makeRunName(localStart, place),
    );
  } catch (_) {
    // Place lookup failure must never fail the saved run.
  }
}

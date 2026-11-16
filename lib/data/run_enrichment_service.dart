// Road Runner — Run Enrichment Service
// Owner: Nadeesha
// SRS reference: Section 8.5

import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:road_runner/data/app_database.dart';
import 'package:road_runner/data/place_cache.dart';
import 'package:road_runner/data/run_place_client.dart';
import 'package:road_runner/data/run_repository.dart';
import 'package:road_runner/data/run_weather_client.dart';
import 'package:road_runner/domain/stats/models.dart';

/// Service orchestrating post-save asynchronous enrichment of runs with
/// weather conditions, reverse-geocoded place names, and friendly run titles.
class RunEnrichmentService {
  final RunRepository repository;
  final RunWeatherClient weatherClient;
  final RunPlaceClient placeClient;

  RunEnrichmentService({
    required this.repository,
    RunWeatherClient? weatherClient,
    RunPlaceClient? placeClient,
    http.Client? httpClient,
    AppDatabase? database,
    String contactEmail = 'support@roadrunner.local',
  }) : weatherClient =
           weatherClient ?? RunWeatherClient(httpClient ?? http.Client()),
       placeClient =
           placeClient ??
           RunPlaceClient(
             client: httpClient ?? http.Client(),
             cache: PlaceCache(database ?? AppDatabase.instance),
             contactEmail: contactEmail,
           );

  /// Performs post-save enrichment for [runId]:
  /// 1. Loads the already saved run and its recorded GPS points.
  /// 2. Saves a fallback run name and localStartDay immediately.
  /// 3. Finds the first accepted point to look up weather and cached place.
  /// 4. Updates run details in SQLite with any results received.
  /// 5. Returns cleanly without throwing if network or APIs fail.
  Future<void> enrichRun(String runId) async {
    try {
      final run = await repository.get(runId);
      if (run == null) return;

      final localStart = DateTime.fromMillisecondsSinceEpoch(
        run.startedAtUtcMs,
        isUtc: true,
      ).toLocal();
      final fallbackDay = run.localStartDay ?? localDay(localStart);
      final fallbackName =
          run.runName ?? makeRunName(localStart, run.placeName);

      // 1. Ensure fallback name and calendar day are saved
      if (run.runName == null || run.localStartDay == null) {
        await repository.updateDetails(
          runId,
          runName: fallbackName,
          localStartDay: fallbackDay,
        );
      }

      // 2. Locate first accepted GPS point
      final points = await repository.getPoints(runId);
      Point? startPoint;
      for (final point in points) {
        if (point.accepted) {
          startPoint = point;
          break;
        }
      }

      if (startPoint == null) return;

      // 3. Parallel non-blocking lookup for weather and place
      final weatherFuture = weatherClient.fetch(startPoint, run.startedAtUtcMs);
      final placeFuture = placeClient.lookup(startPoint);

      final weather = await weatherFuture;
      final place = await placeFuture;

      final resolvedPlace = place ?? run.placeName;
      final resolvedName = makeRunName(localStart, resolvedPlace);

      // 4. Update details in SQLite
      await repository.updateDetails(
        runId,
        runName: resolvedName,
        placeName: resolvedPlace,
        temperatureC: weather?.temperatureC,
        windKmh: weather?.windKmh,
        weatherCode: weather?.code,
        localStartDay: fallbackDay,
      );
    } catch (_) {
      // Enrichment failures never delay or break saved runs.
    }
  }
}

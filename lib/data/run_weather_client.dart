// Road Runner — Weather Client & Enrichment Service
// Owner: Nadeesha
// SRS reference: Section 8.5

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:road_runner/data/run_repository.dart';
import 'package:road_runner/domain/stats/models.dart';

/// Represents parsed weather values for a run.
class RunWeather {
  const RunWeather(this.temperatureC, this.windKmh, this.code);

  final double? temperatureC;
  final double? windKmh;
  final int? code;
}

/// Weather condition categories mapped from Open-Meteo WMO weather codes.
enum RunCondition {
  clear,
  cloudy,
  fog,
  drizzle,
  rain,
  snow,
  thunderstorm,
  unknown,
}

/// Maps an Open-Meteo numeric WMO weather code to a [RunCondition].
RunCondition conditionFromCode(int? code) {
  switch (code) {
    case 0:
    case 1:
      return RunCondition.clear;
    case 2:
    case 3:
      return RunCondition.cloudy;
    case 45:
    case 48:
      return RunCondition.fog;
    case 51:
    case 53:
    case 55:
    case 56:
    case 57:
      return RunCondition.drizzle;
    case 61:
    case 63:
    case 65:
    case 66:
    case 67:
    case 80:
    case 81:
    case 82:
      return RunCondition.rain;
    case 71:
    case 73:
    case 75:
    case 77:
    case 85:
    case 86:
      return RunCondition.snow;
    case 95:
    case 96:
    case 97:
    case 99:
      return RunCondition.thunderstorm;
    default:
      return RunCondition.unknown;
  }
}

/// Client to fetch historical or forecasted hourly weather from Open-Meteo.
class RunWeatherClient {
  RunWeatherClient(this.client);

  final http.Client client;

  Future<RunWeather?> fetch(Point point, int startedAtUtcMs) async {
    final started = DateTime.fromMillisecondsSinceEpoch(
      startedAtUtcMs,
      isUtc: true,
    );
    final age = DateTime.now().toUtc().difference(started);
    final recent = age >= Duration.zero && age <= const Duration(days: 2);
    final date = started.toIso8601String().substring(0, 10);

    final parameters = {
      'latitude': point.lat.toString(),
      'longitude': point.lon.toString(),
      'hourly': 'temperature_2m,wind_speed_10m,weather_code',
      'temperature_unit': 'celsius',
      'wind_speed_unit': 'kmh',
      'timeformat': 'unixtime',
      'timezone': 'GMT',
    };

    final uri = recent
        ? Uri.https('api.open-meteo.com', '/v1/forecast', {
            ...parameters,
            'past_days': '3',
            'forecast_days': '1',
          })
        : Uri.https('archive-api.open-meteo.com', '/v1/archive', {
            ...parameters,
            'start_date': date,
            'end_date': date,
          });

    try {
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final hourly = body['hourly'] as Map<String, dynamic>?;
      final times = hourly?['time'];
      if (hourly == null || times is! List || times.isEmpty) {
        return null;
      }

      var nearest = -1;
      var smallestGapMs = 1 << 62;

      for (var i = 0; i < times.length; i++) {
        final seconds = times[i];
        if (seconds is! num) continue;

        final gapMs = (seconds.toInt() * 1000 - startedAtUtcMs).abs();
        if (gapMs < smallestGapMs) {
          smallestGapMs = gapMs;
          nearest = i;
        }
      }

      if (nearest < 0 ||
          smallestGapMs > const Duration(hours: 1).inMilliseconds) {
        return null;
      }

      num? numberAt(String key) {
        final values = hourly[key];
        if (values is! List || nearest >= values.length) return null;
        final value = values[nearest];
        return value is num ? value : null;
      }

      final temperature = numberAt('temperature_2m');
      final wind = numberAt('wind_speed_10m');
      final code = numberAt('weather_code');
      if (temperature == null && wind == null && code == null) {
        return null;
      }

      return RunWeather(
        temperature?.toDouble(),
        wind?.toDouble(),
        code?.toInt(),
      );
    } catch (_) {
      // Weather is optional; a network error must not lose the run.
      return null;
    }
  }

  /// Alias for fetching weather at start location.
  Future<RunWeather?> getAtStart(Point point, int startedAtUtcMs) =>
      fetch(point, startedAtUtcMs);
}

/// Loads a saved run and its points, finds the first accepted point,
/// fetches weather once, and updates weather on the run.
///
/// If there is no accepted point or the network call fails, it returns
/// safely without modifying the run.
Future<void> enrichRunWeather(
  String runId, {
  required RunRepository repository,
  RunWeatherClient? weatherClient,
  http.Client? httpClient,
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

    if (startPoint == null) return;

    final client =
        weatherClient ?? RunWeatherClient(httpClient ?? http.Client());
    final weather = await client.fetch(startPoint, run.startedAtUtcMs);

    if (weather != null) {
      await repository.updateWeather(
        runId,
        temperatureC: weather.temperatureC,
        windKmh: weather.windKmh,
        weatherCode: weather.code,
      );
    }
  } catch (_) {
    // Weather is optional; network failure must not impact saved run.
  }
}

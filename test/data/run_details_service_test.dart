import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/data/run.dart';
import 'package:road_runner/data/run_details_service.dart';
import 'package:road_runner/data/run_name.dart';
import 'package:road_runner/features/summary/weather_description.dart';

void main() {
  test('run titles work offline and gain a cached place', () {
    final start = DateTime(2026, 11, 16, 8, 30).millisecondsSinceEpoch;
    expect(runName(start), 'Morning run');
    expect(runName(start, 'Parramatta'), 'Morning run in Parramatta');
    final saved = Run(
      id: 'r',
      startedAtUtcMs: start,
      endedAtUtcMs: start + 1000,
      movingMs: 1000,
      distanceM: 50,
      name: runName(start, 'Parramatta'),
      placeName: 'Parramatta',
      weatherTempC: 23.5,
      weatherWindKmh: 11.0,
      weatherCode: 2,
    );
    final reloaded = Run.fromDbMap(saved.toDbMap());
    expect(reloaded, saved);
    expect(reloaded.displayName, 'Morning run in Parramatta');
  });

  test('reverse geocoding selects a locality and identifies the app', () async {
    Uri? requested;
    Map<String, String>? requestHeaders;
    final service = RunDetailsService(
      loadJson: (uri, headers) async {
        requested = uri;
        requestHeaders = headers;
        return {
          'address': {'suburb': 'Parramatta', 'city': 'Sydney'},
        };
      },
    );
    expect(await service.lookupPlace(-33.815, 151.002), 'Parramatta');
    expect(requested!.host, 'nominatim.openstreetmap.org');
    expect(requested!.queryParameters['format'], 'jsonv2');
    expect(requestHeaders!['User-Agent'], contains('RoadRunner'));
  });

  test('historical weather selects the hour nearest the run start', () async {
    final start = DateTime.utc(2024, 11, 16, 10, 20);
    final firstHour =
        DateTime.utc(2024, 11, 16, 10).millisecondsSinceEpoch ~/ 1000;
    Uri? requested;
    final service = RunDetailsService(
      loadJson: (uri, headers) async {
        requested = uri;
        return {
          'hourly': {
            'time': [firstHour, firstHour + 3600],
            'temperature_2m': [23.5, 25.0],
            'wind_speed_10m': [11.0, 12.0],
            'weather_code': [2, 3],
          },
        };
      },
    );
    final weather = await service.lookupWeather(
      -33.815,
      151.002,
      start.millisecondsSinceEpoch,
    );
    expect(requested!.host, 'historical-forecast-api.open-meteo.com');
    expect(requested!.queryParameters['timezone'], 'UTC');
    expect(weather!.temperatureC, 23.5);
    expect(weather.windKmh, 11);
    expect(weatherDescription(weather.code), 'Partly cloudy');
  });

  test('weather lookup includes midnight when the run starts late', () async {
    final start = DateTime.utc(2024, 11, 16, 23, 40);
    final before =
        DateTime.utc(2024, 11, 16, 23).millisecondsSinceEpoch ~/ 1000;
    Uri? requested;
    final service = RunDetailsService(
      loadJson: (uri, headers) async {
        requested = uri;
        return {
          'hourly': {
            'time': [before, before + 3600],
            'temperature_2m': [20, 18],
            'wind_speed_10m': [8, 9],
            'weather_code': [1, 2],
          },
        };
      },
    );
    final weather = await service.lookupWeather(
      0,
      0,
      start.millisecondsSinceEpoch,
    );
    expect(requested!.queryParameters['end_date'], '2024-11-17');
    expect(weather!.temperatureC, 18);
  });
}

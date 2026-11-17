import 'dart:convert';

import 'package:http/http.dart' as http;

import 'run_weather_client.dart';

class HourlyWeather {
  const HourlyWeather({
    required this.time,
    required this.temperatureC,
    required this.code,
    required this.rainChancePercent,
  });

  final DateTime time;
  final double? temperatureC;
  final int? code;
  final int? rainChancePercent;
}

class LocalForecast {
  const LocalForecast({required this.current, required this.nextHours});

  final RunWeather? current;
  final List<HourlyWeather> nextHours;
}

/// Current conditions at a known route location, from Open-Meteo.
class CurrentWeatherClient {
  const CurrentWeatherClient();

  /// Current conditions and the next three hourly forecasts near the device.
  Future<LocalForecast?> fetchForecast(
    double latitude,
    double longitude,
  ) async {
    if (latitude.abs() > 90 || longitude.abs() > 180) return null;
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current': 'temperature_2m,wind_speed_10m,weather_code',
        'hourly': 'temperature_2m,precipitation_probability,weather_code',
        'forecast_hours': '5',
        'timeformat': 'unixtime',
        'temperature_unit': 'celsius',
        'wind_speed_unit': 'kmh',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      return parseForecast(jsonDecode(response.body), now: DateTime.now());
    } catch (_) {
      return null;
    }
  }

  static LocalForecast? parseForecast(Object? data, {required DateTime now}) {
    if (data is! Map<String, dynamic>) return null;
    final currentData = data['current'];
    final RunWeather? current = currentData is Map<String, dynamic>
        ? RunWeather(
            (currentData['temperature_2m'] as num?)?.toDouble(),
            (currentData['wind_speed_10m'] as num?)?.toDouble(),
            (currentData['weather_code'] as num?)?.toInt(),
          )
        : null;
    final hourly = data['hourly'];
    final hours = <HourlyWeather>[];
    if (hourly is Map<String, dynamic>) {
      final times = hourly['time'];
      final temperatures = hourly['temperature_2m'];
      final codes = hourly['weather_code'];
      final rainChances = hourly['precipitation_probability'];
      if (times is List &&
          temperatures is List &&
          codes is List &&
          rainChances is List) {
        final length = [
          times.length,
          temperatures.length,
          codes.length,
          rainChances.length,
        ].reduce((a, b) => a < b ? a : b);
        for (var i = 0; i < length && hours.length < 3; i++) {
          final timestamp = times[i];
          if (timestamp is! num) continue;
          final time = DateTime.fromMillisecondsSinceEpoch(
            timestamp.toInt() * 1000,
          );
          if (!time.isAfter(now)) continue;
          hours.add(
            HourlyWeather(
              time: time,
              temperatureC: (temperatures[i] as num?)?.toDouble(),
              code: (codes[i] as num?)?.toInt(),
              rainChancePercent: (rainChances[i] as num?)?.toInt(),
            ),
          );
        }
      }
    }
    if (current == null && hours.isEmpty) return null;
    return LocalForecast(current: current, nextHours: List.unmodifiable(hours));
  }

  Future<RunWeather?> fetch(double latitude, double longitude) async {
    if (latitude.abs() > 90 || longitude.abs() > 180) return null;
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current': 'temperature_2m,wind_speed_10m,weather_code',
        'temperature_unit': 'celsius',
        'wind_speed_unit': 'kmh',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final current =
          (jsonDecode(response.body) as Map<String, dynamic>)['current'];
      if (current is! Map<String, dynamic>) return null;
      return RunWeather(
        (current['temperature_2m'] as num?)?.toDouble(),
        (current['wind_speed_10m'] as num?)?.toDouble(),
        (current['weather_code'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}

String weatherDescription(RunWeather? weather) =>
    switch (conditionFromCode(weather?.code)) {
      RunCondition.clear => 'Clear skies',
      RunCondition.cloudy => 'Cloudy',
      RunCondition.fog => 'Foggy',
      RunCondition.drizzle => 'Drizzle',
      RunCondition.rain => 'Rain',
      RunCondition.snow => 'Snow',
      RunCondition.thunderstorm => 'Storms',
      RunCondition.unknown => 'Conditions unavailable',
    };

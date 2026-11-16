import 'dart:convert';

import 'package:http/http.dart' as http;

import 'run_weather_client.dart';

/// Current conditions at a known route location, from Open-Meteo.
class CurrentWeatherClient {
  const CurrentWeatherClient();

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

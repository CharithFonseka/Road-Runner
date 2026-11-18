import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/data/current_weather_client.dart';

void main() {
  test('parses the next three hours and skips the current hour', () {
    final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
    final currentSecond = now.millisecondsSinceEpoch ~/ 1000;
    final forecast = CurrentWeatherClient.parseForecast({
      'current': {'temperature_2m': 28, 'wind_speed_10m': 8, 'weather_code': 2},
      'hourly': {
        'time': [
          currentSecond - 3600,
          currentSecond,
          currentSecond + 3600,
          currentSecond + 7200,
          currentSecond + 10800,
        ],
        'temperature_2m': [27, 28, 29, 30, 29],
        'weather_code': [1, 2, 2, 3, 61],
        'precipitation_probability': [5, 10, 10, 20, 45],
      },
    }, now: now);

    expect(forecast?.current?.temperatureC, 28);
    expect(forecast?.nextHours, hasLength(3));
    expect(forecast?.nextHours.first.temperatureC, 29);
    expect(forecast?.nextHours.last.code, 61);
    expect(forecast?.nextHours.last.rainChancePercent, 45);
  });

  test('does not show a forecast for malformed data', () {
    expect(CurrentWeatherClient.parseForecast({}, now: DateTime.now()), isNull);
  });
}

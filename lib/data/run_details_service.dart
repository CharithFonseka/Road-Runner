import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef JsonLoader = Future<Map<String, dynamic>> Function(
  Uri uri,
  Map<String, String> headers,
);

class RunWeather {
  const RunWeather({
    required this.temperatureC,
    required this.windKmh,
    required this.code,
  });

  final double temperatureC;
  final double windKmh;
  final int code;
}

/// One request per missing run detail, never called from the tracking loop.
class RunDetailsService {
  RunDetailsService({
    JsonLoader? loadJson,
    Uri? placeEndpoint,
    Uri? recentWeatherEndpoint,
    Uri? historicalWeatherEndpoint,
  }) : _loadJson = loadJson ?? _httpGetJson,
       _placeEndpoint =
           placeEndpoint ??
           Uri.parse('https://nominatim.openstreetmap.org/reverse'),
       _recentWeatherEndpoint =
           recentWeatherEndpoint ??
           Uri.parse('https://api.open-meteo.com/v1/forecast'),
       _historicalWeatherEndpoint =
           historicalWeatherEndpoint ??
           Uri.parse(
             'https://historical-forecast-api.open-meteo.com/v1/forecast',
           );

  final JsonLoader _loadJson;
  final Uri _placeEndpoint;
  final Uri _recentWeatherEndpoint;
  final Uri _historicalWeatherEndpoint;

  static Future<void> _placeQueue = Future<void>.value();
  static DateTime? _lastPlaceRequest;

  Future<String?> lookupPlace(double lat, double lon) async {
    // The public Nominatim service allows at most one request per second.
    final previous = _placeQueue;
    final done = Completer<void>();
    _placeQueue = done.future;
    await previous;
    try {
      final last = _lastPlaceRequest;
      if (last != null) {
        final remaining =
            const Duration(seconds: 1) - DateTime.now().difference(last);
        if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      }
      _lastPlaceRequest = DateTime.now();
      final uri = _placeEndpoint.replace(
        queryParameters: {
          'lat': lat.toString(),
          'lon': lon.toString(),
          'format': 'jsonv2',
          'addressdetails': '1',
          'zoom': '14',
        },
      );
      final data = await _loadJson(uri, {
        'User-Agent': 'RoadRunner/0.1 (https://github.com/praveen-madawalage/Road-Runner)',
        'Accept': 'application/json',
      });
      final address = data['address'];
      if (address is! Map) return null;
      for (final key in [
        'suburb',
        'city_district',
        'town',
        'village',
        'city',
        'municipality',
        'county',
      ]) {
        final value = address[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return null;
    } finally {
      done.complete();
    }
  }

  Future<RunWeather?> lookupWeather(
    double lat,
    double lon,
    int startedAtUtcMs,
  ) async {
    final started = DateTime.fromMillisecondsSinceEpoch(
      startedAtUtcMs,
      isUtc: true,
    );
    final recent =
        DateTime.now().toUtc().difference(started) < const Duration(days: 2);
    String date(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    final uri = (recent ? _recentWeatherEndpoint : _historicalWeatherEndpoint)
        .replace(
          queryParameters: {
            'latitude': lat.toString(),
            'longitude': lon.toString(),
            'start_date': date(started),
            // The nearest hour may be midnight on the following UTC day.
            'end_date': date(started.add(const Duration(days: 1))),
            'hourly': 'temperature_2m,wind_speed_10m,weather_code',
            'timezone': 'UTC',
            'timeformat': 'unixtime',
            'wind_speed_unit': 'kmh',
            'temperature_unit': 'celsius',
          },
        );
    final data = await _loadJson(uri, {'Accept': 'application/json'});
    final hourly = data['hourly'];
    if (hourly is! Map) return null;
    final times = hourly['time'];
    final temperatures = hourly['temperature_2m'];
    final winds = hourly['wind_speed_10m'];
    final codes = hourly['weather_code'];
    if (times is! List ||
        temperatures is! List ||
        winds is! List ||
        codes is! List) {
      return null;
    }
    int? closest;
    int? smallestDifference;
    for (var i = 0; i < times.length; i++) {
      final t = times[i];
      if (t is! num) continue;
      final difference = (t.toInt() * 1000 - startedAtUtcMs).abs();
      if (smallestDifference == null || difference < smallestDifference) {
        smallestDifference = difference;
        closest = i;
      }
    }
    if (closest == null ||
        smallestDifference! > const Duration(minutes: 31).inMilliseconds ||
        closest >= temperatures.length ||
        closest >= winds.length ||
        closest >= codes.length) {
      return null;
    }
    final temperature = temperatures[closest];
    final wind = winds[closest];
    final code = codes[closest];
    if (temperature is! num || wind is! num || code is! num) return null;
    if (!temperature.toDouble().isFinite || !wind.toDouble().isFinite) {
      return null;
    }
    return RunWeather(
      temperatureC: temperature.toDouble(),
      windKmh: wind.toDouble(),
      code: code.toInt(),
    );
  }

  static Future<Map<String, dynamic>> _httpGetJson(
    Uri uri,
    Map<String, String> headers,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 6));
      headers.forEach(request.headers.set);
      final response = await request.close().timeout(
        const Duration(seconds: 6),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 6));
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object');
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }
}

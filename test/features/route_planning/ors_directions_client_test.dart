import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:road_runner/features/route_planning/ors_directions_client.dart';

void main() {
  test('sends longitude-latitude pairs and parses walking GeoJSON', () async {
    final client = OrsDirectionsClient(
      apiKey: 'test-key',
      post: (uri, key, body) async {
        expect(uri, OrsDirectionsClient.endpoint);
        expect(uri.host, 'api.heigit.org');
        expect(key, 'test-key');
        expect(body['coordinates'], [
          [79.8612, 6.9271],
          [79.864, 6.93],
        ]);
        return {
          'features': [
            {
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  [79.8612, 6.9271],
                  [79.862, 6.928],
                  [79.864, 6.93],
                ],
              },
            },
          ],
        };
      },
    );

    final points = await client.walkingRoute(
      const LatLng(6.9271, 79.8612),
      const LatLng(6.93, 79.864),
    );
    expect(points, hasLength(3));
    expect(points.first.lat, 6.9271);
    expect(points.first.lon, 79.8612);
    expect(points.last.lat, 6.93);
    expect(points.last.lon, 79.864);
    expect(() => points.clear(), throwsUnsupportedError);
  });

  test('rejects a missing key without making a request', () async {
    final client = OrsDirectionsClient(
      apiKey: '',
      post: (_, _, _) => throw StateError('Request should not be sent'),
    );
    expect(
      client.walkingRoute(const LatLng(1, 2), const LatLng(3, 4)),
      throwsStateError,
    );
  });

  test('rejects malformed and degenerate route geometry', () async {
    final client = OrsDirectionsClient(
      apiKey: 'test-key',
      post: (_, _, _) async => {
        'features': [
          {
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [79.0, 7.0],
                [79.0, 7.0],
              ],
            },
          },
        ],
      },
    );
    expect(
      client.walkingRoute(const LatLng(7, 79), const LatLng(8, 80)),
      throwsFormatException,
    );
  });
}

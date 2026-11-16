import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:road_runner/data/planned_route.dart';
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

  test('uses free OSRM foot routing when no ORS API key is set', () async {
    final client = OrsDirectionsClient(
      apiKey: '',
      post: (_, _, _) => throw StateError('ORS should not be called'),
      fetchOsrm: (uri) async {
        expect(uri.host, 'routing.openstreetmap.de');
        expect(
          uri.path,
          '/routed-foot/route/v1/driving/79.8612,6.9271;79.864,6.93',
        );
        expect(uri.queryParameters['overview'], 'full');
        expect(uri.queryParameters['geometries'], 'geojson');
        return {
          'routes': [
            {
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  [79.8612, 6.9271],
                  [79.8625, 6.9282],
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
    expect(points[1].lat, 6.9282);
    expect(points[1].lon, 79.8625);
  });

  test(
    'cycling uses the bicycle profile, while running uses pedestrian paths',
    () async {
      final requested = <Uri>[];
      final client = OrsDirectionsClient(
        fetchOsrm: (uri) async {
          requested.add(uri);
          return {
            'routes': [
              {
                'geometry': {
                  'type': 'LineString',
                  'coordinates': [
                    [79.8612, 6.9271],
                    [79.864, 6.93],
                  ],
                },
              },
            ],
          };
        },
      );
      const start = LatLng(6.9271, 79.8612);
      const end = LatLng(6.93, 79.864);
      await client.route(start, end, activity: RouteActivity.run);
      await client.route(start, end, activity: RouteActivity.cycle);
      expect(requested[0].path, startsWith('/routed-foot/'));
      expect(requested[1].path, startsWith('/routed-bike/'));
      expect(
        OrsDirectionsClient.endpointFor(RouteActivity.cycle).path,
        contains('/cycling-regular/geojson'),
      );
    },
  );

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

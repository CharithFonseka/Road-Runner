import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:road_runner/features/route_planning/place_search_client.dart';

void main() {
  test('builds Photon URI with optional bias center and parses results', () async {
    final client = PlaceSearchClient(
      fetch: (uri) async {
        expect(uri.host, 'photon.komoot.io');
        expect(uri.path, '/api/');
        expect(uri.queryParameters['q'], 'Viharamahadevi');
        expect(uri.queryParameters['lat'], '6.92710');
        expect(uri.queryParameters['lon'], '79.86120');
        return {
          'features': [
            {
              'geometry': {
                'type': 'Point',
                'coordinates': [79.8617, 6.9147],
              },
              'properties': {
                'name': 'Viharamahadevi Park',
                'street': 'Ananda Coomaraswamy Mawatha',
                'city': 'Colombo',
                'country': 'Sri Lanka',
              },
            },
            {
              'geometry': {
                'type': 'Point',
                'coordinates': [999, 6.9147],
              },
              'properties': {'name': 'Invalid place'},
            },
          ],
        };
      },
    );

    final results = await client.search(
      ' Viharamahadevi ',
      biasCenter: const LatLng(6.9271, 79.8612),
    );
    expect(results, hasLength(1));
    expect(results.first.name, 'Viharamahadevi Park');
    expect(
      results.first.subtitle,
      'Ananda Coomaraswamy Mawatha, Colombo, Sri Lanka',
    );
    expect(results.first.location.latitude, 6.9147);
    expect(results.first.location.longitude, 79.8617);
  });

  test('ignores short queries without making a network request', () async {
    final client = PlaceSearchClient(
      fetch: (_) => throw StateError('Should not fetch'),
    );
    expect(await client.search('a'), isEmpty);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/bridge/tracking_bridge.dart';

void main() {
  test('live snapshot keeps optional accepted coordinates', () {
    final snapshot = TrackingSnapshot.fromMap({
      'elapsedMs': 1000,
      'movingMs': 1000,
      'distanceM': 4.0,
      'speedMps': 4.0,
      'paceSecPerKm': 250.0,
      'lat': -33.8688,
      'lon': 151.2093,
      'seq': 3,
    });
    expect(snapshot.lat, -33.8688);
    expect(snapshot.lon, 151.2093);
    expect(snapshot.seq, 3);
    expect(TrackingSnapshot.fromMap(snapshot.toMap()), snapshot);
  });

  test('accepted point events validate coordinate ranges', () {
    final event = TrackingEvent.fromMap({
      'type': 'point',
      'seq': 5,
      'lat': -33.8688,
      'lon': 151.2093,
    });
    expect(event, isA<TrackingPointEvent>());
    expect((event as TrackingPointEvent).point.seq, 5);
    expect(
      TrackingEvent.fromMap({'type': 'point', 'seq': 6, 'lat': 95, 'lon': 151}),
      isNull,
    );
  });
}

// Road Runner — Unit Tests for Haversine Distance (Pure Dart)
// Owner: Nadeesha
// SRS reference: Section 4.6, 4.7, 8.5

import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/contract/contract.dart';
import 'package:road_runner/domain/stats/haversine.dart';

void main() {
  group('Haversine Distance Tests (SRS §4.7)', () {
    test('same point returns zero distance', () {
      expect(haversineM(6.9271, 79.8612, 6.9271, 79.8612), 0.0);
      expect(haversineM(0.0, 0.0, 0.0, 0.0), 0.0);
    });

    test('distance is symmetric regardless of point order', () {
      const lat1 = 6.9271;
      const lon1 = 79.8612;
      const lat2 = 7.2906;
      const lon2 = 80.6337;

      final d1 = haversineM(lat1, lon1, lat2, lon2);
      final d2 = haversineM(lat2, lon2, lat1, lon1);

      expect(d1, closeTo(d2, 1e-6));
    });

    test('one degree along equator matches theoretical distance with Earth radius', () {
      // Circumference = 2 * pi * R
      // 1 degree = (2 * pi * 6371000) / 360 ≈ 111194.9266 m
      final expectedM =
          (2 * 3.141592653589793 * FilterConfig.earthRadiusM) / 360.0;
      final actualM = haversineM(0.0, 0.0, 0.0, 1.0);

      expect(actualM, closeTo(expectedM, 0.01));
    });

    test('calculates accurate distance between known city benchmarks (Colombo to Kandy)', () {
      // Colombo: 6.9271, 79.8612
      // Kandy: 7.2906, 80.6337
      // Great circle distance is ~94.0 km (94,000 m ± 500 m)
      final distanceM = haversineM(6.9271, 79.8612, 7.2906, 80.6337);

      expect(distanceM, greaterThan(93500.0));
      expect(distanceM, lessThan(94500.0));
    });

    test('small GPS movements are measured smoothly in meters', () {
      // Move approximately 10 meters north
      // 10 meters / 111195 m/deg ≈ 0.0000899 degrees
      final d = haversineM(6.9271, 79.8612, 6.9271899, 79.8612);

      expect(d, closeTo(10.0, 0.1));
    });
  });
}

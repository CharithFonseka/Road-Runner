// Road Runner — Unit Tests for Running Statistics Formatters (Pure Dart)
// Owner: Nadeesha
// SRS reference: Section 4.7, 8.5

import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/domain/stats/formatting.dart';

void main() {
  group('formatDistance Tests (SRS §4.7)', () {
    test('formats standard distances in kilometers with 2 decimal places', () {
      expect(formatDistance(1000.0), '1.00 km');
      expect(formatDistance(5240.0), '5.24 km');
      expect(formatDistance(50.0), '0.05 km');
      expect(formatDistance(9.0), '0.01 km');
      expect(formatDistance(10500.0), '10.50 km');
    });

    test('handles zero and boundary values', () {
      expect(formatDistance(0.0), '0.00 km');
      expect(formatDistance(0.4), '0.00 km');
    });

    test('clamps negative and invalid distances gracefully to 0.00 km', () {
      expect(formatDistance(-500.0), '0.00 km');
      expect(formatDistance(double.nan), '0.00 km');
      expect(formatDistance(double.infinity), '0.00 km');
      expect(formatDistance(double.negativeInfinity), '0.00 km');
    });
  });

  group('formatPace Tests (SRS §4.7)', () {
    test('formats valid pace into m:ss correctly', () {
      expect(formatPace(330.0), '5:30');
      expect(formatPace(305.0), '5:05'); // checks zero-padding of seconds
      expect(formatPace(300.0), '5:00');
      expect(formatPace(59.0), '0:59');
      expect(formatPace(60.0), '1:00');
      expect(formatPace(65.0), '1:05');
      expect(formatPace(599.0), '9:59');
    });

    test('handles rounding of fractional seconds', () {
      expect(formatPace(330.4), '5:30');
      expect(formatPace(330.6), '5:31');
    });

    test('respects max pace threshold (1200 s/km = 20 min/km)', () {
      expect(formatPace(1200.0), '20:00');
      expect(formatPace(1200.4), '20:00');
      expect(formatPace(1201.0), '--:--');
      expect(formatPace(1500.0), '--:--');
    });

    test('returns --:-- for null, non-positive, or invalid values', () {
      expect(formatPace(null), '--:--');
      expect(formatPace(0.0), '--:--');
      expect(formatPace(-10.0), '--:--');
      expect(formatPace(double.nan), '--:--');
      expect(formatPace(double.infinity), '--:--');
      expect(formatPace(double.negativeInfinity), '--:--');
    });
  });

  group('formatSpeed Tests (SRS §4.7)', () {
    test('converts meters per second to km/h with 1 decimal place', () {
      // 1 m/s = 3.6 km/h
      expect(formatSpeed(1.0), '3.6 km/h');
      // 2.78 m/s * 3.6 = 10.008 -> 10.0 km/h
      expect(formatSpeed(2.78), '10.0 km/h');
      // 5.0 m/s * 3.6 = 18.0 km/h
      expect(formatSpeed(5.0), '18.0 km/h');
    });

    test('handles zero speed', () {
      expect(formatSpeed(0.0), '0.0 km/h');
    });

    test('returns --.- for null, negative, or invalid speeds', () {
      expect(formatSpeed(null), '--.-');
      expect(formatSpeed(-1.0), '--.-');
      expect(formatSpeed(double.nan), '--.-');
      expect(formatSpeed(double.infinity), '--.-');
      expect(formatSpeed(double.negativeInfinity), '--.-');
    });
  });
}

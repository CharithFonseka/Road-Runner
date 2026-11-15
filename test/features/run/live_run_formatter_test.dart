// Road Runner — LiveRunFormatter tests (display conversion only).
// Owner: Tharushi

import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/contract/contract.dart';
import 'package:road_runner/features/run/live_run_formatter.dart';

void main() {
  const LiveRunFormatter f = LiveRunFormatter();

  group('elapsed', () {
    test('placeholder when missing or negative', () {
      expect(f.elapsed(null), LiveRunFormatter.elapsedPlaceholder);
      expect(f.elapsed(-1), LiveRunFormatter.elapsedPlaceholder);
    });

    test('m:ss under one hour, truncating partial seconds', () {
      expect(f.elapsed(0), '0:00');
      expect(f.elapsed(999), '0:00');
      expect(f.elapsed(65 * 1000), '1:05');
      expect(f.elapsed((59 * 60 + 59) * 1000 + 999), '59:59');
    });

    test('h:mm:ss from one hour', () {
      expect(f.elapsed(3600 * 1000), '1:00:00');
      expect(f.elapsed((3600 + 2 * 60 + 3) * 1000), '1:02:03');
    });
  });

  group('distanceKm', () {
    test('metres to km with two decimals', () {
      expect(f.distanceKm(0), '0.00');
      expect(f.distanceKm(3420), '3.42');
      expect(f.distanceKm(12345), '12.35');
    });

    test('placeholder for missing or invalid values', () {
      expect(f.distanceKm(null), LiveRunFormatter.distancePlaceholder);
      expect(f.distanceKm(-5), LiveRunFormatter.distancePlaceholder);
      expect(f.distanceKm(double.nan), LiveRunFormatter.distancePlaceholder);
    });
  });

  group('speedKmh', () {
    test('m/s to km/h with one decimal', () {
      expect(f.speedKmh(0), '0.0');
      expect(f.speedKmh(3.0), '10.8');
      expect(f.speedKmh(2.5), '9.0');
    });

    test('placeholder for missing or invalid values', () {
      expect(f.speedKmh(null), LiveRunFormatter.speedPlaceholder);
      expect(f.speedKmh(-1), LiveRunFormatter.speedPlaceholder);
      expect(f.speedKmh(double.infinity), LiveRunFormatter.speedPlaceholder);
    });
  });

  group('pace', () {
    test('seconds per km to m:ss, rounding to the nearest second', () {
      expect(f.pace(327), '5:27');
      expect(f.pace(327.4), '5:27');
      expect(f.pace(359.6), '6:00');
      expect(f.pace(60), '1:00');
    });

    test('unavailable pace shows --:--', () {
      expect(f.pace(null), '--:--');
      expect(f.pace(0), '--:--');
      expect(f.pace(-3), '--:--');
      expect(f.pace(double.nan), '--:--');
      expect(f.pace(double.infinity), '--:--');
    });

    test('slower than the contract maximum shows --:--', () {
      expect(f.pace(CalcConfig.maxPaceSecPerKm.toDouble()), '20:00');
      expect(f.pace(CalcConfig.maxPaceSecPerKm + 1.0), '--:--');
    });
  });
}

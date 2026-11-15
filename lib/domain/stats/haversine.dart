// Road Runner — Haversine Distance Calculation (Pure Dart)
// Owner: Nadeesha
// SRS reference: Section 4.6, 4.7, 8.5

import 'dart:math' as math;
import 'package:road_runner/core/contract/contract.dart';

/// Calculates the great-circle distance between two GPS coordinates in meters
/// using the Haversine formula and the earth radius specified in [FilterConfig.earthRadiusM].
///
/// Both [lat1], [lon1] and [lat2], [lon2] are given in degrees.
/// Returns distance in meters.
double haversineM(double lat1, double lon1, double lat2, double lon2) {
  if (lat1 == lat2 && lon1 == lon2) {
    return 0.0;
  }

  final double dLat = _degreesToRadians(lat2 - lat1);
  final double dLon = _degreesToRadians(lon2 - lon1);

  final double lat1Rad = _degreesToRadians(lat1);
  final double lat2Rad = _degreesToRadians(lat2);

  final double a = math.sin(dLat / 2.0) * math.sin(dLat / 2.0) +
      math.cos(lat1Rad) *
          math.cos(lat2Rad) *
          math.sin(dLon / 2.0) *
          math.sin(dLon / 2.0);

  // Clamp to [0.0, 1.0] to protect against floating point precision issues
  final double clampedA = a.clamp(0.0, 1.0);
  final double c =
      2.0 * math.atan2(math.sqrt(clampedA), math.sqrt(1.0 - clampedA));

  return FilterConfig.earthRadiusM * c;
}

double _degreesToRadians(double degrees) {
  return degrees * (math.pi / 180.0);
}

// Road Runner — Running Statistics Formatters (Pure Dart)
// Owner: Nadeesha
// SRS reference: Section 4.7, 8.5

import 'package:road_runner/core/contract/contract.dart';

/// Formats a pace in seconds per kilometer to 'm:ss' (e.g. '5:30' or '5:05').
///
/// Returns '--:--' if [secPerKm] is null, non-positive, not finite,
/// or exceeds [CalcConfig.maxPaceSecPerKm] (20 min/km = 1200 s/km).
String formatPace(double? secPerKm) {
  if (secPerKm == null ||
      secPerKm.isNaN ||
      secPerKm.isInfinite ||
      secPerKm <= 0.0) {
    return '--:--';
  }

  final int totalSeconds = secPerKm.round();
  if (totalSeconds > CalcConfig.maxPaceSecPerKm.toInt()) {
    return '--:--';
  }

  final int minutes = totalSeconds ~/ 60;
  final int seconds = totalSeconds % 60;

  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Formats a distance in meters to kilometers with two decimal places (e.g. '5.24 km').
///
/// Negative or invalid distances are clamped to '0.00 km'.
String formatDistance(double meters) {
  if (meters.isNaN || meters.isInfinite || meters <= 0.0) {
    return '0.00 km';
  }

  final double km = meters / 1000.0;
  return '${km.toStringAsFixed(2)} km';
}

/// Formats a speed in meters per second (mps) to 'x.x km/h' (e.g. '10.0 km/h').
///
/// Returns '--.-' if [mps] is null, negative, or not finite.
String formatSpeed(double? mps) {
  if (mps == null || mps.isNaN || mps.isInfinite || mps < 0.0) {
    return '--.-';
  }

  final double kmh = mps * 3.6;
  return '${kmh.toStringAsFixed(1)} km/h';
}

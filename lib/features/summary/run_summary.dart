// Road Runner — Run Summary presentation model.
// Owner: Tharushi
// SRS reference: Section 4.7, 8.4, 8.5, FR-50–52
//
// Immutable, injected data for the Summary screen. Every value here must
// come from the data/stats layer (Nadeesha) via the repository (Praveen).
// The screen only formats and draws it; it never computes distance, pace,
// speed, splits or the fastest split.
//
// See lib/features/summary/README.md for how each field maps to the
// planned RunRepository / stats functions and which ones are missing.

import 'package:flutter/foundation.dart';

/// One accepted GPS point of the route, in drawing order.
@immutable
class RoutePoint {
  const RoutePoint({required this.lat, required this.lon, this.speedMps});

  /// Degrees, WGS84.
  final double lat;
  final double lon;

  /// Speed reported for this point (m/s), or null if not recorded.
  final double? speedMps;
}

/// One full kilometre split as produced by the stats layer.
@immutable
class SplitSummary {
  const SplitSummary({
    required this.km,
    required this.durationMs,
    this.isFastest = false,
  });

  /// 1-based kilometre number.
  final int km;

  /// Time taken for this kilometre (interpolated km-mark times).
  final int durationMs;

  /// Set by the stats layer. The screen highlights it; it does not decide.
  final bool isFastest;
}

/// The final, shorter-than-1 km piece of a run (`Split.isPartial` from the
/// stats layer). Shown after the full splits; never marked as fastest.
@immutable
class PartialSplitSummary {
  const PartialSplitSummary({
    required this.distanceM,
    required this.durationMs,
  });

  /// Distance covered in the partial split, in metres (under 1000).
  final double distanceM;

  /// Time taken for it.
  final int durationMs;
}

/// Everything the Summary screen shows for one completed run.
@immutable
class RunSummary {
  const RunSummary({
    required this.runId,
    this.startedAt,
    this.distanceM,
    this.movingMs,
    this.averagePaceSecPerKm,
    this.averageSpeedMps,
    this.route = const [],
    this.splits = const [],
    this.partialSplit,
  });

  final String runId;

  /// Start of the run. Shown in the phone's local time.
  final DateTime? startedAt;

  final double? distanceM;
  final int? movingMs;
  final double? averagePaceSecPerKm;
  final double? averageSpeedMps;

  /// Accepted points only, in sequence order.
  final List<RoutePoint> route;

  /// Full kilometre splits, in order. Empty for runs under 1 km.
  final List<SplitSummary> splits;

  /// Optional final partial split. Null hides the row.
  final PartialSplitSummary? partialSplit;
}

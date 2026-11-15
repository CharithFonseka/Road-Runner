// Road Runner — Home presentation model for the "Last Run" card.
// Owner: Tharushi
// SRS reference: Section 8.4, FR-71
//
// Holds text that is ALREADY formatted for display (e.g. "5.02 km",
// "32:15", "6:25/km"). Home never computes or formats statistics itself
// (lib/features/README.md rule). The app flow builds this from the run
// repository and the stats formatters once those exist.

import 'package:flutter/foundation.dart';

/// Display values for the most recent saved run, shown on Home.
@immutable
class LastRunSummary {
  const LastRunSummary({
    required this.dateLabel,
    required this.distance,
    required this.duration,
    required this.averagePace,
  });

  /// When the run happened, e.g. "Yesterday" or "14 Nov 2026".
  final String dateLabel;

  /// Total distance, e.g. "5.02 km".
  final String distance;

  /// Moving time, e.g. "32:15".
  final String duration;

  /// Average pace, e.g. "6:25/km" or "--:--".
  final String averagePace;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LastRunSummary &&
          dateLabel == other.dateLabel &&
          distance == other.distance &&
          duration == other.duration &&
          averagePace == other.averagePace;

  @override
  int get hashCode => Object.hash(dateLabel, distance, duration, averagePace);
}

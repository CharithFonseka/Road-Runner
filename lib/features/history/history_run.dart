// Road Runner — History list presentation model.
// Owner: Tharushi
// SRS reference: Section 8.4, 8.5, FR-61
//
// One saved run as the History list shows it. Values come from the run
// repository (Nadeesha) via the app flow (Praveen); the screen only formats
// them. Raw units are kept so the official stats formatters can replace the
// temporary one without changing this model.

import 'package:flutter/foundation.dart';

@immutable
class HistoryRun {
  const HistoryRun({
    required this.runId,
    required this.startedAt,
    this.distanceM,
    this.movingMs,
    this.averagePaceSecPerKm,
  });

  /// Repository run ID, passed back on tap so the parent can open Summary.
  final String runId;

  /// Start of the run (from runs.started_at_utc_ms). Used for newest-first
  /// order and shown in the phone's local time.
  final DateTime startedAt;

  final double? distanceM;
  final int? movingMs;
  final double? averagePaceSecPerKm;
}

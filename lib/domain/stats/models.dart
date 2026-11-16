
// Road Runner — Domain Models for Statistics and Storage (Pure Dart)
// Owner: Nadeesha
// SRS reference: Section 4.4, 4.7, 8.5

import 'package:road_runner/core/contract/contract.dart';

/// Represents a single recorded GPS fix from the native run file or SQLite database.
class Point {
  final int seq;
  final int tUtcMs;
  final double lat;
  final double lon;
  final double accM;
  final double? speedMps;
  final double? altM;
  final bool accepted;

  const Point({
    this.seq = 0,
    required this.tUtcMs,
    required this.lat,
    required this.lon,
    this.accM = 0.0,
    this.speedMps,
    this.altM,
    this.accepted = true,
  });

  /// Factory to parse from SQLite row map (`run_points` table).
  factory Point.fromDbMap(Map<String, dynamic> map) {
    return Point(
      seq: (map['seq'] as num?)?.toInt() ?? 0,
      tUtcMs: (map['t_utc_ms'] as num?)?.toInt() ?? 0,
      lat: (map['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (map['lon'] as num?)?.toDouble() ?? 0.0,
      accM: (map['acc_m'] as num?)?.toDouble() ?? 0.0,
      speedMps: (map['speed_mps'] as num?)?.toDouble(),
      altM: (map['alt_m'] as num?)?.toDouble(),
      accepted: (map['accepted'] is bool)
          ? map['accepted'] as bool
          : ((map['accepted'] as num?)?.toInt() ?? 0) == 1,
    );
  }

  /// Converts to SQLite row map for database insertion.
  Map<String, dynamic> toDbMap(String runId) {
    return {
      'run_id': runId,
      'seq': seq,
      't_utc_ms': tUtcMs,
      'lat': lat,
      'lon': lon,
      'acc_m': accM,
      'speed_mps': speedMps,
      'alt_m': altM,
      'accepted': accepted ? 1 : 0,
    };
  }

  /// Factory to parse a v1 JSONL point line (`k: "p"`).
  factory Point.fromJsonl(Map<String, dynamic> map) {
    final ok = map[kRunFileKeyAccepted];

    return Point(
      seq: (map[kRunFileKeySeq] as num?)?.toInt() ?? 0,
      tUtcMs: (map[kRunFileKeyTime] as num?)?.toInt() ?? 0,
      lat: (map[kRunFileKeyLat] as num?)?.toDouble() ?? 0.0,
      lon: (map[kRunFileKeyLon] as num?)?.toDouble() ?? 0.0,
      accM: (map[kRunFileKeyAcc] as num?)?.toDouble() ?? 0.0,
      speedMps: (map[kRunFileKeySpeed] as num?)?.toDouble(),
      altM: (map[kRunFileKeyAlt] as num?)?.toDouble(),
      accepted: ok == true || ok == 1,
    );
  }
}

/// Represents a period when the workout was paused.
class PauseInterval {
  final int startMs;
  final int endMs;

  const PauseInterval({
    required this.startMs,
    required this.endMs,
  });

  int get durationMs => endMs > startMs ? endMs - startMs : 0;
}

/// Represents a 1-kilometer split interval or a final partial split.
class Split {
  final int kmIndex;
  final int durationMs;
  final double distanceM;
  final bool isPartial;

  const Split({
    required this.kmIndex,
    required this.durationMs,
    required this.distanceM,
    this.isPartial = false,
  });

  Map<String, dynamic> toJson() => {
        'km_index': kmIndex,
        'duration_ms': durationMs,
        'is_partial': isPartial,
      };

  factory Split.fromJson(Map<String, dynamic> json) => Split(
        kmIndex: (json['km_index'] as num).toInt(),
        durationMs: (json['duration_ms'] as num).toInt(),
        distanceM: (json['distance_m'] as num?)?.toDouble() ??
            (json['is_partial'] == true ? 0.0 : 1000.0),
        isPartial: json['is_partial'] as bool? ?? false,
      );
}

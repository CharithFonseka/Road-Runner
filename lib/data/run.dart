// Road Runner — Run Model for SQLite Storage (Pure Dart)
// Owner: Nadeesha
// SRS reference: Section 8.5

import 'package:road_runner/core/contract/contract.dart';

/// Represents a single completed workout summary stored in the SQLite `runs` table.
class Run {
  final String id;
  final int startedAtUtcMs;
  final int endedAtUtcMs;
  final int movingMs;
  final double distanceM;
  final double? avgPaceSecPerKm;
  final double? maxSpeedMps;
  final String status;
  final String? runName;
  final String? placeName;
  final double? weatherTempC;
  final double? weatherWindKmh;
  final int? weatherCode;
  final String? localStartDay;

  const Run({
    required this.id,
    required this.startedAtUtcMs,
    required this.endedAtUtcMs,
    required this.movingMs,
    required this.distanceM,
    this.avgPaceSecPerKm,
    this.maxSpeedMps,
    this.status = kStateSaved,
    this.runName,
    this.placeName,
    this.weatherTempC,
    this.weatherWindKmh,
    this.weatherCode,
    this.localStartDay,
  });

  /// Factory constructor to create a [Run] instance from a SQLite row map.
  factory Run.fromDbMap(Map<String, Object?> map) {
    return Run(
      id: map['id']! as String,
      startedAtUtcMs: (map['started_at_utc_ms']! as num).toInt(),
      endedAtUtcMs: (map['ended_at_utc_ms']! as num).toInt(),
      movingMs: (map['moving_ms']! as num).toInt(),
      distanceM: (map['distance_m']! as num).toDouble(),
      avgPaceSecPerKm: (map['avg_pace_sec_per_km'] as num?)?.toDouble(),
      maxSpeedMps: (map['max_speed_mps'] as num?)?.toDouble(),
      status: (map['status'] as String?) ?? kStateSaved,
      runName: map['run_name'] as String?,
      placeName: map['place_name'] as String?,
      weatherTempC: (map['weather_temp_c'] as num?)?.toDouble(),
      weatherWindKmh: (map['weather_wind_kmh'] as num?)?.toDouble(),
      weatherCode: (map['weather_code'] as num?)?.toInt(),
      localStartDay: map['local_start_day'] as String?,
    );
  }

  /// Converts this [Run] instance to a SQLite row map for database insertion.
  Map<String, Object?> toDbMap() {
    return {
      'id': id,
      'started_at_utc_ms': startedAtUtcMs,
      'ended_at_utc_ms': endedAtUtcMs,
      'moving_ms': movingMs,
      'distance_m': distanceM,
      'avg_pace_sec_per_km': avgPaceSecPerKm,
      'max_speed_mps': maxSpeedMps,
      'status': status,
      'run_name': runName,
      'place_name': placeName,
      'weather_temp_c': weatherTempC,
      'weather_wind_kmh': weatherWindKmh,
      'weather_code': weatherCode,
      'local_start_day': localStartDay,
    };
  }

  /// Creates a copy of this [Run] with the given fields replaced.
  Run copyWith({
    String? id,
    int? startedAtUtcMs,
    int? endedAtUtcMs,
    int? movingMs,
    double? distanceM,
    double? avgPaceSecPerKm,
    double? maxSpeedMps,
    String? status,
    String? runName,
    String? placeName,
    double? weatherTempC,
    double? weatherWindKmh,
    int? weatherCode,
    String? localStartDay,
  }) {
    return Run(
      id: id ?? this.id,
      startedAtUtcMs: startedAtUtcMs ?? this.startedAtUtcMs,
      endedAtUtcMs: endedAtUtcMs ?? this.endedAtUtcMs,
      movingMs: movingMs ?? this.movingMs,
      distanceM: distanceM ?? this.distanceM,
      avgPaceSecPerKm: avgPaceSecPerKm ?? this.avgPaceSecPerKm,
      maxSpeedMps: maxSpeedMps ?? this.maxSpeedMps,
      status: status ?? this.status,
      runName: runName ?? this.runName,
      placeName: placeName ?? this.placeName,
      weatherTempC: weatherTempC ?? this.weatherTempC,
      weatherWindKmh: weatherWindKmh ?? this.weatherWindKmh,
      weatherCode: weatherCode ?? this.weatherCode,
      localStartDay: localStartDay ?? this.localStartDay,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Run &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          startedAtUtcMs == other.startedAtUtcMs &&
          endedAtUtcMs == other.endedAtUtcMs &&
          movingMs == other.movingMs &&
          distanceM == other.distanceM &&
          avgPaceSecPerKm == other.avgPaceSecPerKm &&
          maxSpeedMps == other.maxSpeedMps &&
          status == other.status &&
          runName == other.runName &&
          placeName == other.placeName &&
          weatherTempC == other.weatherTempC &&
          weatherWindKmh == other.weatherWindKmh &&
          weatherCode == other.weatherCode &&
          localStartDay == other.localStartDay;

  @override
  int get hashCode => Object.hash(
    id,
    startedAtUtcMs,
    endedAtUtcMs,
    movingMs,
    distanceM,
    avgPaceSecPerKm,
    maxSpeedMps,
    status,
    runName,
    placeName,
    weatherTempC,
    weatherWindKmh,
    weatherCode,
    localStartDay,
  );

  @override
  String toString() {
    return 'Run(id: $id, startedAtUtcMs: $startedAtUtcMs, endedAtUtcMs: $endedAtUtcMs, movingMs: $movingMs, distanceM: $distanceM, avgPaceSecPerKm: $avgPaceSecPerKm, maxSpeedMps: $maxSpeedMps, status: $status, runName: $runName, placeName: $placeName, weatherTempC: $weatherTempC, weatherWindKmh: $weatherWindKmh, weatherCode: $weatherCode, localStartDay: $localStartDay)';
  }
}

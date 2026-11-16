// Road Runner — Running Statistics Calculations (Pure Dart)
// Owner: Nadeesha
// SRS reference: Section 4.6, 4.7, 8.5

import 'dart:math' as math;

import 'package:road_runner/core/contract/contract.dart';

import 'haversine.dart';
import 'models.dart';

/// Computes the total distance in meters between consecutive accepted GPS points.
///
/// Returns 0.0 if there are fewer than 2 accepted points.
double computeDistance(List<Point> points) {
  final List<Point> accepted = points.where((p) => p.accepted).toList();
  if (accepted.length < 2) {
    return 0.0;
  }

  double totalMeters = 0.0;
  for (int i = 1; i < accepted.length; i++) {
    final double step = haversineM(
      accepted[i - 1].lat,
      accepted[i - 1].lon,
      accepted[i].lat,
      accepted[i].lon,
    );
    if (!step.isNaN && !step.isInfinite && step > 0.0) {
      totalMeters += step;
    }
  }

  return totalMeters;
}

/// Computes the moving duration in milliseconds, defined as total elapsed time
/// minus the duration of all pause intervals.
///
/// Pauses outside the [startMs, endMs] window are clamped.
/// Overlapping or adjacent pause intervals are merged so paused time is not counted twice.
int computeMovingMs(int startMs, int endMs, List<PauseInterval> pauses) {
  if (endMs <= startMs) {
    return 0;
  }

  final int elapsedMs = endMs - startMs;

  // 1. Clamp each pause interval to the [startMs, endMs] window
  final List<_Interval> clamped = [];
  for (final pause in pauses) {
    final int clampedStart = math.max(pause.startMs, startMs);
    final int clampedEnd = math.min(pause.endMs, endMs);
    if (clampedEnd > clampedStart) {
      clamped.add(_Interval(clampedStart, clampedEnd));
    }
  }

  if (clamped.isEmpty) {
    return elapsedMs;
  }

  // 2. Sort by start timestamp ascending
  clamped.sort((a, b) => a.start.compareTo(b.start));

  // 3. Merge overlapping and adjacent pause intervals
  final List<_Interval> merged = [];
  _Interval current = clamped[0];

  for (int i = 1; i < clamped.length; i++) {
    final next = clamped[i];
    if (next.start <= current.end) {
      current = _Interval(current.start, math.max(current.end, next.end));
    } else {
      merged.add(current);
      current = next;
    }
  }
  merged.add(current);

  // 4. Calculate total paused milliseconds
  final int totalPauseMs = merged.fold<int>(
    0,
    (sum, interval) => sum + (interval.end - interval.start),
  );

  final int movingMs = elapsedMs - totalPauseMs;
  return math.max(0, movingMs);
}

/// Computes the average pace in seconds per kilometer.
///
/// Returns null if:
/// - [distanceM] is less than [CalcConfig.minDistanceForPaceM] (50.0 m)
/// - [movingMs] is non-positive
/// - values are not finite
/// - calculated pace exceeds [CalcConfig.maxPaceSecPerKm] (1200.0 s/km)
double? computeAvgPaceSecPerKm(double distanceM, int movingMs) {
  if (distanceM < CalcConfig.minDistanceForPaceM ||
      movingMs <= 0 ||
      distanceM.isNaN ||
      distanceM.isInfinite) {
    return null;
  }

  final double km = distanceM / 1000.0;
  final double seconds = movingMs / 1000.0;
  final double pace = seconds / km;

  if (pace <= 0.0 ||
      pace.isNaN ||
      pace.isInfinite ||
      pace > CalcConfig.maxPaceSecPerKm) {
    return null;
  }

  return pace;
}

/// Computes 1-kilometer splits with linearly interpolated boundary timestamps.
///
/// Only accepted GPS points are considered. If there is remaining distance after
/// the last full kilometer, a partial split ([Split.isPartial] = true) is appended.
List<Split> computeSplits(
  List<Point> points, {
  List<PauseInterval> pauses = const [],
}) {
  final List<Point> accepted = points.where((p) => p.accepted).toList();
  if (accepted.length < 2) {
    return const [];
  }

  // Sort chronologically by timestamp
  accepted.sort((a, b) => a.tUtcMs.compareTo(b.tUtcMs));

  final List<Split> splits = [];
  double accumulatedDistanceM = 0.0;
  double nextTargetDistanceM = CalcConfig.splitDistanceM;
  int splitIndex = 1;

  int prevSplitBoundaryTimestampMs = accepted.first.tUtcMs;
  double prevSplitBoundaryDistanceM = 0.0;

  for (int i = 1; i < accepted.length; i++) {
    final Point pPrev = accepted[i - 1];
    final Point pCurr = accepted[i];

    final double segmentDist = haversineM(
      pPrev.lat,
      pPrev.lon,
      pCurr.lat,
      pCurr.lon,
    );
    if (segmentDist <= 0.0 || segmentDist.isNaN || segmentDist.isInfinite) {
      continue;
    }

    final double newAccumulatedDistanceM = accumulatedDistanceM + segmentDist;
    final int segmentDurationMs = math.max(0, pCurr.tUtcMs - pPrev.tUtcMs);

    while (newAccumulatedDistanceM >= nextTargetDistanceM) {
      final double distanceNeededInSegment =
          nextTargetDistanceM - accumulatedDistanceM;
      final double fraction = (distanceNeededInSegment / segmentDist).clamp(
        0.0,
        1.0,
      );
      final int splitBoundaryTimestampMs =
          pPrev.tUtcMs + (fraction * segmentDurationMs).round();

      final int splitDurationMs = computeMovingMs(
        prevSplitBoundaryTimestampMs,
        splitBoundaryTimestampMs,
        pauses,
      );

      splits.add(
        Split(
          kmIndex: splitIndex,
          durationMs: splitDurationMs,
          distanceM: CalcConfig.splitDistanceM,
          isPartial: false,
        ),
      );

      prevSplitBoundaryTimestampMs = splitBoundaryTimestampMs;
      prevSplitBoundaryDistanceM = nextTargetDistanceM;
      splitIndex++;
      nextTargetDistanceM += CalcConfig.splitDistanceM;
    }

    accumulatedDistanceM = newAccumulatedDistanceM;
  }

  // Append any final partial split for the remaining distance.
  // We emit a partial split if there is meaningful remaining distance (>= 1.0m),
  // or if the run was shorter than 1 km and produced no full splits yet.
  final double remainderDistanceM =
      accumulatedDistanceM - prevSplitBoundaryDistanceM;
  if ((splits.isEmpty ? remainderDistanceM > 0.0 : remainderDistanceM >= 1.0) &&
      accepted.isNotEmpty) {
    final int remainderDurationMs = computeMovingMs(
      prevSplitBoundaryTimestampMs,
      accepted.last.tUtcMs,
      pauses,
    );
    splits.add(
      Split(
        kmIndex: splitIndex,
        durationMs: remainderDurationMs,
        distanceM: remainderDistanceM,
        isPartial: true,
      ),
    );
  }

  return splits;
}

/// Finds the maximum speed in meters per second among accepted points.
///
/// Returns null if no accepted points contain a valid non-negative speed.
double? computeMaxSpeedMps(List<Point> points) {
  final validSpeeds = points
      .where(
        (p) =>
            p.accepted &&
            p.speedMps != null &&
            !p.speedMps!.isNaN &&
            !p.speedMps!.isInfinite &&
            p.speedMps! >= 0.0,
      )
      .map((p) => p.speedMps!)
      .toList();

  if (validSpeeds.isEmpty) {
    return null;
  }

  return validSpeeds.reduce(math.max);
}

class _Interval {
  final int start;
  final int end;

  const _Interval(this.start, this.end);
}

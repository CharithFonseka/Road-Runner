// Road Runner — TEMPORARY display formatter for live run values.
// Owner: Tharushi
// SRS reference: Section 4.7 (display rules), 8.4
//
// DEPENDENCY: lib/domain/stats/ (Nadeesha) will provide the official
// formatPace / formatDistance / formatSpeed. Until they are merged, this
// adapter does DISPLAY FORMATTING ONLY:
//   - milliseconds    -> time text
//   - metres          -> kilometres text
//   - metres/second   -> km/h text
//   - seconds per km  -> m:ss text
// It never calculates new running statistics (no distance, pace, splits or
// speed derived from other measurements). When the domain formatters land,
// replace the method bodies here (or pass a subclass to ActiveRunScreen) so
// screens do not change.

import '../../core/contract/contract.dart';

/// Turns bridge-provided measurements into display text.
///
/// Every method accepts null and returns a placeholder, so the screen never
/// shows invented numbers before the bridge has sent real values.
class LiveRunFormatter {
  const LiveRunFormatter();

  static const String elapsedPlaceholder = '--:--';
  static const String distancePlaceholder = '-.--';
  static const String speedPlaceholder = '--.-';
  static const String pacePlaceholder = '--:--';

  /// A duration such as moving time: "m:ss" under one hour ("18:42"),
  /// "h:mm:ss" from one hour ("1:02:03"). The short form keeps the 62sp
  /// timer readable at large system text sizes without dropping below 32sp.
  /// (The name is historical; it formats any millisecond duration.)
  String elapsed(int? ms) {
    if (ms == null || ms < 0) return elapsedPlaceholder;
    final int totalSeconds = ms ~/ 1000;
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    final String ss = seconds.toString().padLeft(2, '0');
    if (hours == 0) return '$minutes:$ss';
    final String mm = minutes.toString().padLeft(2, '0');
    return '$hours:$mm:$ss';
  }

  /// Distance in kilometres with two decimals, e.g. "3.42" (unit shown
  /// separately).
  String distanceKm(double? metres) {
    if (metres == null || !metres.isFinite || metres < 0) {
      return distancePlaceholder;
    }
    return (metres / 1000).toStringAsFixed(2);
  }

  /// Speed in km/h with one decimal, e.g. "11.0" (unit shown separately).
  String speedKmh(double? metresPerSecond) {
    if (metresPerSecond == null ||
        !metresPerSecond.isFinite ||
        metresPerSecond < 0) {
      return speedPlaceholder;
    }
    return (metresPerSecond * 3.6).toStringAsFixed(1);
  }

  /// Pace as "m:ss" per km, e.g. "5:27" (unit shown separately).
  ///
  /// Shows [pacePlaceholder] when the bridge has no pace (null), or when the
  /// pace is slower than [CalcConfig.maxPaceSecPerKm] (SRS §4.7 display rule).
  String pace(double? secondsPerKm) {
    if (secondsPerKm == null ||
        !secondsPerKm.isFinite ||
        secondsPerKm <= 0 ||
        secondsPerKm > CalcConfig.maxPaceSecPerKm) {
      return pacePlaceholder;
    }
    final int total = secondsPerKm.round();
    final int minutes = total ~/ 60;
    final String ss = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$ss';
  }
}

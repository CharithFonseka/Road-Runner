// Road Runner — Run Name Generator (Pure Dart)
// Owner: Nadeesha
// SRS reference: Section 8.5

/// Generates a human-friendly run name based on the local time of day and optional place name.
String makeRunName(DateTime localStart, String? placeName) {
  final period = localStart.hour < 12
      ? 'Morning'
      : localStart.hour < 17
      ? 'Afternoon'
      : 'Evening';

  return placeName == null ? '$period run' : '$period run in $placeName';
}

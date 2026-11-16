/// A useful title even when a run has no GPS fix or network connection.
String runName(int startedAtUtcMs, [String? place]) {
  final hour = DateTime.fromMillisecondsSinceEpoch(
    startedAtUtcMs,
    isUtc: true,
  ).toLocal().hour;
  final period = hour < 5
      ? 'Night'
      : hour < 12
      ? 'Morning'
      : hour < 17
      ? 'Afternoon'
      : hour < 21
      ? 'Evening'
      : 'Night';
  final location = place?.trim();
  return location == null || location.isEmpty
      ? '$period run'
      : '$period run in $location';
}

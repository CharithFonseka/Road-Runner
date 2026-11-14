# stats

Owner: Nadeesha  
SRS reference: Section 8.5

Pure Dart stats module — no Flutter imports.

## Functions to implement

- `haversineM(lat1, lon1, lat2, lon2)` → distance in meters (earth radius 6,371,000 m)
- `computeDistance(List<Point> accepted)` → total meters
- `computeMovingMs(startMs, endMs, List<PauseInterval>)` → ms
- `computeAvgPaceSecPerKm(distanceM, movingMs)` → nullable double
- `computeSplits(List<Point>)` → List<Split> with interpolated km-mark times
- `computeMaxSpeedMps(List<Point>)` → nullable double
- `formatPace(double? secPerKm)` → `'m:ss'` or `'--:--'`
- `formatDistance(double meters)` → `'x.xx km'`
- `formatSpeed(double? mps)` → `'x.x km/h'` or `'--.-'`

## Rules (SRS §4.7)

- Distance: haversine sum between consecutive **accepted** points while running.
- Moving time: elapsed minus paused. No auto-pause.
- Splits: interpolated (not rounded to nearest point).
- Earth radius: exactly 6,371,000 m.
- Units in storage: meters, seconds, m/s, UTC ms. Convert for display only.

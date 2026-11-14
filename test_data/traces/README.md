# test_data/traces

Owner: Nadeesha  
SRS reference: Section 8.5, §4.7

Golden GPS traces used for deterministic testing.  
**Due: 1 November 2026** (needed by Charith for filter tests and Tharushi for the path painter).

## Required traces (minimum 6)

| File | Description | Key property |
|---|---|---|
| `straight_1km.csv` | Straight 1 km at steady pace (~5 min/km) | Baseline accuracy |
| `loop_3km.csv` | 3 km loop returning close to start | Path drawing |
| `gps_spike.csv` | Trace with one obvious teleport jump | Filter must reject spike |
| `standing_jitter.csv` | 2 min of standing-still micro-movements | Filter must suppress |
| `pause_resume.csv` | Run with one pause and resume | No distance jump on resume |
| `long_gap.csv` | 15-second GPS gap in the middle | Straight-line fill rule |

## File format

Each trace is a pair of files:

```
straight_1km.csv       # raw GPS fixes
straight_1km_expected.json  # expected results
```

### CSV columns (one fix per row, header required)
```
t_utc_ms,lat,lon,acc_m,speed_mps,alt_m,is_mock
```

### expected.json schema
```json
{
  "distance_m": 1002.5,
  "accepted_points": 298,
  "splits": [
    { "km_index": 1, "duration_ms": 302000, "is_partial": false }
  ]
}
```

## Usage in tests

```dart
// Dart (Nadeesha's stats module tests)
final points = loadTrace('test_data/traces/straight_1km.csv');
final result = computeDistance(points.where((p) => p.accepted).toList());
expect(result, closeTo(expected.distanceM, expected.distanceM * 0.01));
```

```kotlin
// Kotlin (Charith's GpsFilter tests)
val fixes = loadTrace("test_data/traces/gps_spike.csv")
// feed through GpsFilter, assert spike rejected
```

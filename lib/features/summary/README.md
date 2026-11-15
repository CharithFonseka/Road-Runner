# Summary feature (FR-50, FR-51, FR-52)

Owner: Tharushi

## Public API

```dart
SummaryScreen(
  summary: runSummary,        // immutable RunSummary, built by the integrator
  onBackToHome: () {},
  onOpenHistory: () {},
)
```

The screen formats and draws the `RunSummary` it is given. It never calculates distance, pace, speed, splits or the fastest split.

## Where each field should come from

The data layer and the stats layer are only described in READMEs today; no code exists yet. `RunResult` from the bridge holds only `runId` and `filePath`.

| `RunSummary` field | Planned source | Status |
|---|---|---|
| `runId` | `RunResult.runId` | available |
| `startedAt` | `runs.started_at_utc_ms` (convert to `DateTime`, UTC) | planned |
| `distanceM` | `runs.distance_m` | planned |
| `movingMs` | `runs.moving_ms` | planned |
| `averagePaceSecPerKm` | `runs.avg_pace_sec_per_km` | planned |
| `averageSpeedMps` | **missing**, see below | — |
| `route` | `RunRepository.getPoints(runId)`, accepted points only, mapped to `RoutePoint(lat, lon, speedMps)` | planned |
| `splits` | `computeSplits(points)` | planned |
| `SplitSummary.isFastest` | **missing**, see below | — |

### Missing pieces

**For Nadeesha:**

1. **Average speed.** The `runs` table has no average-speed column, and the stats module has no matching function. Please add one, for example `computeAvgSpeedMps(distanceM, movingMs)` or an `avg_speed_mps` column. Until then the screen shows `--.- km/h`.
2. **Fastest split.** Nothing in the stats module marks the fastest split. Please add it to `Split`, or add a `fastestSplitIndex(splits)` function. The screen highlights only splits flagged `isFastest` and never chooses one itself.
3. **The `Split` model.** Please confirm it carries the kilometre number and that kilometre's duration in ms. Those map to `SplitSummary.km` and `SplitSummary.durationMs`.

**For Praveen:**

4. **Loading and navigation.** After `stopRun()`, the saved run must be loaded before this screen opens: `saveFromFile`, then `get` and `getPoints`. Navigation should then build a `RunSummary` and pass the callbacks.

**For Aadila:**

5. **Recorded speed.** The run file's `spd` value becomes `RoutePoint.speedMps`. If the device does not report speed, it stays null and the route is drawn in a single colour.

## Route drawing

- Only the points it is given are drawn. Nothing is added, smoothed or snapped to roads.
- **Projection:** longitude is scaled by cos(mean latitude), then one uniform scale fits the route in the box, centred, with north up.
- **Too short:** fewer than two distinct points shows "Route too short to map".
- **Speed colour:** each segment uses the speed at its end point (or its start point if the end has none), on this run's own slowest-to-fastest range, from orange (slower) to teal (faster). Segments with no speed are drawn muted brown. If there is no speed at all, the route is plain brown and a note says so.
- Routes that cross the ±180° meridian are not handled.

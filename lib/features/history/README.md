# History feature (FR-61, FR-62)

Owner: Tharushi

## Public API

```dart
HistoryScreen(
  runs: historyRuns,                 // List<HistoryRun>, in any order
  onRunSelected: (String runId) {},  // parent opens Summary for this run
  onBackToHome: () {},
)
```

- Runs are shown newest first: by `startedAt` descending, with ties broken by `runId`.
- The screen never creates run records. With an empty list it shows its empty state.

## Repository integration (Praveen and Nadeesha)

The data layer exists only as a README so far. Once `RunRepository` exists, the app flow should map `list()` to `HistoryRun` like this:

| `HistoryRun` field | Source |
|---|---|
| `runId` | `runs.id` |
| `startedAt` | `DateTime.fromMillisecondsSinceEpoch(started_at_utc_ms, isUtc: true)` |
| `distanceM` | `runs.distance_m` |
| `movingMs` | `runs.moving_ms` |
| `averagePaceSecPerKm` | `runs.avg_pace_sec_per_km` (may be null) |

Remaining requirements:

- **Saved runs only:** `list()` should return only saved runs (`status = 'saved'`), not unfinished ones.
- **Loading and errors:** show a loading or error state while `list()` runs; that is the parent's job.
- **Opening a run:** `onRunSelected(runId)` should load `get(runId)` and `getPoints(runId)`, then open Summary.

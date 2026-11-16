# History feature (FR-61, FR-62)

Owner: Tharushi

## Public API

The required constructor arguments remain compatible with the application
integration:

```dart
HistoryScreen(
  runs: historyRuns,
  onRunSelected: (String runId) {},
  onBackToHome: () {},
)
```

Optional inputs:

- `referenceDate` makes local-calendar month filtering deterministic in tests.
- `initialFilter` selects `HistoryRunFilter.allRuns`, `thisMonth`, or
  `lastMonth`. It defaults to `allRuns` to preserve the previous screen behavior.
- `thisMonthSummary` and `lastMonthSummary` accept `HistoryMonthlySummary`
  values supplied by the integration/domain layer. All Runs never shows a
  month-specific summary.
- `isLoading`, `hasError`, and `onRetry` provide loading and error states.
- `onStartRun`, `onOpenHome`, and `onOpenSettings` enable the corresponding
  actions when the caller supports them. Home falls back to `onBackToHome`.

Runs are filtered by their actual start timestamp in local calendar time and
shown newest first; ties retain the existing deterministic `runId` ordering.
Filtering and sorting do not mutate the input collection. The screen does not
create records or aggregate monthly statistics.

## Repository and summary integration

Map saved repository runs to `HistoryRun` as before:

| `HistoryRun` field | Source |
|---|---|
| `runId` | `runs.id` |
| `startedAt` | `DateTime.fromMillisecondsSinceEpoch(started_at_utc_ms, isUtc: true)` |
| `distanceM` | `runs.distance_m` |
| `movingMs` | `runs.moving_ms` |
| `averagePaceSecPerKm` | `runs.avg_pace_sec_per_km` (may be null) |

Supply `HistoryMonthlySummary` values from outside the widget. Each summary
contains a display month label, total run count, total distance in metres, and
total moving time in milliseconds. If a summary is absent, its card is omitted;
the screen does not invent totals. The All Runs filter does not display either
monthly summary.

The current app shell supplies the existing required arguments only, so it
opens All Runs without summaries, loading/error state, Start a Run callback, or
a Settings destination callback. Those remain optional for backward
compatibility and should be wired when the integration supports them.

`onRunSelected(runId)` remains responsible for loading the run and its points,
then opening Summary. Loading/errors and retry behavior likewise belong to the
integration layer; pass `isLoading` or `hasError` and the relevant callback
when available.

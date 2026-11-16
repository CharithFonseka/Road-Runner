# Summary feature (FR-50, FR-51, FR-52)

Owner: Tharushi

## Public API

```dart
SummaryScreen(
  summary: runSummary,        // immutable RunSummary, built by the integrator
  onBackToHome: () {},
  onOpenHistory: () {},
  // Optional (Phase 2B.1):
  onBack: () {},              // header Back; null uses onBackToHome
  isLoading: false,           // true shows static skeletons while loading
)
```

The screen formats and draws the `RunSummary` it is given. It never calculates distance, pace, average speed, splits or the fastest split.

There is no navigation drawer: Summary is reached from a finished run or from History.

Keys: `backButtonKey`, `dateKey`, `statsCardKey`, `statKey(SummaryStat)`, `routeAreaKey`, `splitsCardKey`, `splitRowKey(km)`, `partialSplitKey`, `loadingKey`, `homeButtonKey`, `historyButtonKey`.

## Layout (UI kit Revision 5)

- **Header:** a slim sky header with a 48dp Back button, "Run summary", and the run's date and start time, for example "14 Nov 2026 · 6:42 AM". If there is no timestamp, it says "Date unavailable".
- **Statistics:** Distance, Moving time, Average pace and Average speed, side by side with hairline dividers.
  - On narrow screens or with large text, the strip becomes a 2 × 2 grid, then one stat per line. Values are never cut off.
  - Missing or invalid values show the formatter's placeholder, such as `--.- km/h`, and are spoken as "not available".
- **Route:** unchanged in this phase; the redesign is Phase 2B.2. The too-short state now also says why: fewer than two distinct GPS points.
- **Splits:**
  - one row per full kilometre, showing that kilometre's time;
  - the split flagged `isFastest` gets a tinted row and a FASTEST label;
  - an optional final partial row such as "0.02 km partial 0:08", which is never highlighted.
  - With no splits: "Run under 1 km" when the distance is known to be under 1 km; otherwise "No splits to show".
- **Loading:** static skeletons the size of the cards, with no shimmer. The header and buttons stay usable.

## Where each field comes from (as integrated in `main.dart`)

| `RunSummary` field | Source |
|---|---|
| `runId` | `RunResult.runId` |
| `startedAt` | `runs.started_at_utc_ms` |
| `distanceM`, `movingMs`, `averagePaceSecPerKm` | `runs` row |
| `averageSpeedMps` | computed by the integrator as distance ÷ moving time (Nadeesha confirmed no stored column). The screen only formats it. |
| `route` | `RunRepository.getPoints`, accepted points only |
| `splits` | `computeSplits(points)`, full kilometres only |
| `SplitSummary.isFastest` | set by the integrator on the full split with the lowest `durationMs` |
| `partialSplit` | **new, optional.** The `Split` with `isPartial == true` from `computeSplits`, mapped to `PartialSplitSummary(distanceM, durationMs)` |

### Integration follow-up (Charith / Praveen)

`main.dart` currently drops the partial split (`.where((s) => !s.isPartial)`), so the partial row never appears in the app. To show it, pass it in `_loadRunSummary`:

```dart
final Split? partial =
    computeSplits(points).where((s) => s.isPartial).lastOrNull;
// ...
partialSplit: partial == null
    ? null
    : PartialSplitSummary(
        distanceM: partial.distanceM,
        durationMs: partial.durationMs,
      ),
```

Two more optional steps:
- `isLoading: true` can be used if the Summary route is pushed before the repository read completes. Today it is pushed after the read, so this isn't needed.
- `onBack` can be passed for a different Back target. Without it, Back behaves like Back to Home, matching the current flow.

## Route drawing

- Only the points it is given are drawn. Nothing is added, smoothed or snapped to roads.
- **Projection:** longitude is scaled by cos(mean latitude), then one uniform scale fits the route in the box, centred, with north up.
- **Too short:** fewer than two distinct points shows "Route too short to map".
- **Speed colour:** each segment uses the speed at its end point (or its start point if the end has none), on this run's own slowest-to-fastest range, from orange (slower) to teal (faster). Segments with no speed are drawn muted brown. If there is no speed at all, the route is plain brown and a note says so.
- Routes that cross the ±180° meridian are not handled.

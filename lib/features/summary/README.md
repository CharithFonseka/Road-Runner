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

Revision 5 "Your route" card: parchment map (kit ratio 328 × 232, 220–360 dp tall), scale grid, route on a white underlay, scale pill, then a legend (Start, Finish, "Grid shows scale only"; Slower pace, Steady, Faster).

- Only the points it is given are drawn. Nothing is added, smoothed or snapped to roads.
- **Projection:** equirectangular around the mean latitude (east = Δlon · cos(mean lat), north = Δlat), converted to metres with a mean Earth radius of 6 371 008.8 m. One uniform scale fits the route, centred, north up, so the aspect ratio is true. Error versus WGS84 is under about 0.6%, which is fine for run-sized areas. Routes shorter than a few metres are never zoomed past 0.25 m per pixel.
- **Scale bar and grid:** `RouteLayout.metresPerPixel` comes from the same fit the painter uses. The bar is the largest "nice" length (1, 2, 2.5, 5 × 10ⁿ m) that is at most 110 px long, drawn at its exact pixel length and labelled with that value ("250 m", "1 km"). Grid squares are the same size, aligned to the start point. Nothing is hardcoded to 500 m.
- **Pace bands:** each segment uses the speed at its end point (or at its start point if the end has none). Bands are terciles of this run's own recorded point speeds: the slowest third is Slower pace (blue `#5182D5`), the fastest third is Faster (dark red `#87211C`), and the rest is Steady (orange `#D9581A`). Steady is slightly deeper than the kit's `#EB6621` so every band is at least 3:1 on the parchment. A constant-speed run is all Steady. Segments without speed are muted brown. If there is no speed at all, the route is plain brown and a note replaces the band legend. The bands are relative to the run, not absolute paces.
- **GPS gaps:** a segment longer than both 100 m and 8 × the run's median segment (it needs at least 3 moving segments) is treated as lost signal. It is drawn as a thin, dashed, uncoloured line, and a "GPS gap" legend entry appears. This is a drawing heuristic only. It does not change distance or stats.
- **Markers:** Start is a blue circle with a white ring and centre. Finish is an orange rounded square, drawn on top. The legend uses the same shapes and colours.
- **Too short:** empty, single-point or all-identical routes show "Route too short to map".
- **Split colour dots** are not shown. `SplitSummary` has no link to route points, so they cannot be matched without inventing data.
- Routes that cross the ±180° meridian are not handled.

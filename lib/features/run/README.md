# Run feature (Active Run, Paused Run and Stop Confirmation)

Owner: Tharushi

## Public API

```dart
ActiveRunScreen(
  bridge: trackingBridge,          // owned by the parent; never disposed here
  onRunFinished: (RunResult r) {}, // the real result from bridge.stopRun()
  onExit: () {},                   // leave after a failed start or an unresolved stop
)
```

- On open, the screen calls `getState()`. If a run is already running or paused, it adopts that run (FR-23). Otherwise it calls `startRun()`.
- `stopRun()` is called only after the user taps **Finish Run** in the confirmation.
- Android Back never leaves silently:
  - While running or paused, it opens the confirmation.
  - After a failed start or an unresolved stop, it calls `onExit`.
- Removing the screen cancels its event subscription only. It does not stop the run.

## What the screen shows

The live street map appears after the first accepted GPS fix. It draws each
accepted point from the bridge, follows the current position until the user
moves the map, and offers a recenter button. When the screen reattaches to an
active run, it restores the full accepted route from the app-private run file.
The route stays visible if online map tiles are unavailable. OpenMapTiles and
OpenStreetMap credit stays on the map.

| Stat | Bridge field | Label | Notes |
|---|---|---|---|
| Main timer (62sp) | `movingMs` | Moving time | Freezes while paused. |
| Pace (32sp) | `paceSecPerKm` | Current pace | `--:-- /km` when null or slower than 20 min/km. |
| Distance (32sp) | `distanceM` | Distance | km, 2 decimals. |
| Speed (32sp) | `speedMps` | Speed | km/h, 1 decimal. |

- GPS quality (Searching, Weak, Good) and the run status pill (Starting, Recording, Paused, Finishing) are in the header, so they never shrink the four statistics.
- `elapsedMs` (wall-clock time) is not shown.

## Confirmed bridge behaviour (Aadila)

- **Moving time and elapsed time:**
  - `elapsedMs` is wall-clock duration and keeps rising during Pause.
  - `movingMs` freezes during Pause.
- **Pace:** `paceSecPerKm` is the current pace, derived from smoothed speed. Average pace is a separate statistic for completed runs, shown on Summary and History.
- **Notification:** it has Pause and Resume actions, but no Stop.
- **Finishing a run:** a normal finish calls `stopRun()` and receives the `RunResult` directly.
- **Crash recovery:** this can use `getState()` and `getUnfinishedRun()`. That is the app shell's job, not this screen's.

### Defensive stop handling

The notification cannot stop a run. Even so, the screen still handles a `stopped` event that it did not cause, for example when the service ends unexpectedly:

1. It calls `getState()`.
2. If that returns a stopped run with both a `runId` and a `filePath`, the real result is passed to `onRunFinished`.
3. Otherwise the screen shows **"Run stopped"** with **Exit**. No result is invented.

`MockTrackingBridge` stops itself after 300 ticks (5 minutes). Its `getState()` has no `filePath`, so with the mock this path ends on "Run stopped".

**Note for Aadila:** `MockTrackingBridge` currently emits moving time divided by distance, which is average pace, as `paceSecPerKm`. The screen labels whatever it receives "Current pace", so previews with the mock show an average-pace value. The native service sends the real current pace.

## Temporary formatter

`live_run_formatter.dart` only converts units: ms to time, m to km, m/s to km/h, and s/km to m:ss.

Nadeesha's `lib/domain/stats/formatting.dart` is merged, but it is not a drop-in replacement:

- `formatDistance` and `formatSpeed` include the unit, and this screen draws units separately at a smaller size.
- `formatDistance` returns `0.00 km` for missing values, and this screen needs a placeholder instead.
- There is no duration formatter.

Moving to the shared formatters is planned for a later phase.

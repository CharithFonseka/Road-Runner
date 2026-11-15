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

## Open integration questions

### For Aadila (bridge)

1. **Elapsed time while paused.** The screen shows `TrackingSnapshot.elapsedMs` as "Elapsed time", exactly as reported. `MockTrackingBridge` keeps increasing `elapsedMs` while paused. Please confirm what the native service does.
2. **Pace meaning.** The screen labels `paceSecPerKm` "Average pace" because the mock computes moving time divided by distance. If the native value becomes a current or rolling pace, the label must change.
3. **Paused snapshots.** While paused, the screen keeps whatever the latest snapshot says (the mock sends speed 0 and pace null). The screen does not invent or zero any values.

### For Aadila and Praveen (stopping from the notification)

When the run is stopped outside the screen, the bridge sends a `stopped` state event but no `RunResult`. The screen then calls `getState()`:

- If the status is `stopped` and has both a `runId` and a `filePath`, that real result is passed to `onRunFinished`.
- Otherwise, the screen shows **"Run stopped"** with an **Exit** button. No result or file path is invented.

The mock's `getState()` returns no `filePath`, so this path always ends unresolved today. A supported way to recover the result is needed, either:

- `getState().filePath` after a stop, or
- `getUnfinishedRun()` covering this case.

## Temporary formatter

`live_run_formatter.dart` only converts units: ms to time, m to km, m/s to km/h, and s/km to m:ss. Replace it with Nadeesha's domain formatters when they are merged.

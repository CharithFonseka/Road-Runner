# Tracking Engine

Owner: Charith
Language: Kotlin

## Requirements

Follow Road_Runner_SRS.md:
- Section 4: core contract, states, run file, GPS filtering
  and calculation rules.
- Section 8.2: tracking engine tasks and acceptance checks.
- Section 9: testing and Definition of Done.

The SRS is the source of truth for requirements.
This README records implementation details only.

## Current Status

- `GpsFilter` accepts or rejects GPS fixes and reports distance added.
- `GpsFilterTest` contains unit tests; their execution has not been verified yet.
- `RunClock` tracks elapsed and moving time across pauses.
- `RunFileWriter` writes v1 JSONL files under `filesDir/runs/`.
- The foreground service, live snapshots, and recovery UI are still to come.

## Implementation Notes

- Pass monotonic milliseconds from `SystemClock.elapsedRealtime()` to `RunClock`, not UTC time.
- Call `GpsFilter.markResumed()` when a paused run resumes so the next accepted fix adds no distance.
- GPS fix timestamps and future run-file timestamps use UTC milliseconds.

## Integration

- Aadila: connect tracking events through TrackingApi
  to the Flutter bridge and notification.
- Praveen: coordinate Contract.kt and FilterConfig.
- Nadeesha: provide golden traces and expected statistics.
- Tharushi: display tracking data through TrackingBridge.



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

- The service records filtered GPS fixes, supports pause/resume, and emits live events.
- `RunRecovery` finds and discards unfinished v1 run files.
- Bridge integration, run import, and real-phone verification remain.

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



# Road Runner — Prototype Demo Script (Monday 16 November 2026)

Owner: Praveen (Presenter & QA Lead)  
SRS reference: Section 1.2, Section 5, Section 8.1

> **Goal:** Demonstrate a reliable, offline, privacy-first Android run tracker built in Flutter + native Kotlin — highlighting background screen-off GPS tracking, lock-screen chronometer notification, accurate post-run summary with custom speed-coloured path drawing, and local SQLite persistence.

---

## Pre-Demo Setup Checklist (15 minutes before demo)

1. **Primary Demo Phone:**
   - Fully charged (> 80%), screen brightness at comfortable indoor visibility.
   - Do Not Disturb **OFF** (or notifications allowed for Road Runner) so lock-screen notification is visible.
   - Location / GPS enabled on High Accuracy.
   - Pre-load **3–5 realistic sample runs** (or real field-test runs) in History so History list and Summary comparisons look authentic immediately.
   - Keep a **second phone** with the exact same release APK installed as a cold backup.
   - If indoors (classroom/lab), have a **pre-recorded field test video** and **real field-test screenshots** ready on the laptop/phone to prove outdoor GPS accuracy (`NFR-02`) and lock-screen timing (`NFR-03`) where indoor GPS signal is weak.
2. **Code & Repo Readiness:**
   - Have `docs/test-logs/field-test-log.md`, `battery-test-log.md`, `device-matrix.md`, and `core-test-cases.md` open to cite real measured numbers (no guessing).
   - Release APK installed (`adb install -r build/app/outputs/flutter-apk/app-release.apk`).
   - Confirm `"Road Runner"` name and original bird launcher icon appear cleanly on the home screen (`FR-71`).

---

## Live Demo Flow (5–7 Minutes)

### Scene 1: Launch & Permissions (`NFR-06`, `NFR-09`, `FR-40`, `FR-41`, `FR-70`, `FR-71`)
- **Action:** Tap the **Road Runner** icon on the Android home screen (fresh install or cleared permissions for first run, or show permission rationale flow).
- **Show:**
  - Cold start completes in under 3 seconds (`NFR-06`).
  - Road Runner desert-inspired palette, clean typography, and original bird icon (`FR-70`, `FR-71`).
  - Explain-then-ask permission prompt (`FR-40`): explains *why* precise location and notification permissions are needed before triggering the Android system dialog.
- **Talking point:** *"Road Runner works 100% offline — no internet permission in the release build, no account, no analytics, everything stays in app-private storage."*

### Scene 2: One-Tap Run Start & Live Display (`FR-01`, `FR-16`, `FR-20`, `FR-21`, `NFR-09`)
- **Action:** From the Home screen, tap **Start** (≤ 2 taps from launch).
- **Show:**
  - App immediately transitions to the **Run** screen (`RUNNING` state within 2 s).
  - GPS status pill shows `Searching` / `"Finding GPS"` until the first fix better than 20 m (`FR-16`) — timer runs, distance stays at `0.00 km` (no fake jump).
  - Large daylight-readable stats (`≥ 32sp`): elapsed/moving time (`mm:ss`), distance (`km`, 2 decimals), current speed (`km/h`, 1 decimal), and pace (`m:ss` min/km, showing `--:--` while stationary or < 50 m).
- **Talking point:** *"All live numbers are owned and calculated by our native Kotlin foreground service and pushed once per second over Flutter EventChannel — the UI never recalculates live stats."*

### Scene 3: Screen Off & Lock Screen Notification (`FR-10`, `FR-23`, `FR-30`, `FR-31`, `FR-32`, `FR-34`)
- **Action:** Lock the phone (press power button). Wait 5–10 seconds.
- **Show on lock screen:**
  - Ongoing Road Runner notification visible on the lock screen with live ticking timer and current speed (`FR-30`).
  - Point out that the timer uses Android's system **Chronometer** (`FR-31`) — we do *not* rebuild the notification every second, protecting battery life (`NFR-04` target ≤ 8%/hr).
- **Action:** Tap the notification from the lock screen (and/or unlock and reopen the app).
- **Show:** Opens straight back to the **Run** screen; numbers resync within 1 second (`FR-23`, `FR-32`).

### Scene 4: Pause, Resume & Accidental-Stop Guard (`FR-02`, `FR-03`)
- **Action:** Tap **Pause**.
- **Show:**
  - Timer freezes; distance stops counting; location updates stop to save battery.
  - Pull down shade / check lock screen: notification clearly displays **"Paused"** and chronometer pauses (`FR-34`).
- **Action:** Tap **Resume** → timer resumes from exact paused value; no distance jump from pre-pause position (`FR-02`).
- **Action:** Single-tap **Stop** → show confirmation dialog / hold action (`FR-03`) so an accidental tap mid-run never ends a workout. Confirm **Stop**.

### Scene 5: Post-Run Summary, Path Painter & Splits (`FR-50`, `FR-51`, `FR-52`, `NFR-11`)
- **Action:** (If indoors with short/zero distance, also open one of the pre-recorded 2–3 km real outdoor runs from History immediately after.)
- **Show:**
  - Summary opens within 2 seconds (`FR-03`).
  - **CustomPainter GPS Path** (`FR-50`): zero paid map tiles, zero network calls — path is projected cleanly, start marker + bird finish marker, coloured by speed (10th–90th percentile normalization).
  - Key stats (`FR-51`): distance, moving time, average pace, average speed, date & start time.
  - **Kilometre Splits** (`FR-52`): interpolated 1 km splits with partial last km and best split highlighted.

### Scene 6: Local Persistence, History & Reliability (`FR-60`, `FR-61`, `FR-62`, `FR-05`)
- **Action:** Navigate to **History**, force-close the app from Android recents, reopen Road Runner, and open History again.
- **Show:** Runs persist cleanly in SQLite (`FR-60`), sorted newest first (`FR-61`), and tapping a past run opens the exact same Summary screen (`FR-62`).
- **Bonus resilience point:** Mention the `.jsonl` crash-safe run file (`FR-05`): if Android kills the app mid-run, relaunching offers `"Recover run"` with zero lost points up to the last flush.

---

## Backup / Contingency Plan (If Live GPS Signal Fails Indoors)

1. **Indoors GPS behavior:** Show how `GpsFilter` properly displays `"Finding GPS"` (`FR-16`) instead of hallucinating noisy indoor fixes.
2. **Pre-recorded Outdoor Proof:** Immediately switch to the real outdoor field-test run in History (and play the recorded lock-screen / field-test screen recording) and share the exact measured accuracy & battery figures from `docs/test-logs/field-test-log.md` and `battery-test-log.md`.
3. **Architecture & QA Proof:** Show `bash scripts/check_contract.sh` (`64/64` constants verified), unit tests (`flutter test` & `./gradlew testDebugUnitTest`), and the release manifest check (`TC-13`) confirming zero `INTERNET` permission.

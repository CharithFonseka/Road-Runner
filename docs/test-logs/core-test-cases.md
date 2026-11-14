# Core Test Cases Execution Log (`TC-01` to `TC-14`)

Owner: Praveen (coordinated across team)  
SRS reference: Section 9.1, Section 9.6

> **Rule (`DoD` §9.1):** Run on a real phone (or golden traces where specified). Attach a screenshot or screen recording link/reference in the Evidence column for every completed case. Mark Status as `PASS`, `FAIL`, `BLOCKED`, or `PENDING`.

---

## Build Under Test

- **Commit SHA / Tag:** `<git rev-parse --short HEAD>`
- **APK Build Type:** `Debug / Release`
- **APK File Size (`NFR-13` target ≤ 40 MB):** `<XX.X MB>`
- **Test Date(s):** `<YYYY-MM-DD>`

---

## Core Test Cases (`SRS §9.6`)

| ID | Covers | Steps | Expected Result | Device / Tester | Status | Evidence / Notes |
|---|---|---|---|---|---|---|
| **TC-01** | `FR-01`, `FR-10` | Grant permissions, tap Start, lock the phone, walk 5 min | Ongoing notification appears on lock screen within 2 s; `.jsonl` run file grows at ~1 point/sec | | ⬜ PENDING | |
| **TC-02** | `FR-02` | Pause for 30 s, then resume | Timer and distance freeze during pause; notification shows `"Paused"`; no distance jump after resume | | ⬜ PENDING | |
| **TC-03** | `FR-03` | Single tap on Stop | Run continues uninterrupted; confirmation step (dialog or hold button) is required before ending | | ⬜ PENDING | |
| **TC-04** | `FR-12` | Replay each golden trace (`test_data/traces/`) | Reported distance matches `expected.json` within **1%** for every trace | | ⬜ PENDING | |
| **TC-05** | `FR-20`, `FR-30` | Compare Run screen and lock screen notification after 10 min | Both timers agree within **1 s** of each other and within **1 s** of an external stopwatch | | ⬜ PENDING | |
| **TC-06** | `FR-13` | Stop a run, wait 2 s, then inspect running services, location listeners, and notifications | Within 2 s: no foreground service running, no notification visible, no active location listener (verify via `adb` below) | | ⬜ PENDING | |
| **TC-07** | `FR-05` | Force-stop app mid-run (`adb shell am force-stop com.roadrunner.app` or Android Settings), reopen app | `"Recover run"` prompt is offered; recovering imports a valid run up to the last synced point | | ⬜ PENDING | |
| **TC-08** | `FR-15` | Turn device Location off mid-run | Native emits `LOCATION_OFF` error event; run pauses cleanly; clear plain-language message shown; no crash | | ⬜ PENDING | |
| **TC-09** | `FR-40`, `FR-41` | Deny location permission on first prompt, then permanently deny | Explain-then-ask rationale shown first; clear plain-language error on deny; `"Open settings"` button opens Android app settings cleanly; no crash | | ⬜ PENDING | |
| **TC-10** | `FR-50`, `FR-52` | Complete a loop run and open Summary screen | Path drawn cleanly without map tiles, closed loop, coloured by speed, start/finish markers visible, full-km interpolated splits + best split highlighted | | ⬜ PENDING | |
| **TC-11** | `FR-60`, `FR-62` | Force-close/restart app, open History, open the saved run | Saved run appears newest-first; opening it in Summary shows identical numbers to right after the run | | ⬜ PENDING | |
| **TC-12** | `FR-65` | Start a run and stop it immediately (< 10 s / < 20 m / 0 points) | Handled cleanly without crash or `NaN`; pace displays `--:--`; discard prompt offered (`FR-04`) if implemented | | ⬜ PENDING | |
| **TC-13** | `NFR-07`, `NFR-08` | Build release APK and inspect merged release `AndroidManifest.xml` | Zero `android.permission.INTERNET` in release manifest; `android:allowBackup="false"`; service/receivers `android:exported="false"` | | ⬜ PENDING | |
| **TC-14** | `NFR-06` | Load a 1-hour run (~3,600 points) into Summary | Summary (stats, splits, downsampled path) renders in **under 2 s**; 100-run History list scrolls smoothly | | ⬜ PENDING | |

---

## ADB & CLI Verification Commands

Run these via USB debugging while executing `TC-06`, `TC-07`, `TC-13`, and automated checks:

### 1. Contract Parity & Automated Unit Checks
```bash
bash scripts/check_contract.sh
flutter analyze
flutter test
cd android && ./gradlew testDebugUnitTest lintDebug && cd ..
```

### 2. `TC-06` — Verify Clean Service & Location Release (run 2 s after Stop)
```bash
# Confirm TrackingService is no longer running
adb shell dumpsys activity services com.roadrunner.app

# Confirm no active Fused/LocationManager registration remains for com.roadrunner.app
adb shell dumpsys location | grep -i -A 5 "roadrunner"

# Confirm ongoing notification is dismissed
adb shell dumpsys notification --noredact | grep -i -A 10 "com.roadrunner.app"
```

### 3. `TC-07` — Simulate Mid-Run Crash / Force-Stop
```bash
adb shell am force-stop com.roadrunner.app
```

### 4. `TC-13` & `NFR-13` — Release Manifest & APK Size Inspection
```bash
flutter build apk --release
ls -lh build/app/outputs/flutter-apk/app-release.apk

# Inspect merged release manifest (requires Android SDK build-tools aapt2)
aapt2 dump xmltree build/app/outputs/flutter-apk/app-release.apk --file AndroidManifest.xml | grep -E "INTERNET|allowBackup|exported|foregroundServiceType"
```
*Expected:* `INTERNET` must **not** appear; `allowBackup` must be `false` (`0x0`); `TrackingService` must have `exported=false` (`0x0`) and `foregroundServiceType=0x8` (`location`).

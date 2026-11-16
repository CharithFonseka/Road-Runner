# Integration Build Reports

Owner: Praveen  
SRS reference: Section 7, Section 8.1, Section 9.1 – 9.2

> **Policy (`SRS §4.1` C12 & `§8.1`):** Every integration build must have a ticked checklist saved here. Never merge a PR with failing CI or unapproved contract changes.

---

## Build 0 — M0 Foundation & Contract Freeze (14 Nov 2026)

- **Commit:** `0686cb5` on `main` (pushed to `origin/main`)
- **Scope:** Repo structure (`§3.4`), Core Contract (`contract.dart` & `Contract.kt`), contract parity script (`scripts/check_contract.sh`), unit tests for contract, Android permissions (`AndroidManifest.xml`), approved dependencies (`pubspec.yaml`), JUnit dependency (`android/app/build.gradle.kts`), CI workflow definition (`docs/ci-workflow.yml`).

### Checklist
- [x] Folder structure created per SRS §3.4 with owner READMEs
- [x] App ID (`com.roadrunner.app`) and `minSdk = 26` confirmed
- [x] `lib/core/contract/contract.dart` and `Contract.kt` committed with all 64 constants
- [x] `bash scripts/check_contract.sh` passes (**64/64 constants match**)
- [x] `AndroidManifest.xml` declares only the 6 approved SRS §3.3 permissions (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS`, `WAKE_LOCK`) and `android:allowBackup="false"`
- [x] `pubspec.yaml` contains only SRS §3.1 approved packages (`flutter_riverpod`, `sqflite`, `go_router`, `permission_handler`, `cupertino_icons`)
- [x] `.github/workflows/ci.yml` active on GitHub Actions
- [ ] Run `flutter pub get`, `flutter analyze`, `flutter test`, and `./gradlew testDebugUnitTest` on a machine with Flutter SDK installed (or via `.github/workflows/ci.yml`)

---

## Build 1 — M1: Tracking End-to-End Integration

- **Target status:** Merges Nadeesha's stats/golden traces + Aadila's `MockTrackingBridge`/native bridge + Charith's `feature/tracking-engine` (`TrackingService` + `TrackingApi`)
- **Date:** `2026-11-16`
- **Commit SHA:** `ace29c5`

### Pre-Merge PR Gate (`SRS §9.2`)
- [x] Only owner's folders modified (or explicit owner approval recorded)
- [x] Contract files (`contract.dart`, `Contract.kt`, `FilterConfig`) unchanged, or CCR linked
- [x] `bash scripts/check_contract.sh` passes (including `tracking/FilterConfig.kt` check — **70/70 constants match**)
- [x] No new permissions, no `INTERNET` permission in main/release manifest, no analytics/network packages
- [x] `AndroidManifest.xml` has `<service android:name=".tracking.TrackingService" android:exported="false" android:foregroundServiceType="location" />` enabled

### Verification Checklist
- [ ] `flutter pub get` succeeds
- [ ] `flutter analyze` passes with 0 errors/warnings
- [ ] `flutter test` passes (contract tests + stats tests + golden trace tests)
- [ ] `cd android && ./gradlew testDebugUnitTest lintDebug` passes
- [ ] `flutter build apk --debug` succeeds
- [ ] Debug APK installs cleanly on real phone (`adb install`)
- [ ] Real run started from app -> `.jsonl` file created in `filesDir/runs/<runId>.jsonl` -> 1 s `snapshot` events reach Flutter

### Build Notes & Blockers
- _Notes:_ Code integration completed in `lib/main.dart` (Home, Permissions, ActiveRun, Summary, History, crash recovery, startup resync, `AppTheme.light()`, `SqliteRunRepository`, `NativeTrackingBridge`, `computeSplits`/`formatDistance`/`formatPace`) and `MainActivity.kt` (`TrackingBridgePlugin` registration + `ServiceDelegate` + `TrackingApi.events` forwarding). Pending CI/device verification (Flutter SDK not installed on local machine).

---

## Build 2 — M2: Full Run Flow Integrated

- **Target status:** Home, Permissions, Run, Stop confirmation, Summary (path painter + splits), History, and Lock Screen notification integrated end-to-end
- **Date:** `2026-11-16`
- **Commit SHA:** `ace29c5`

### Verification Checklist
- [x] `bash scripts/check_contract.sh` passes (**70/70 constants match**)
- [ ] `flutter analyze` & `flutter test` pass
- [ ] `./gradlew testDebugUnitTest lintDebug` passes
- [ ] Cold start on real phone under **3 s** (`NFR-06`)
- [ ] Launch to Run start in **≤ 2 taps** (`NFR-09`)
- [ ] Explain-then-ask permissions flow works for Location + Notifications (`FR-40`, `FR-41`)
- [ ] Lock screen notification shows system chronometer (`C10` — not rebuilt every second) and speed
- [ ] Stop confirmation works; Summary opens within **2 s** (`FR-03`)
- [ ] Live distance vs Summary distance agree within **1%** (`NFR-11`)
- [ ] Run persists to SQLite (`sqflite`) across app restart and opens cleanly from History (`FR-60`–`FR-62`)

### Build Notes & Blockers
- _Notes:_ Code integration completed in `lib/main.dart` (Home, Permissions, ActiveRun, Summary, History, crash recovery, startup resync, `AppTheme.light()`, `SqliteRunRepository`, `NativeTrackingBridge`, `computeSplits`/`formatDistance`/`formatPace`) and `MainActivity.kt` (`TrackingBridgePlugin` registration + `ServiceDelegate` + `TrackingApi.events` forwarding). Pending CI/device verification (Flutter SDK not installed on local machine).

---

## Build 3 — M4: Release Candidate (RC)

- **Date:** `2026-11-16`
- **Commit SHA:** `ace29c5`
- **APK File Path:** `build/app/outputs/flutter-apk/app-release.apk`
- **Release APK Size (`NFR-13` target ≤ 40 MB):** `<XX.X MB>`

### Final Release Checklist (`SRS §6`, `§9.1`, `§9.6`)
- [ ] All **Must** functional requirements pass acceptance checks (`FR-01`–`FR-03`, `FR-10`–`FR-13`, `FR-16`, `FR-20`–`FR-21`, `FR-23`, `FR-30`–`FR-32`, `FR-34`, `FR-40`–`FR-41`, `FR-50`–`FR-52`, `FR-60`–`FR-62`, `FR-65`, `FR-70`–`FR-72`)
- [x] `bash scripts/check_contract.sh` passes (**70/70 constants match**)
- [ ] `flutter analyze` & `flutter test` pass (0 skipped/relaxed tests)
- [ ] `./gradlew testDebugUnitTest lintDebug` passes
- [ ] `TC-01` through `TC-14` marked PASS in `docs/test-logs/core-test-cases.md`
- [ ] Device matrix completed (`≥ 3` real phones, `≥ 2` brands, Android 13+, Android 14+, aggressive battery brand)
- [ ] Field test log completed (`< 3%` open-sky error) in `docs/test-logs/field-test-log.md`
- [ ] Battery test log completed in `docs/test-logs/battery-test-log.md`
- [ ] Release manifest audited (`TC-13` / `NFR-07`): `INTERNET` used only for approved free-tier services (maps, weather, places, routing, Firebase Auth/Firestore; no analytics/ad/paid SDKs), `allowBackup="false"`, service `exported="false"`
- [ ] Release APK ≤ 40 MB (`NFR-13`)
- [x] Signing keystore kept **outside** the repository (verified via `git status` & `.gitignore`)
- [ ] Demo script rehearsed on the demo phone (`docs/demo-script.md`)

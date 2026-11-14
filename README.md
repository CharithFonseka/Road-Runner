# Road Runner

An Android running tracker — Flutter + Kotlin prototype.

**Prototype deadline:** Monday 16 November 2026  
**Platform:** Android 8.0 (API 26) and above

---

## Quick start (3 commands)

```bash
git clone <repo-url>
cd Road-Runner
flutter pub get
flutter run          # requires a connected Android device or emulator
```

> A real phone with GPS is required for all tracking features.
> Emulators can be used for UI-only work with the mock bridge.

---

## Team

| Member | Area | Folders |
|---|---|---|
| Praveen | Project lead, integration, CI, QA | `lib/core/contract/`, `docs/`, `.github/`, scripts/ |
| Charith | Tracking engine (Kotlin) | `android/.../tracking/` |
| Aadila | Lock screen + bridge | `android/.../notification/`, `android/.../bridge/`, `lib/bridge/` |
| Tharushi | Flutter screens + design | `lib/features/`, `lib/core/theme/` |
| Nadeesha | Data, stats, test data | `lib/domain/stats/`, `lib/data/`, `test_data/` |

**Rule:** edit only your own folders. Changes to another member's folder require their approval on the PR.

---

## Repository structure

```
lib/
  core/
    contract/     ← frozen shared spec (Praveen)
    theme/        ← design tokens (Tharushi)
  bridge/         ← Dart bridge interface + mock (Aadila)
  features/
    home/         ← (Tharushi)
    run/          ← (Tharushi)
    summary/      ← (Tharushi)
    history/      ← (Tharushi)
    permissions/  ← (Tharushi)
  domain/
    stats/        ← pure Dart stats module (Nadeesha)
  data/           ← SQLite repository (Nadeesha)
android/app/src/main/kotlin/com/roadrunner/app/
  tracking/       ← foreground service (Charith)
  notification/   ← lock screen notification (Aadila)
  bridge/         ← MethodChannel + EventChannel plugin (Aadila)
test/             ← unit + widget tests (each owner)
test_data/
  traces/         ← golden GPS traces (Nadeesha)
docs/
  test-logs/      ← field + battery test results
  decisions.md    ← one-line record of team decisions
scripts/
  check_contract.sh ← CI contract comparison script
.github/
  workflows/
    ci.yml        ← analyze, test, build APK on every PR
```

---

## CI

Every pull request runs:
1. `flutter analyze` (fatal on infos)
2. `flutter test`
3. Kotlin unit tests (`./gradlew testDebugUnitTest`)
4. Android lint (`./gradlew lintDebug`)
5. Debug APK build — uploaded as a CI artifact
6. Contract check — `scripts/check_contract.sh` verifies `contract.dart` and `Contract.kt` match

**Rule:** never merge a PR with a red CI.

---

## Contract changes (CCR)

The contract (`lib/core/contract/contract.dart` and `Contract.kt`) is frozen.  
To change it: open a GitHub issue titled `CCR: <what>`, get Praveen's approval after affected owners agree, then update both files together.

See SRS §4.8 for the full process.

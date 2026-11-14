# docs

This folder contains project documentation, QA logs, integration reports, demo prep, and decision records.

## Contents

| Path | Purpose |
|---|---|
| `test-logs/` | Device matrix, core test cases (`TC-01`–`TC-14`), integration reports, field & battery logs |
| `demo-script.md` | Step-by-step prototype demo script for Monday 16 November 2026 |
| `decisions.md` | One-line record of every team decision (see SRS §10) |
| `ci-workflow.yml` | GitHub Actions CI workflow definition |

## Test log template

See SRS §9.4 and §9.5 for the field and battery test protocols, or fill in [`test-logs/field-test-log.md`](test-logs/field-test-log.md) and [`test-logs/battery-test-log.md`](test-logs/battery-test-log.md) directly.

```
Date:
Phone model + Android version:
Tester:
Route / test type:
Reference distance (m):
App distance (m):
Error (%):
App time (mm:ss):
Stopwatch time (mm:ss):
Battery start (%):
Battery end (%):
Duration (min):
Estimated drain per hour (%):
Notes:
```

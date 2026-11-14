# docs

This folder contains project documentation, test logs, and decision records.

## Contents

| Path | Purpose |
|---|---|
| `test-logs/` | Field test, battery test and integration build logs |
| `decisions.md` | One-line record of every team decision (see SRS §10) |

## Test log template

See SRS §9.4 and §9.5 for the field and battery test protocols.  
Use the template below when saving a log in `test-logs/`.

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

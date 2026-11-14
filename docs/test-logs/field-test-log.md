# Field Test Log

Owner: Praveen (with test runners from the team)  
SRS reference: Section 4.7, Section 6 (`NFR-02`, `NFR-03`, `NFR-11`), Section 9.4

---

## Field Test Protocol (`SRS §9.4`)

1. Pick a route with a known reference length of **2 km or more** (a measured running track or a route measured carefully with a free mapping tool). Include:
   - An **open-sky** section for the primary accuracy check (`NFR-02`).
   - A **tree-covered or urban/city** section for the GPS stress test.
2. Carry at least **two test phones** in the same pocket or armband while running or jogging the exact same route.
3. Record for each phone: reference length (`m`), app distance (`m`), error (`%`), app moving/elapsed time vs external stopwatch (`mm:ss`), and notes on path drawing.
4. Perform **at least one test run with a pause and resume** in the middle (verify timer and distance freeze during pause and no jump on resume).
5. Check live-vs-summary consistency (`SRS §4.7` / `NFR-11`): final Summary distance must be within **1%** of the last live distance shown before Stop.

### Pass Criteria
- Open-sky distance error **within 3%** of the reference length (`|App - Reference| / Reference * 100 <= 3.0%`).
- Moving/elapsed time within **1 s** of the external stopwatch (`NFR-03`).
- Final Summary distance within **1%** of last live distance.
- Zero crashes; path rendered cleanly on Summary.

---

## Formulas

- **Distance Error (%):** $\text{Error \%} = \frac{|\text{App Distance (m)} - \text{Reference Distance (m)}|}{\text{Reference Distance (m)}} \times 100$
- **Live vs Summary Parity (%):** $\text{Parity \%} = \frac{|\text{Summary Distance (m)} - \text{Last Live Distance (m)}|}{\text{Last Live Distance (m)}} \times 100$

---

## Test Session Records

### Run 1 — Open-Sky Accuracy Test (≥ 2 km)

- **Date:** `<YYYY-MM-DD>`
- **Route name & measurement tool:** `<e.g. Independence Square 400m track x 6 laps / OpenStreetMap measure>`
- **Weather / Sky conditions:** `<Clear / Cloudy>`
- **Reference distance (m):** `<e.g. 2400>`
- **Stopwatch time (mm:ss):** `<mm:ss>`

| Phone & Android Version | Tester | Last Live Dist (m) | Final Summary Dist (m) | Live/Final Parity (%) | Reference Error (%) | App Time (mm:ss) | Time Diff vs Stopwatch (s) | Path Drawing & Splits Notes | Result |
|---|---|---|---|---|---|---|---|---|---|
| Phone A: `<Model / Android XX>` | | | | | | | | | ⬜ PASS / FAIL |
| Phone B: `<Model / Android XX>` | | | | | | | | | ⬜ PASS / FAIL |

---

### Run 2 — Pause & Resume Mid-Run Verification

- **Date:** `<YYYY-MM-DD>`
- **Route & Reference distance (m):** `<...>`
- **Planned pause duration (s):** `<e.g. 60 s>` (walk/move slightly or stay still while paused to verify no distance jump)
- **Stopwatch active time (mm:ss):** `<mm:ss>`

| Phone & Android Version | Tester | Dist Before Pause (m) | Dist After Resume (m) | Jump on Resume? | Notification Showed "Paused"? | Final Summary Dist (m) | Reference Error (%) | App Moving Time (mm:ss) | Result |
|---|---|---|---|---|---|---|---|---|---|
| Phone A: `<Model / Android XX>` | | | | Yes / No | Yes / No | | | | ⬜ PASS / FAIL |
| Phone B: `<Model / Android XX>` | | | | Yes / No | Yes / No | | | | ⬜ PASS / FAIL |

---

### Run 3 — Tree-Covered / Urban Stress Test

- **Date:** `<YYYY-MM-DD>`
- **Route & Reference distance (m):** `<...>`
- **Environment notes:** `<Tree canopy density / tall buildings>`
- **Stopwatch time (mm:ss):** `<mm:ss>`

| Phone & Android Version | Tester | Final Summary Dist (m) | Reference Error (%) | GPS Quality Drops Observed? | Path Zigs/Jumps Filtered? | Crashes? | Notes |
|---|---|---|---|---|---|---|---|
| Phone A: `<Model / Android XX>` | | | | | Yes / No | Yes / No | |
| Phone B: `<Model / Android XX>` | | | | | Yes / No | Yes / No | |

---

## Issues Found & Follow-up Actions

| Issue | Severity | Owner | Logged in Error Log? | Fix Commit / Status |
|---|---|---|---|---|
| _None recorded yet_ | | | | |

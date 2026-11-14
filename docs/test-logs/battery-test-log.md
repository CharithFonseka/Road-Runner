# Battery Test Log

Owner: Praveen (coordinated with Charith & Aadila)  
SRS reference: Section 6 (`NFR-04`), Section 9.5

> **Target (`NFR-04`):** No more than **8% battery per hour** with GPS on and screen off on a mid-range phone, and no worse than a popular free tracker run side by side.  
> **Honesty rule (`SRS §6` & `§9.5`):** Report the exact measured numbers honestly in this log, even if they exceed the target.

---

## Battery Test Protocol (`SRS §9.5`)

1. Charge test phone(s) to **100%** (or record exact starting percentage from Android Battery settings).
2. Keep **screen brightness**, **mobile data ON**, and **background apps** identical across runs (close other heavy apps; no music/video streaming).
3. Start a run in Road Runner, lock the screen immediately, place the phone in a pocket, and walk continuously for **30 minutes** with the screen off.
4. Immediately after 30 minutes, unlock, stop the run, and record the **end battery percentage**.
5. Calculate the scaled hourly rate:
   $$\text{30-min Drain (\%)} = \text{Battery Start (\%)} - \text{Battery End (\%)}$$
   $$\text{Estimated Hourly Drain (\%/hr)} = \text{30-min Drain (\%)} \times \frac{60}{\text{Actual Duration (min)}}$$
6. Repeat the same 30-minute walk with a **popular free running tracker** (e.g., Strava, Adidas Running, or Nike Run Club) either side-by-side on a second phone of the same model or on the same phone on a separate run under matching conditions.

---

## Test Results

### Test 1 — Road Runner (30 min Screen-Off Walk)

| Field | Phone 1 (Mid-range target) | Phone 2 (Optional) |
|---|---|---|
| **Date** | `<YYYY-MM-DD>` | `<YYYY-MM-DD>` |
| **Tester** | | |
| **Phone model & Android version** | | |
| **Battery health / capacity (mAh)** | | |
| **Mobile data & brightness settings** | Mobile data ON, Wi-Fi/BT state: `...` | Mobile data ON, Wi-Fi/BT state: `...` |
| **Start time (HH:MM)** | | |
| **End time (HH:MM)** | | |
| **Actual duration (min)** | `30` | `30` |
| **Battery start (%)** | | |
| **Battery end (%)** | | |
| **30-min drain (%)** | | |
| **Estimated drain per hour (%/hr)** | | |
| **Points recorded vs expected (~1,800)** | | |
| **Notification updated every second? (`C10` check)** | `No (verified in logs)` | `No` |

---

### Test 2 — Reference Free Tracker Comparison

| Field | Reference App (`<e.g. Strava / ...>`) | Comparison Notes |
|---|---|---|
| **Date** | `<YYYY-MM-DD>` | |
| **Tester** | | |
| **Phone model & Android version** | | |
| **Actual duration (min)** | `30` | |
| **Battery start (%)** | | |
| **Battery end (%)** | | |
| **30-min drain (%)** | | |
| **Estimated drain per hour (%/hr)** | | |

---

## Summary & Target Check (`NFR-04`)

- **Road Runner hourly drain:** `<X.X %/hr>` vs Target `≤ 8.0 %/hr` → `MET / ABOVE TARGET`
- **Reference tracker hourly drain:** `<Y.Y %/hr>` → Road Runner is `<better / equal / higher by Z%>`
- **Observations / Potential optimizations if > 8%/hr:**
  - _e.g., verify notification speed text updates at most every 3 s (`C10`), verify `WakeLock` releases on pause/stop, verify no redundant `EventChannel` serialization._

# Device Matrix

Owner: Praveen (coordinated across team)  
SRS reference: Section 6 (`NFR-01`, `NFR-12`), Section 9.3

> **Target requirement (`NFR-01`):** Runs on Android 8.0 (API 26) and above. Tested on at least **3 real phones**, **2 or more brands**, including **one on Android 13+** and **one on Android 14+**.  
> **Brand behaviour (`NFR-12`):** Tested on at least one brand known for aggressive battery management (e.g., Xiaomi, OPPO, realme, vivo, Huawei, OnePlus), with exact user settings noted.

---

## Test Device Matrix

Fill in every column once each team member confirms their available test phone.

| # | Phone Model & Brand | Android Version / API | Google Play Services | Carrier / Tester | Required Role (SRS §9.3) | Status |
|---|---|---|---|---|---|---|
| 1 | _e.g. Pixel / Samsung / Xiaomi_ | _Android XX (API XX)_ | Yes / No | _Name_ | **Main test phone** | ⬜ Pending |
| 2 | _e.g. ..._ | _Android 13+ (API 33+)_ | Yes / No | _Name_ | **Notification permission check** (`POST_NOTIFICATIONS`) | ⬜ Pending |
| 3 | _e.g. ..._ | _Android 14+ (API 34+)_ | Yes / No | _Name_ | **Foreground service type check** (`FOREGROUND_SERVICE_LOCATION`) | ⬜ Pending |
| 4 | _e.g. Xiaomi / OPPO / realme / Huawei_ | _Android XX (API XX)_ | Yes / No | _Name_ | **Brand with aggressive battery management** (`NFR-12`) | ⬜ Pending |

---

## Coverage Verification (`NFR-01`)

- [ ] Minimum 3 distinct real Android phones tested
- [ ] At least 2 distinct OEM brands represented
- [ ] All phones run Android 8.0 (API 26) or newer
- [ ] At least 1 phone runs Android 13 (API 33) or newer — verified runtime `POST_NOTIFICATIONS` prompt + denied fallback
- [ ] At least 1 phone runs Android 14 (API 34) or newer — verified `foregroundServiceType="location"` start from visible app without `SecurityException` or `ForegroundServiceStartNotAllowedException`
- [ ] At least 1 aggressive-battery OEM phone tested for 30+ min screen-off tracking

---

## OEM Aggressive Battery Management Notes (`NFR-12`)

Record exact phone-specific behaviour and required user settings observed during screen-off soak and field tests.

### Device tested: `<Brand / Model / Android & UI version (e.g. MIUI / HyperOS / ColorOS)>`
- **Default behaviour (without changing settings):**
  - Did tracking survive 30 min with screen off? `Yes / No`
  - Did GPS updates drop or stop after screen lock? `Notes:`
  - Did the lock-screen notification stay visible? `Yes / No`
- **OEM settings required (if tracking was killed or throttled):**
  - Battery saver / app battery policy: e.g. `Settings -> Apps -> Road Runner -> Battery -> Unrestricted / No restrictions`
  - Autostart / background lock (if applicable): e.g. `...`
- **Notes for `FR-42` / Demo day:**
  - _Write concise guidance to include or explain during the demo._

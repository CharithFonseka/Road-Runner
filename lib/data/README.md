# Data Layer (SQLite Storage & Enrichment)

**Owner:** Nadeesha
**SRS Reference:** Section 8.5
**Database Name:** `road_runner.db`
**Current Database Version:** `6`

SQLite storage layer implemented via `sqflite`. Persists completed runs, GPS track points, pause intervals, cached geocoded places, and awarded badges/streaks.

---

## Schema Versions & Migrations

| Version | Migration Summary |
|---|---|
| **v1** | Initial release schema: `runs` and `run_points` tables with compound index `(run_id, seq)`. |
| **v2** | Added `run_pauses` table for tracking pause and resume intervals. |
| **v3** | Added 6 nullable metadata columns to `runs`: `run_name`, `place_name`, `weather_temp_c`, `weather_wind_kmh`, `weather_code`, `local_start_day`. |
| **v4** | Added `place_cache` table with composite primary key `(lat_bucket, lon_bucket)` for offline/cached reverse geocoding. |
| **v5** | Added `run_badges` table with composite primary key `(run_id, badge_type)` and cascade delete on `runs(id)`. |
| **v6** | Added `planned_routes` and ordered `planned_route_points` tables. |

The v6 migration also preserves run names, cached places, and saved routes
from early route-planner builds that used a different v4 schema.

---

## Database Tables

### 1. `runs` table
Main storage for summary statistics and enrichment metadata.

| Column | Type | Constraints / Description |
|---|---|---|
| `id` | `TEXT` | PRIMARY KEY (UUID / runId) |
| `started_at_utc_ms` | `INTEGER` | NOT NULL. Epoch milliseconds UTC |
| `ended_at_utc_ms` | `INTEGER` | NOT NULL. Epoch milliseconds UTC |
| `moving_ms` | `INTEGER` | NOT NULL. Elapsed time minus pause durations |
| `distance_m` | `REAL` | NOT NULL. Total distance in metres |
| `avg_pace_sec_per_km` | `REAL` | Nullable. Average pace in seconds per kilometre |
| `max_speed_mps` | `REAL` | Nullable. Maximum speed in metres per second |
| `status` | `TEXT` | NOT NULL. Default `'saved'` |
| `run_name` | `TEXT` | Nullable. Friendly title (e.g., `"Morning run in Colombo"`) |
| `place_name` | `TEXT` | Nullable. Reverse-geocoded locality (e.g., `"Colombo"`) |
| `weather_temp_c` | `REAL` | Nullable. Temperature in Celsius at run start |
| `weather_wind_kmh` | `REAL` | Nullable. Wind speed in km/h at run start |
| `weather_code` | `INTEGER` | Nullable. WMO weather interpretation code |
| `local_start_day` | `TEXT` | Nullable. Date in local calendar format `YYYY-MM-DD` |

### 2. `run_points` table
Recorded raw track GPS coordinates and metrics.

| Column | Type | Constraints / Description |
|---|---|---|
| `run_id` | `TEXT` | FOREIGN KEY REFERENCES `runs(id)` ON DELETE CASCADE |
| `seq` | `INTEGER` | NOT NULL. 0-based sequence number |
| `t_utc_ms` | `INTEGER` | NOT NULL. Timestamp in epoch ms UTC |
| `lat` | `REAL` | NOT NULL. Latitude in degrees |
| `lon` | `REAL` | NOT NULL. Longitude in degrees |
| `acc_m` | `REAL` | NOT NULL. Horizontal accuracy in metres |
| `speed_mps` | `REAL` | Nullable. Instantaneous speed in m/s |
| `alt_m` | `REAL` | Nullable. Altitude in metres |
| `accepted` | `INTEGER` | NOT NULL. `1` if point passed filter, `0` if rejected |

*Index:* `idx_run_points_run_seq` on `(run_id, seq)`.

### 3. `run_pauses` table
Records pause periods during the run.

| Column | Type | Constraints / Description |
|---|---|---|
| `run_id` | `TEXT` | FOREIGN KEY REFERENCES `runs(id)` ON DELETE CASCADE |
| `start_ms` | `INTEGER` | NOT NULL. Pause start epoch ms |
| `end_ms` | `INTEGER` | Nullable. Resume epoch ms |

### 4. `place_cache` table
Local key-value bucket store for reverse geocoding to minimize external network requests.

| Column | Type | Constraints / Description |
|---|---|---|
| `lat_bucket` | `INTEGER` | NOT NULL. Bucket key: `(lat * 1000).round()` |
| `lon_bucket` | `INTEGER` | NOT NULL. Bucket key: `(lon * 1000).round()` |
| `place_name` | `TEXT` | NOT NULL. Resolved locality / city / town |

*Primary Key:* `(lat_bucket, lon_bucket)`.

### 5. `run_badges` table
Persists badges awarded to runs.

| Column | Type | Constraints / Description |
|---|---|---|
| `run_id` | `TEXT` | FOREIGN KEY REFERENCES `runs(id)` ON DELETE CASCADE |
| `badge_type` | `TEXT` | NOT NULL. Key: `'first_run'`, `'first_5km'`, `'fastest_km'`, `'seven_day_streak'` |
| `awarded_at_utc_ms` | `INTEGER` | NOT NULL. Timestamp of evaluation / award |

*Primary Key:* `(run_id, badge_type)`.

### 6. Planned routes

`planned_routes(id, name, created_at_utc_ms)` stores route metadata.
`planned_route_points(route_id, seq, lat, lon)` stores ordered geometry with a
foreign key to the route. `PlannedRouteRepository` saves each route and its
points in one transaction and supports loading, listing, replacing, and
deleting routes. Planned routes are separate from recorded runs.

---

## `RunRepository` Interface

Defined in `lib/data/run_repository.dart`:

```dart
abstract class RunRepository {
  Future<void> saveFromFile(String runId, String filePath);
  Future<List<Run>> list();
  Future<Run?> get(String runId);
  Future<List<Point>> getPoints(String runId);
  Future<List<PauseInterval>> getPauses(String runId);
  Future<void> delete(String runId);
  Future<String?> getUnfinishedRunPath();

  // Metadata & enrichment updates
  Future<void> updateWeather(
    String runId, {
    double? temperatureC,
    double? windKmh,
    int? weatherCode,
  });

  Future<void> updateDetails(
    String runId, {
    String? runName,
    String? placeName,
    double? temperatureC,
    double? windKmh,
    int? weatherCode,
    String? localStartDay,
  });

  // Achievements & Badges
  Future<List<RunBadge>> getBadgesForRun(String runId);
  Future<int> getCurrentStreak();
  Future<void> recalculateBadges();
}
```

*Note on `saveFromFile`:* Reads existing run metadata prior to replacing row so subsequent imports or file writes do NOT wipe enriched metadata.

---

## `RunEnrichmentService` & Asynchronous Pipeline

Defined in `lib/data/run_enrichment_service.dart`. Called immediately after `saveFromFile` without blocking the summary screen navigation:

```dart
await repository.saveFromFile(result.runId, result.filePath);
unawaited(runEnrichment.enrichRun(result.runId));
```

### Enrichment Steps:
1. **Loads Run & Points:** Fetches run details and GPS points from repository.
2. **Immediate Fallback:** If `runName` or `localStartDay` are unset, writes immediate fallback name (e.g., `"Morning run"`) and local day (`YYYY-MM-DD`) into DB.
3. **First Accepted Point Check:** Finds the first point with `accepted == true`. If none exists, stops gracefully without error.
4. **Parallel Lookup:** Concurrently requests:
   - Weather from Open-Meteo (`RunWeatherClient`)
   - Place name from Nominatim with local SQLite cache (`RunPlaceClient` + `PlaceCache`)
5. **Persistence:** Calls `repository.updateDetails(...)` to save place name, weather details, and updated run title (e.g. `"Morning run in Colombo"`).
6. **Graceful Degradation:** All exceptions are caught internally. Network errors or service timeouts will never crash the app or prevent run saving.

---

## Data Contract for Screen Owners (Tharushi)

Screen implementations (Summary, History, Run Details) can read the following fields directly from `Run`:

| Property | Type | Presentation / UI Usage |
|---|---|---|
| `run.runName` | `String?` | Display title for the run. Fallback if null: `"Morning run"`, `"Afternoon run"`, etc. |
| `run.placeName` | `String?` | Subheading or location badge (e.g. `"Colombo"`). |
| `run.weatherTempC` | `double?` | Ambient temperature formatted to 1 decimal place (e.g., `"${temp.toStringAsFixed(1)}°C"`). |
| `run.weatherWindKmh` | `double?` | Wind speed in km/h (e.g., `"${wind.toStringAsFixed(1)} km/h"`). |
| `run.weatherCode` | `int?` | Map using `conditionFromCode(code)` or display text. |
| `repository.getBadgesForRun(runId)` | `Future<List<RunBadge>>` | List of badges earned on this specific run. |
| `repository.getCurrentStreak()` | `Future<int>` | Current consecutive active calendar days count. |

### Weather Code to Condition Mapping (`conditionFromCode`)

Available via `import 'package:road_runner/data/run_weather_client.dart';`:

| Weather Codes (WMO) | `RunCondition` Enum | Suggested Label |
|---|---|---|
| `0, 1` | `RunCondition.clear` | `"Clear"` |
| `2, 3` | `RunCondition.cloudy` | `"Cloudy"` |
| `45, 48` | `RunCondition.fog` | `"Foggy"` |
| `51, 53, 55, 56, 57` | `RunCondition.drizzle` | `"Drizzle"` |
| `61, 63, 65, 66, 67, 80, 81, 82` | `RunCondition.rain` | `"Rain"` |
| `71, 73, 75, 77, 85, 86` | `RunCondition.snow` | `"Snow"` |
| `95, 96, 99` | `RunCondition.thunderstorm` | `"Thunderstorm"` |
| Any other / null | `RunCondition.unknown` | `"—"` |

---

## Badge Rules & Criteria

Calculated by `lib/domain/achievements/achievements.dart`:

1. **First Run (`first_run`):** Awarded to the very first chronologically saved run (`startedAtUtcMs`).
2. **First 5 km (`first_5km`):** Awarded to the first chronological run with `distanceM >= 5000.0`.
3. **Fastest 1 km (`fastest_km`):** Awarded to the run that contains the overall fastest completed 1,000 m moving split across all runs.
4. **7-Day Streak (`seven_day_streak`):** Awarded on the 7th consecutive calendar day with at least one recorded run (calculated from `local_start_day`). Multiple runs on the same calendar day count as one active day.

---

## Attributions & API Policies

### Open-Meteo
- Weather data provided by [Open-Meteo](https://open-meteo.com/) under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
- Non-commercial, open-source usage without API key. Attribution should be accessible in the app's About / Legal screens.

### OpenStreetMap / Nominatim
- Geocoding data © [OpenStreetMap](https://www.openstreetmap.org/copyright) contributors.
- **Nominatim Usage Policy:**
  - Must include a valid `User-Agent` with contact information (`RoadRunner/1.0 (contact: email)`).
  - Rate limited to maximum 1 request per second.
  - Results are aggressively cached locally in `place_cache` by coordinate buckets to avoid redundant requests.
  - *Note for Praveen:* If distributing publicly beyond demo/academic evaluation, configure a dedicated geocoding service or proxy to adhere strictly to OSM tile/geocoding acceptable use policies.

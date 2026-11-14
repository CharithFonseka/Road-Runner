# data

Owner: Nadeesha  
SRS reference: Section 8.5

SQLite storage layer via `sqflite`.

## Schema

**`runs` table**

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT PK | UUID |
| `started_at_utc_ms` | INTEGER | |
| `ended_at_utc_ms` | INTEGER | |
| `moving_ms` | INTEGER | elapsed minus paused |
| `distance_m` | REAL | |
| `avg_pace_sec_per_km` | REAL | nullable |
| `max_speed_mps` | REAL | nullable |
| `status` | TEXT | `'saved'` |

**`run_points` table**

| Column | Type | Notes |
|---|---|---|
| `run_id` | TEXT FK | |
| `seq` | INTEGER | 0-based |
| `t_utc_ms` | INTEGER | |
| `lat` | REAL | |
| `lon` | REAL | |
| `acc_m` | REAL | |
| `speed_mps` | REAL | nullable |
| `alt_m` | REAL | nullable |
| `accepted` | INTEGER | 0 or 1 |

Index: `(run_id, seq)`.

## RunRepository interface

```dart
Future<void> saveFromFile(String runId, String filePath);
Future<List<Run>> list();
Future<Run?> get(String runId);
Future<List<Point>> getPoints(String runId);
Future<void> delete(String runId);
Future<String?> getUnfinishedRunPath();
```

## Rules

- Insert points in a single transaction.
- Include a database version for future migrations.
- A 1-hour run (≈3,600 points) must save in under 1 s and load in under 500 ms.

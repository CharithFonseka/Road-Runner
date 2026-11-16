# Draft CCR: Live position and route on the Run screen

**Status:** Draft for Praveen and affected owners to review. Do not merge until approved.

## Why

The proposed live street map needs the latest accepted GPS position and every
accepted route point. The original bridge sends only live statistics; reopening
the Run screen cannot reconstruct points already recorded by the service.

## Proposed bridge contract v2

- Add optional `lat`, `lon`, and `seq` to each `snapshot` event and to the
  `snapshot` returned by `getState()`. These identify the latest **accepted**
  fix. They remain null until the first accepted fix and retain that position
  while paused. Rejected GPS fixes never move the map marker.
- Add a `point` event with `{type: "point", seq, lat, lon}` for every accepted
  fix. `seq` is the existing run-file point sequence number, so route events
  can be merged with the file without duplication.
- Return the app-private `filePath` from `getState()` while running or paused,
  as well as after stopping. Dart reads accepted points from the existing v1
  JSONL run file when it reattaches to an active run. A trailing incomplete
  line is ignored, and incoming point events continue to update the map.
- Add matching Dart and Kotlin constants and set the bridge contract version
  to 2. The run-file format and GPS filter thresholds do not change.

## Other changes tied to the map

- Add `flutter_map` and a vector-tile layer for OpenFreeMap's Liberty style.
  OpenFreeMap supplies map tiles only; tracking and the route remain local.
- Add Android `INTERNET` permission so release builds can request tiles.
- Keep OpenMapTiles and OpenStreetMap credit visible. If tiles fail to load,
  the current position and route still render over a plain background.
- Tile requests disclose the approximate viewed area to OpenFreeMap, so the
  team should review the updated privacy wording before release.

## Affected owners and review

- **Praveen:** contract version, both contract files, contract check, Android
  permission, package approval, integration and CCR approval.
- **Charith:** accepted-fix publication and tracking status behavior.
- **Aadila:** bridge models, point event decoding, and snapshot compatibility.
- **Tharushi:** Run screen map layout and controls.
- **Nadeesha:** review of run-file reading against accepted-point semantics.

## Verification before merge

- Contract parity script, Flutter analysis and tests, Android unit tests and
  debug APK build must pass.
- On a real phone, check first-fix acquisition, rejected GPS spikes, pause and
  resume, screen lock, closing and reopening the app during a run, and offline
  map tiles. Verify the full accepted route returns after reopening.
- Confirm the network permission and map attribution meet the team's updated
  privacy and demo requirements.

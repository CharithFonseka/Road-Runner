# features

Owner: Tharushi  
SRS reference: Section 8.4

Flutter screens. Each sub-folder is one feature.

| Folder | Screen | Key FRs |
|---|---|---|
| `home/` | Home screen — big Start button, last run card, History link | FR-01 (trigger), FR-71 |
| `run/` | Live run screen — time, distance, speed, pace, pause, stop | FR-20, 21, 22, 23 |
| `summary/` | Post-run summary — stats, path painter, splits | FR-50, 51, 52 |
| `history/` | History list + detail (reuses Summary) | FR-61, 62 |
| `permissions/` | Explain-then-ask permission flow | FR-40, 41 |

## Rules

- Talk only to `TrackingBridge` (interface) and the repository interfaces from Nadeesha.
- Never call native channels directly.
- Never compute stats in the UI — display what the bridge or repository provides.
- All user-facing text goes in one strings file (NFR-14).

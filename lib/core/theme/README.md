# theme

Owner: Tharushi  
SRS reference: Section 8.4

Design tokens: colours, text sizes, spacing.

## Suggested palette (SRS §8.4)

| Token | Value | Use |
|---|---|---|
| sand | `#F4E4C8` | Background |
| burnt orange | `#D9622B` | Primary action |
| dusk pink | `#E58C8A` | Secondary |
| canyon brown | `#5B3A29` | Text / dark surface |
| accent teal | `#2A9D8F` | Live data highlight |

Colours are a suggestion. Change freely if contrast stays at 4.5:1 or better.

## UI kit additions

Colour meaning: **blue = live running information** (Run screen), **teal = saved running statistics** (Home, History, Summary).

| Token | Value | Use |
|---|---|---|
| `liveBlue` | `#2E5AAE` | Live timer, pace, speed, GPS good, Live pill |
| `iconTile` | `#F6D2C2` | Fill behind icons (text on it: `canyonBrownDeep`) |
| `skyTop` / `skyMid` | `#A6C0FD` / `#CCCCE5` | Header gradient into `sand` (text on it: `canyonBrown`) |
| `divider` | `canyonBrown` 12% | Hairlines |

Text styles: `liveTimer` (62sp, blue), `livePace` (32sp, blue), `statValue` (20sp, teal, saved runs).
Illustration and route-map colours stay private inside the widgets that draw them.

### Unresolved design conflict (NFR-09)

The UI kit shows Run-screen distance and speed at 18sp. NFR-09 requires main running
statistics to be at least 32sp. The theme does not weaken this: when the Run screen is
built, distance and speed use 32sp or larger. If that does not fit beside the large
Pause/Stop buttons on small screens, the team decides the trade-off.

## Text contrast requirement

WCAG AA: 4.5:1 for normal text, 3:1 for large text (≥ 18sp regular or ≥ 14sp bold).

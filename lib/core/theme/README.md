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

## Light / dark architecture (UI kit Revision 5)

| Layer | File | What it holds |
|---|---|---|
| Raw tokens | `app_colors.dart` | `AppColors` (day, unchanged) and `AppDarkColors` (night, from the kit) |
| Semantic roles | `app_palette.dart` | `AppPalette` `ThemeExtension`: `AppPalette.light` / `AppPalette.dark` |
| Text | `app_text_styles.dart` | `const` styles (unchanged), `textThemeFor(palette)`, `AppTextStyles.of(context)` |
| Material themes | `app_theme.dart` | `AppTheme.light()`, `AppTheme.dark()`, `AppTheme.themeMode` (system) |

Both themes are built by one builder, so every component theme exists in both modes.
`AppPalette` is registered on both themes and lerps, so a system light/dark change cross-fades.

### How screens should read colours

```dart
final AppPalette p = context.palette;              // or AppPalette.of(context)
Container(decoration: BoxDecoration(gradient: p.skyGradient));
Text('5.02 km', style: AppTextStyles.of(context).statValue);
Icon(Icons.timer, color: p.accent);
```

- Material widgets (`FilledButton`, `OutlinedButton`, `TextButton`, `Card`, dialogs, drawer,
  `Divider`, `AppBar`, `Text` defaults) already follow `ColorScheme` / `TextTheme`.
- Use `AppPalette` for colours Material has no slot for (stat, statLive, route bands,
  GPS badge, skeleton, desert artwork, illustration).
- `AppColors.*` and the `const` `AppTextStyles.*` stay valid during migration; they are the
  day values only. A widget that still uses them will look correct by day and wrong at night.
- `context.palette` falls back to `AppPalette.light` when no Road Runner theme is present.

### Night tokens (kit Components sheet, night column)

| Role | Night | Day |
|---|---|---|
| background | `#171D2B` | `#F4E4C8` |
| surface (card, drawer, dialog) | `#293247` | `#FBF3E6` |
| textPrimary / textSecondary | `#F3E7D6` / `#D4C5B7` | `#5B3A29` / `#6E4F3E` |
| primaryFill / onPrimaryFill | `#A34A20` / `#FFFFFF` | same |
| primaryFillActive (Starting run) | `#7E3A19` | same |
| accent (icons, links, Pause border) | `#E8957A` | `#A34A20` |
| buttonOutline | `#8C7768` | `#A34A20` |
| iconTile | `#E8957A` 16% | `#F6D2C2` |
| stat (saved) / statLive | `#8FE0CF` / `#91B4FE` | `#1D6E64` / `#2E5AAE` |
| statLiveTint / highlight | `#91B4FE` 14% / `#8FE0CF` 12% | `#2E5AAE` 10% / `#1D6E64` 12% |
| gpsWeak / tint | `#FFCE29` / 14% | `#8A5200` / `#FFCE29` 24% |
| hairline / cardBorder | `#D4C5B7` 14% / `#F3E7D6` 6% | `#5B3A29` 12% / none |
| cardShadow | `0 8 24` black 28% | `0 6 18` `#5B3A29` 8% |
| scrim | `#080A12` 76% | `#3C281E` 42% |
| route slow / steady / fast | `#91B4FE` / `#FFCE29` / `#FF6D0F` | `#5182D5` / `#D9581A` / `#87211C` |
| map / grid / casing | `#1F2638` / `#F3E7D6` 6% / `#171D2B` | `#F3E6CF` / `#5B3A29` 8% / white |
| skeleton / shimmer | `#F3E7D6` 9% / white 7% | `#5B3A29` 10% / white 45% |
| header sky | `#0E1430` → `#1D2546` (55%) → `#171D2B` | `#A6C0FD` → `#CCCCE5` (52%) → `#F4E4C8` |
| splash sky | `#0B1028`, `#1D2546` 50%, `#3E3B66` 72%, `#171D2B` | `#8FB1F9`, `#BFC9EE` 38%, `#FFCF91` 66%, `#F4E4C8` |
| celestial | moon `#EEE1CB`, crater `#D8C9B2`, glow `#F3E7D6` 7% | sun `#FFD762` |
| mesa / hills / dunes / sandDune | `#3E3B66` / `#5C3E36` / `#2C3347` / `#232A3B` | `#C07358` / `#DF8583` / `#FFCF91` / `#F2D6A6` |
| illustration phone / grid | `#222A3D` / `#303A52`, image brightness .9 saturate .92 | `#FBF3E6` / `#EBDAC0` |

### Accessibility deviations from the kit (night)

| Where | Kit | Used | Why |
|---|---|---|---|
| Text on an icon tile (selected drawer label, step numbers) | `#E8957A` (4.16:1) | `#F0A58D` (4.83:1) | 4.5:1 text rule |
| Route finish marker | `#A34A20` (2.55:1 on map) | `#E8957A` | 3:1 graphics rule |
| `ColorScheme.primary` | — | `#E8957A`; the `#A34A20` fill moves to `primaryContainer` and the filled-button theme | Material uses `primary` as text/indicator colour; `#A34A20` is 2.17:1 on the surface |
| Error | not in kit | `#FFB4AB` / onError `#690005` (Material 3 dark) | day `#B3261E` is unreadable on navy |

All night pairs are verified in `test/core/theme/dark_contrast_test.dart`.

### App-shell change (owner: Praveen, `lib/main.dart`)

Not applied in this phase. To enable system light/dark selection, change the `MaterialApp`:

```dart
MaterialApp(
  theme: AppTheme.light(),
  darkTheme: AppTheme.dark(),     // add
  themeMode: AppTheme.themeMode,  // add (ThemeMode.system)
  ...
)
```

Until screens migrate to `context.palette`, enabling this will show dark Material chrome with
some day-coloured screen content, so land it together with (or after) the screen updates.

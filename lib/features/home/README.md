# Home feature (UI kit Revision 5)

Owner: Tharushi
SRS reference: Section 8.4, FR-01 (trigger), FR-61, FR-71, NFR-09, NFR-14

## Public API

```dart
HomeScreen(
  // Unchanged, required:
  onStartRun: ...,          // called once per completed Slide to Start
  onOpenHistory: ...,       // View all, drawer History, and rows if onRunSelected is null
  onOpenPermissions: ...,   // kept; now the fallback for Settings (see below)

  // New, optional:
  recentRuns: <HistoryRun>[...],              // any order; shown newest first
  recentRunsStatus: RecentRunsStatus.ready,   // loading | ready | error
  onRetry: ...,                               // "Try again" in the error state
  onRunSelected: (runId) => ...,              // open Summary for that run
  onOpenSettings: ...,                        // header gear + drawer Settings
  isStartingRun: false,                       // parent's "starting" flag
  startRunEnabled: true,                      // false disables the slider

  // Deprecated (still works):
  lastRun: LastRunSummary(...),               // shown as the only row when recentRuns is empty
)
```

| Change | Notes |
|---|---|
| `lastRun` | Deprecated. Still compiles and still shows (one row, tapping opens History). Use `recentRuns`. `LastRunSummary` is unchanged. |
| `onOpenPermissions` | Still required. Home has no Permissions row any more; it is used for the Settings shortcut and the drawer Settings entry until `onOpenSettings` is supplied. |
| `startRunButtonKey` | Same key, now on the Slide to Start control. |
| New keys | `menuButtonKey`, `settingsButtonKey`, `recentRunsKey`; `RecentRunsCard.viewAllKey`, `retryKey`, `rowKey(i)`, state keys; `SlideToStart.handleKey`. |
| `AppSpacing.heroButtonHeight` | 64 → 72 (Revision 5 slider height). Only Home used it. |

Home never reads the repository or TrackingBridge. The shell loads runs and passes them in. Show `RecentRunsStatus.loading` only while a read is really in progress; never add a delay.

## Slide to Start

`widgets/slide_to_start.dart` is a reusable `SlideToStart(onStart:, enabled:, starting:)`.

- **Drag:** the handle follows the finger anywhere on the 72dp track. On release, at 70% of the travel or more, the run starts. Below 70% the handle snaps back (200 ms; instant with *Remove animations*). Only the release position counts; dragging past 70% and back does not start.
- **Press and hold:** keeping a finger still on the track for 1 s starts the run. A white ring fills around the handle and the hint changes to "Keep holding". Moving past the touch slop or lifting early cancels. The hold keeps its real 1 s even with *Remove animations*.
- **Tap:** does nothing.
- **Screen readers, switch access and keyboard:** one button, "Start run", with a hint. A single TalkBack double tap, switch press, or Enter/Space starts the run.
- **One start only:** every path goes through one latch. After a start the track shows "Starting run" (announced) and ignores input, so `onStart` runs exactly once. It re-arms when:
  - the parent changes `starting` from true to false; or
  - Home becomes visible again after another route covered it (for example, back from Run or Permissions).
- There is no confirmation screen. With permissions already granted, a run starts in two actions: open the app, then slide.

## Drawer

Home's `Scaffold` uses `AppNavigationDrawer(selected: AppDestination.home)`. The header menu button opens it. Back closes it first. Choosing Home only closes it.

# Settings feature (UI kit Revision 5)

Owner: Tharushi
SRS reference: Section 8.4, FR-40, FR-41, NFR-09, NFR-14

## Public API

```dart
SettingsScreen(
  gateway: const PermissionHandlerGateway(), // or a fake in tests
  onBack: ...,               // header Back button
  onOpenHome: ...,           // retained for existing callers
  onOpenHistory: ...,        // retained for existing callers
  onManagePermissions: ...,  // open the existing PermissionsScreen
  appVersion: '1.0.0 (3)',   // optional; real value only, null hides the row
)
```

Keys: `backButtonKey`, `manageButtonKey`, `openAppSettingsKey`, `retryButtonKey`, `checkFailedKey`, `settingsFailedKey`, `versionKey`, `rowKey(SettingsPermissionRow)`.

## What it shows

**Permissions card.** Three rows, each with a `PermissionStatusChip` (`lib/features/shared/permission_status_chip.dart`). Every chip shows an icon and a word, never colour alone.

| Row | Possible chips |
|---|---|
| Precise location | Allowed, Not allowed, Blocked |
| Notifications | Allowed, Not allowed, Blocked |
| Device Location Services | On, Off |
| Any row, while reading | Checking |
| Any row, if the read failed | Unavailable, plus "Couldn't check permissions" and Try again |

Actions:
- **Manage permissions** always calls `onManagePermissions`.
- **Open app settings** appears only when a permission is Blocked, because only Android's app settings page can change a blocked permission. If the page cannot be opened, a message explains how to get there manually.

**About card:**
- "Offline GPS run tracker", with no internet needed;
- "Stored on this phone";
- Version, only when `appVersion` is a non-blank string.

Appearance offers Auto, Light and Dark. The app shell saves this choice in its
application support directory. Google account sign-in and sync appear when the
Firebase account gateway is available.

## Permission behaviour

- Status is only read, through `PermissionGateway.check()` via the existing `PermissionsController`. Settings never calls `requestLocation` or `requestNotification`, so it never shows a system prompt. Prompts happen only on the Permissions screen, after its explanation.
- Status is read once on open and again whenever the app resumes, for example after the user changes something in Android Settings.
- Reads run asynchronously; the rest of the screen stays usable meanwhile.
- A failed read never shows stale values: all rows switch to "Unavailable".

## Integration notes (app shell)

- **Reaching Settings:** pass `onOpenSettings` to `HomeScreen` and push or replace to `SettingsScreen`. Home and History both show a Settings gear.
- **Navigation:** use the bottom bar for main destinations and the header Back button to leave Settings.
- **Back:** `onBack` is the header Back button. System Back is handled by the parent's `Navigator`.
- **Manage permissions:** push `PermissionsScreen(gateway: ..., onContinue: pop, onNotNow: pop)`. Settings refreshes on its own when it is shown again after the user returns from Android Settings.
- **Version:** reading the app version needs `package_info_plus`, which is not a current dependency. Until the team approves it, leave `appVersion` null and the row stays hidden.
- **During a run:** Settings must not be reachable. Active Run has no Settings entry; keep it that way in routing.

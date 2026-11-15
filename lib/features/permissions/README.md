# Permissions feature (FR-40, FR-41)

Owner: Tharushi

## Public API

```dart
PermissionsScreen(
  gateway: const PermissionHandlerGateway(), // or a fake in tests
  onContinue: () {}, // location and notifications are allowed, Location is on
  onNotNow: () {},   // user left without granting
  onBack: () {},     // optional; header Back button (null uses onNotNow)
)
```

Constructor arguments are unchanged apart from the new optional `onBack`. There is no drawer: Permissions is part of a flow.

- The screen explains both permissions first.
- System prompts appear only after the user taps the main button.
- Permissions that are already granted are never requested again.
- The screen re-reads the state when the app resumes, for example after the user returns from Settings.
- The screen does not navigate by itself; the parent decides where to go.

## Steps

The screen checks for problems in this order and shows the first one it finds:

1. Location not allowed → **Continue** the first time (after the explanation); **Allow Location Access** after an ordinary denial
2. Location blocked (permanently denied) → numbered steps and **Open app settings**
3. The phone's Location setting is off → instructions and **Check Again**
4. Notifications not allowed → **Allow Notifications**
5. Notifications blocked → **Open app settings**
6. Everything is ready → **Continue**

The main button and **Not Now** sit in a fixed bar above the Android navigation bar.

## Scenes and illustrations (UI kit Revision 5)

`PermissionsScreen.sceneFor(step, issue)` picks one of three scenes:

| Scene | When | Figures |
|---|---|---|
| `explain` | checking, check failed, location not asked yet, notification steps, ready | `runner_female_running.png` and `runner_male_running.png` |
| `locationDenied` | location denied after asking (ask again), or blocked (steps and Open app settings) | `runner_female_standing.png` and `runner_male_standing.png` |
| `servicesOff` | the phone's Location setting is off | the same standing pair |

- **Assets:** `assets/illustrations/` holds the 1x files (128 px tall) plus `2.0x/`, `3.0x/` and `4.0x/` variants. The folder is registered in `pubspec.yaml`, and Flutter picks the right density.
- **Paths:** the file paths are constants in `RunnerAssets` (`widgets/permission_illustration.dart`).
- **Layout:** `PermissionIllustration` draws the kit's 328 × 160 dp scene and places the figures at the kit's positions:
  - running pair at x 0 and 88;
  - standing pair at x 53 and 104.

  On narrow screens the scene scales down, never up, so both figures stay fully visible.
- **Accessibility:** the artwork is decorative and hidden from screen readers.

## Open integration questions

### Precise vs approximate location (Aadila)

On Android 12+, a user can grant only approximate location. `permission_handler` reports `Permission.location` as granted in that case, so this screen cannot tell the difference.

The tracking service should report this as `PERMISSION_DENIED` (or a dedicated code, which would need agreement on the contract). The Run screen already shows the permission error.

### Opening the Location settings page (Aadila)

`permission_handler` can only open the app's own Settings page. It cannot open the Location settings page. When the phone's Location setting is off, the screen therefore gives instructions and a **Check Again** button.

A shortcut that opens the Location settings page directly would need native support.

### Is the notification permission required? (Praveen)

`onContinue` is offered only when notifications are allowed too. If the team decides runs may start without the notification, the parent can call the Run screen from `onNotNow`, or the readiness rule can be relaxed here.

### Wiring (Praveen)

`main.dart` and the router must:

- Create `PermissionsScreen` with `const PermissionHandlerGateway()`.
- Route to it from Settings' **Manage permissions** (Home no longer has a Permissions row).
- Route to it before a run when location is not ready.

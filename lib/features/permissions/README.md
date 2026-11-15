# Permissions feature (FR-40, FR-41)

Owner: Tharushi

## Public API

```dart
PermissionsScreen(
  gateway: const PermissionHandlerGateway(), // or a fake in tests
  onContinue: () {}, // location and notifications are allowed, Location is on
  onNotNow: () {},   // user left without granting
)
```

- The screen explains both permissions first.
- System prompts appear only after the user taps the main button.
- Permissions that are already granted are never requested again.
- The screen re-reads the state when the app resumes, for example after the user returns from Settings.
- The screen does not navigate by itself; the parent decides where to go.

## Steps

The screen checks for problems in this order and shows the first one it finds:

1. Location not allowed → **Allow Location Access**
2. Location blocked (permanently denied) → **Open Settings**
3. The phone's Location setting is off → instructions and **Check Again**
4. Notifications not allowed → **Allow Notifications**
5. Notifications blocked → **Open Settings**
6. Everything is ready → **Continue**

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
- Route to it from Home's Permissions row.
- Route to it before a run when location is not ready.

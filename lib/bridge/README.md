# bridge

Owner: Aadila  
SRS reference: Section 8.3

This folder contains the Dart-side bridge between Flutter and the native tracking service.

## Files to create (Aadila)

| File | Purpose |
|---|---|
| `tracking_bridge.dart` | Abstract interface (`TrackingBridge`) |
| `native_tracking_bridge.dart` | Real implementation using MethodChannel + EventChannel |
| `mock_tracking_bridge.dart` | Fake 5-minute run for UI development. **Due 2 Nov.** |

## Contract

Use channel names and method names from `lib/core/contract/contract.dart` exclusively.  
Never hardcode string literals for channel or method names.

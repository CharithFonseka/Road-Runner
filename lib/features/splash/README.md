# Splash feature (start-up screen)

Owner: Tharushi
SRS reference: Section 8.4, FR-70, FR-71

## Public API

```dart
const SplashScreen()
```

- Shows the sunrise desert background, the runner icon tile, the name "Road Runner", and a circular loading indicator.
- It is **presentational only**:
  - It has no timer and no fixed delay.
  - It does not navigate and does not decide when start-up has finished.
  - It stays on screen until the parent replaces it.
- **Motion:** the loading arc continuously rotates once per second. When the platform or Flutter accessibility settings request reduced motion (`MediaQuery.disableAnimations`), it continues at one revolution every 2.4 seconds.
- **Screen readers:** the indicator is announced as "Loading Road Runner" and the name is a heading. The artwork is hidden from screen readers.
- **Ancestors:** it needs a `MaterialApp` (or `Theme`, `MediaQuery` and `Directionality`) above it, like every other screen.

## Connecting it to real start-up (Praveen, app shell)

Show the splash only while genuine start-up work is running, and replace it as soon as that work completes. Do not add `Future.delayed` or a minimum display time.

```dart
class RoadRunnerApp extends StatefulWidget { /* ... */ }

class _RoadRunnerAppState extends State<RoadRunnerApp> {
  late final Future<StartupResult> _startup = _initialise();

  Future<StartupResult> _initialise() async {
    // Real work only, for example:
    //   open the database (RunRepository)
    //   bridge.getState()          -> resume a running or paused run (FR-23)
    //   bridge.getUnfinishedRun()  -> offer crash recovery (FR-05)
    //   permissionGateway.check()  -> decide whether to show Permissions first
    return StartupResult(/* ... */);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: FutureBuilder<StartupResult>(
        future: _startup,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SplashScreen();
          }
          if (snapshot.hasError) {
            return /* start-up error screen, or Home with an error state */;
          }
          return /* Home, Active Run (resumed run) or recovery prompt */;
        },
      ),
    );
  }
}
```

Notes:

- **Create the future once,** for example in `initState` or a `late final` field, so rebuilds do not restart start-up.
- **Fast start-ups:** if start-up finishes within a frame or two, the splash may barely appear. That is intended.
- Do not hold completed start-up work open to make the splash visible for a minimum time.
- **When there is nothing to load:** if the shell has no real work at start-up, skip `SplashScreen` and open Home directly.

## Loading-state timing (Praveen, app shell)

The splash and feature screens only render the loading state reported by their
parent. For database or other fast reads, start the operation immediately and
show a feature skeleton only if it is still pending after approximately
300 milliseconds. Cancel that pending UI timer when the operation completes;
never delay the operation or hold a completed result just to show a loader.
The screen itself adds no startup or loading delay.

## Android 12+ native splash (not changed here)

Android shows its own system splash, an icon on a plain background, before Flutter draws its first frame. Changing it needs native resources and possibly a package. Both belong to other owners, so nothing was changed here.

To make the system splash hand over smoothly to this screen:

1. In `android/app/src/main/res/values-v31/styles.xml` (`LaunchTheme`), set:
   - `android:windowSplashScreenBackground` to `#F4E4C8` (sand), or to `#8FB1F9` to match the top of the sky;
   - `android:windowSplashScreenAnimatedIcon` to the launcher icon or a runner vector drawable.
2. Keep `android/app/src/main/res/drawable/launch_background.xml` and `drawable-v21` (Android 11 and lower) on the same background colour.
3. Using the `flutter_native_splash` package instead would need a `pubspec.yaml` change and team approval. The two manual steps above need no new dependency.

The Android 12+ system splash cannot show the full desert scene or the loading indicator. This Flutter screen provides them once the engine is running.

// Road Runner — user-facing strings for all Flutter screens.
// Owner: Tharushi
// SRS reference: Section 8.4, NFR-14
//
// Every piece of text a user can see or hear (including screen-reader
// labels) lives here, so wording is consistent and easy to translate later.
// Screens must not contain string literals for user-facing text.

/// Central store of user-facing text (NFR-14).
class AppStrings {
  AppStrings._();

  // ─── App ────────────────────────────────────────────────────────────────────

  static const String appName = 'Road Runner';

  // ─── Home ───────────────────────────────────────────────────────────────────

  static const String homeTagline = 'Ready for your next run?';
  static const String startRun = 'Start Run';

  static const String lastRunTitle = 'Last Run';
  static const String noRunsTitle = 'No runs yet';
  static const String noRunsMessage = 'Tap Start Run to record your first run.';

  static const String statDistance = 'Distance';
  static const String statDuration = 'Duration';
  static const String statAveragePace = 'Avg pace';

  static const String historyTitle = 'History';
  static const String historySubtitle = 'View your past runs';
  static const String permissionsTitle = 'Permissions';
  static const String permissionsSubtitle = 'Allow location to track your runs';

  static const String homeFooter = 'Lace up and hit the road.';

  // ─── Active Run ─────────────────────────────────────────────────────────────

  static const String runTitle = 'Run';

  static const String runStatusStarting = 'Starting';
  static const String runStatusLive = 'Live';
  static const String runStatusPaused = 'Paused';
  static const String runStatusFinishing = 'Finishing';
  static String runStatusSemantics(String status) => 'Run status: $status';

  /// Badge next to the elapsed time while paused.
  static const String pausedBadge = 'PAUSED';

  static const String statElapsedTime = 'Elapsed time';
  static const String statAveragePaceLong = 'Average pace';
  static const String statSpeed = 'Speed';

  static const String unitKm = 'km';
  static const String unitKmPerHour = 'km/h';
  static const String unitPerKm = '/km';

  static const String gpsLabel = 'GPS';
  static const String gpsSearching = 'Searching';
  static const String gpsWeak = 'Weak';
  static const String gpsGood = 'Good';
  static String gpsSemantics(String quality) => 'GPS signal: $quality';

  static const String pauseRun = 'Pause';
  static const String resumeRun = 'Resume';
  static const String stopRun = 'Stop';

  static const String stopDialogTitle = 'Finish your run?';
  static const String stopDialogMessage =
      'Tracking will stop and your run summary will open next.';
  static const String finishRun = 'Finish Run';
  static const String continueRunning = 'Continue Running';

  static const String errorLocationOff =
      'Location is turned off. Turn it on to track your run.';
  static const String errorPermissionDenied =
      'Road Runner needs location permission to track your run.';
  static const String errorServiceFailed =
      'Tracking is not responding. Please try again.';
  static const String errorPauseFailed =
      "Couldn't pause your run. Please try again.";
  static const String errorResumeFailed =
      "Couldn't resume your run. Please try again.";
  static const String errorStopFailed =
      "Couldn't finish your run. It is still recording. Please try again.";

  static const String startFailedTitle = "Couldn't start your run";
  static const String tryAgain = 'Try Again';
  static const String exitRun = 'Exit';
  static const String dismiss = 'Dismiss';

  // ─── Permissions ────────────────────────────────────────────────────────────

  static const String permissionsScreenTitle = 'Location Permission';
  static const String permissionsIntro =
      'Road Runner needs a few permissions to track your runs accurately, '
      'even while the screen is locked.';

  static const String permissionLocationTitle = 'Precise location';
  static const String permissionLocationReason =
      'Uses GPS to measure your distance, pace and route.';
  static const String permissionNotificationTitle = 'Notifications';
  static const String permissionNotificationReason =
      'Shows your run in a notification so you can follow it from the lock '
      'screen.';
  static const String locationServicesTitle = 'Location services';
  static const String locationServicesReason =
      "Your phone's Location setting must be on for GPS tracking.";

  static const String permissionStatusAllowed = 'Allowed';
  static const String permissionStatusNotAllowed = 'Not allowed';
  static const String permissionStatusBlocked = 'Blocked';
  static const String permissionStatusOff = 'Off';
  static String permissionRowSemantics(String title, String status) =>
      '$title: $status';

  static const String allowLocationAccess = 'Allow Location Access';
  static const String allowNotifications = 'Allow Notifications';
  static const String openSettings = 'Open Settings';
  static const String checkAgain = 'Check Again';
  static const String continueAction = 'Continue';
  static const String notNow = 'Not Now';

  static const String permissionsChecking = 'Checking permissions…';
  static const String permissionsCheckFailed =
      "Couldn't check permissions. Please try again.";
  static const String permissionsReady =
      "You're all set. Road Runner can track your runs.";
  static const String locationDeniedMessage =
      'Location was not allowed. Road Runner needs it to record your runs. '
      'Tap Allow Location Access to try again.';
  static const String locationBlockedMessage =
      'Location is blocked for Road Runner. Tap Open Settings, choose '
      'Permissions > Location, select "Allow only while using the app" and '
      'turn on "Use precise location".';
  static const String locationServicesOffMessage =
      "Your phone's Location is turned off. This is a phone setting, not an "
      'app permission. Swipe down from the top of the screen, turn on '
      'Location, then tap Check Again.';
  static const String notificationNeededMessage =
      'Allow notifications so your run stays visible on the lock screen.';
  static const String notificationDeniedMessage =
      'Notifications were not allowed. Tap Allow Notifications to try again.';
  static const String notificationBlockedMessage =
      'Notifications are blocked for Road Runner. Tap Open Settings, choose '
      'Notifications and turn them on.';
  static const String permissionRequestFailed =
      "Couldn't ask for permission. Please try again.";
  static const String settingsOpenFailed =
      "Couldn't open Settings. Open your phone's Settings, then Apps > "
      'Road Runner > Permissions.';

  static const String permissionsFooter =
      'Your location is used only while tracking your run.';

  static const String stoppedUnresolvedTitle = 'Run stopped';
  static const String stoppedUnresolvedMessage =
      "Tracking was stopped outside this screen, so the run result isn't "
      'available here yet.';
}

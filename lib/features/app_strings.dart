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

  // ─── Splash ─────────────────────────────────────────────────────────────────

  /// Spoken by screen readers for the start-up progress indicator.
  static const String splashLoading = 'Loading Road Runner';

  // ─── Navigation drawer ──────────────────────────────────────────────────────

  /// Screen-reader name of the drawer itself.
  static const String navMenuLabel = 'Main navigation';
  static const String navTagline = 'Offline GPS run tracker';
  static const String navHome = 'Home';
  static const String navHistory = 'History';
  static const String navSettings = 'Settings';
  static const String navGoals = 'Goals & Badges';
  static const String navCloseMenu = 'Close menu';
  static const String navRunNote = 'Not available while a run is recording.';

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

  // Home (Revision 5): header, Recent runs card and Slide to Start.
  static const String homeOpenMenu = 'Open navigation menu';
  static const String homeSettings = 'Settings';
  static const String recentRunsTitle = 'Recent runs';
  static const String planRoute = 'Plan a route';
  static const String routeChooseStart = 'Tap the map to choose a start';
  static const String routeChooseFinish = 'Tap the map to choose a finish';
  static const String routePreviewPrompt = 'Preview your walking route';
  static const String routeSavePrompt = 'Name and save your route';
  static const String routeStartSelected = 'Start selected · Finish needed';
  static const String routeBothSelected = 'Start and finish selected';
  static const String routeServiceUnavailable =
      'Walking route service is not configured.';
  static const String routeName = 'Route name';
  static const String routeClear = 'Clear';
  static const String routeFind = 'Find walking route';
  static const String routeSave = 'Save route';
  static const String routeFindFailed =
      'Could not find a walking route. Check your connection and try again.';
  static const String routeSaveFailed =
      'Could not save this route. Please try again.';
  static const String routeStreetMapLoading = 'Loading street map…';
  static const String summaryComplete = 'Run complete';
  static const String weeklyGoalTitle = 'This week';
  static String weeklyGoalProgress(double distanceKm, double goalKm) =>
      '${distanceKm.toStringAsFixed(1)} of ${goalKm.toStringAsFixed(0)} km goal';
  static const String viewAll = 'View all';
  static const String statPace = 'Pace';
  static const String recentRunsLoading = 'Loading recent runs';
  static const String recentRunsEmptyMessage =
      'Your saved runs will appear here after your first run.';
  static const String recentRunsErrorTitle = 'Couldn’t load your runs';
  static const String recentRunsErrorMessage =
      'Your saved runs are still on this phone. Try loading them again.';
  static const String recentRunsRetry = 'Try again';
  static String recentRunSemantics(
    String date,
    String distance,
    String duration,
    String pace,
  ) => 'Run on $date. Distance $distance, duration $duration, pace $pace.';

  /// Short month names for run dates such as "14 Nov 2026" (UI kit format).
  static const List<String> monthsShort = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static String runDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${monthsShort[d.month - 1]} '
      '${d.year}';

  static const String slideToStart = 'Slide to start';
  static const String slideToStartArrows = '›››';
  static const String slideOrHold = 'or press and hold';
  static const String slideKeepHolding = 'Keep holding';
  static const String slideStarting = 'Starting run';
  static const String startRunSemanticsLabel = 'Start run';
  static const String startRunSemanticsHint =
      'Slide the handle right, or press and hold, to start';

  // ─── Active Run ─────────────────────────────────────────────────────────────

  static const String runTitle = 'Run';

  static const String runStatusStarting = 'Starting';
  static const String runStatusRecording = 'Recording';
  static const String runStatusPaused = 'Paused';
  static const String runStatusFinishing = 'Finishing';
  static String runStatusSemantics(String status) => 'Run status: $status';

  /// Badge next to the elapsed time while paused.
  static const String pausedBadge = 'PAUSED';

  static const String statAveragePaceLong = 'Average pace';
  static const String statCurrentPace = 'Current pace';
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
      'Notifications show live run updates on the lock screen. GPS recording '
      'works without them, so you can allow notifications or continue without '
      'them.';
  static const String notificationDeniedMessage =
      'Notifications were not allowed. GPS recording still works, but '
      'lock-screen live notifications may be unavailable. Try again or '
      'continue without notifications.';
  static const String notificationBlockedMessage =
      'Notifications are blocked. GPS recording still works, but lock-screen '
      'live notifications are unavailable. Open Settings to allow them, or '
      'continue without notifications.';
  static const String continueWithoutNotifications =
      'Continue without notifications';
  static const String permissionRequestFailed =
      "Couldn't ask for permission. Please try again.";
  static const String settingsOpenFailed =
      "Couldn't open Settings. Open your phone's Settings, then Apps > "
      'Road Runner > Permissions.';

  // Permissions, UI kit Revision 5 scenes.
  static const String permissionsBack = 'Back';
  static const String permissionsIntroTitle = 'Before your first run';
  static const String permissionsIntroSubtitle = 'Two quick permissions';
  static const String permissionsIntroHeading =
      'Allow location and notifications';
  static const String permissionsIntroBody =
      'Road Runner asks only after you tap Continue. You can change these '
      'later in Settings.';
  static const String locationDeniedHeader = 'Location permission';
  static const String locationDeniedHeading = 'Location permission denied';
  static const String locationDeniedBody =
      'Road Runner can’t track runs without precise location. Tap Allow '
      'Location Access to be asked again.';
  static const String locationBlockedBody =
      'Road Runner can’t track runs without precise location. Allow it in '
      'app settings.';
  static const String locationBlockedStep1 = 'Open app settings';
  static const String locationBlockedStep2 = 'Tap Permissions, then Location';
  static const String locationBlockedStep3 =
      'Choose “Allow only while using the app” and turn on “Use precise '
      'location”';
  static String stepSemantics(int n, String text) => 'Step $n: $text';
  static const String servicesOffHeader = 'Location services';
  static const String servicesOffHeading = 'Device location is off';
  static const String servicesOffBody =
      'Location services are turned off on this phone, so GPS can’t be used.';
  static const String servicesOffStepTitle = 'Turn on Location';
  static const String servicesOffStepDetail =
      'Use the quick settings tile, or open Settings and turn on Location. '
      'Then tap Check Again.';

  static const String permissionsFooter =
      'Your location is used only while tracking your run.';

  // ─── Settings ───────────────────────────────────────────────────────────────

  static const String settingsTitle = 'Settings';
  static const String settingsSubtitle = 'Permissions and app info';
  static const String settingsBack = 'Back';
  static const String settingsPermissionsSection = 'Permissions';
  static const String settingsAboutSection = 'About Road Runner';
  static const String settingsLocationDetail = 'Tracks your route with GPS';
  static const String settingsNotificationDetail = 'Lock-screen live updates';
  static const String settingsServicesTitle = 'Device Location Services';
  static const String settingsServicesDetail = 'Phone location setting';
  static const String managePermissions = 'Manage permissions';
  static const String openAppSettings = 'Open app settings';
  static const String settingsBlockedHint =
      'A permission is blocked. Only your phone’s app settings can allow it '
      'again.';
  static const String settingsNotificationDeniedHint =
      'GPS runs still work without notifications. Lock-screen live updates '
      'may be unavailable.';
  static const String settingsNotificationBlockedHint =
      'GPS runs still work. Lock-screen live updates are unavailable until '
      'notifications are allowed in app settings.';
  static const String aboutTrackerDetail =
      'Records distance, pace and route with your phone’s GPS. No internet '
      'connection needed.';
  static const String aboutStorageTitle = 'Stored on this phone';
  static const String aboutStorageDetail =
      'Your runs are saved locally on this device.';
  static const String aboutVersionTitle = 'Version';
  static String settingsRowSemantics(
    String title,
    String detail,
    String status,
  ) => '$title: $status. $detail';

  /// Permission status chip labels (plus Allowed / Not allowed / Blocked /
  /// Off above).
  static const String permissionStatusOn = 'On';
  static const String permissionStatusChecking = 'Checking';
  static const String permissionStatusUnavailable = 'Unavailable';

  // ─── Run Summary ────────────────────────────────────────────────────────────

  static const String summaryTitle = 'Run summary';
  static const String summaryBack = 'Back';
  static const String summaryLoading = 'Loading run summary';
  static const String summaryDateUnavailable = 'Date unavailable';
  static String summaryDateTime(String date, String time) => '$date · $time';
  static const String summaryDeleteRun = 'Delete Run';
  static const String summaryDeleteTitle = 'Delete this run?';
  static const String summaryDeleteMessage =
      'This run will be permanently deleted. This action cannot be undone.';
  static const String summaryDeleteCancel = 'Cancel';
  static const String summaryDeleteConfirm = 'Delete';
  static const String summaryDeleting = 'Deleting run';
  static const String summaryDeleteFailed =
      'Could not delete this run. Please check History and try again.';

  static const String statMovingTime = 'Moving time';
  static const String statAverageSpeed = 'Average speed';
  static String statSemantics(String label, String value) => '$label: $value';

  /// Spoken instead of a placeholder such as "--.- km/h".
  static const String statUnavailable = 'not available';

  static const String unitM = 'm';

  static const String routeTitle = 'Your route';
  static const String routeSubtitle = 'Top-down view';
  static const String routeTooShort = 'Route too short to map';
  static const String routeTooShortDetail =
      'Fewer than two distinct GPS points were recorded.';
  static const String routeStart = 'Start';
  static const String routeFinish = 'Finish';
  static const String routeSlower = 'Slower pace';
  static const String routeSteady = 'Steady';
  static const String routeFaster = 'Faster';
  static const String routeGridNote = 'Grid shows scale only';
  static String routeGridSquare(String distance) =>
      'Grid squares are $distance';
  static const String routeGap = 'GPS gap';
  static const String routeNoSpeed = 'Speed colours unavailable for this run';
  static const String routeSemantics =
      'Route map of your run, from the start circle to the finish square.';
  static const String routeSemanticsSpeed =
      'Colours show pace compared with the rest of this run: blue for the '
      'slower third, orange for steady, dark red for the faster third.';
  static String routeSemanticsScale(String distance) => 'Scale bar: $distance.';

  static const String splitsTitle = 'Splits';
  static String splitKm(int km) => '$km km';
  static const String splitFastest = 'FASTEST';
  static String splitSemantics(int km, String pace, bool fastest) =>
      'Kilometre $km: $pace per kilometre${fastest ? ', fastest split' : ''}';
  static const String splitsUnderOneKm = 'Run under 1 km';
  static const String splitsUnderOneKmDetail =
      'Splits appear once you run a full kilometre.';
  static const String splitsUnavailable = 'No splits to show';
  static const String splitsUnavailableDetail =
      'Kilometre splits are not available for this run.';
  static const String splitPartial = 'partial';
  static String splitPartialKm(String km) => '$km km';
  static String splitPartialSemantics(String km, String time) =>
      'Final partial split: $km kilometres in $time';

  static const String backToHome = 'Back to Home';
  static const String viewHistory = 'View History';

  // ─── History ────────────────────────────────────────────────────────────────

  static const String historyHeaderSubtitle = 'Newest first';
  static const String historyFilterLabel = 'Filter runs';
  static const String historyAllRuns = 'All Runs';
  static const String historyThisMonth = 'This Month';
  static const String historyLastMonth = 'Last Month';
  static const String historyTotalTime = 'Total time';
  static const String historyLoading = 'Loading run history';
  static const String historyErrorTitle = 'Could not load history';
  static const String historyErrorMessage = 'Please try again in a moment.';
  static const String historyRetry = 'Try again';
  static const String historyStartRun = 'Start a run';
  static const String historyEmptyTitle = 'No runs yet';
  static const String historyEmptyThisMonthTitle = 'No runs this month';
  static const String historyEmptyLastMonthTitle = 'No runs last month';
  static const String historyEmptyMessage =
      'Every adventure starts with a first step. Finish a run to build your '
      'history.';
  static const String historyEmptyPeriodMessage =
      'Every adventure starts with a first step. Start a run to build your '
      'history.';
  static String historySummaryRunsDistance(int runs, String distance) =>
      '$runs ${runs == 1 ? 'run' : 'runs'} · $distance km';
  static String historyDateTime(String date, String time) => '$date · $time';
  static String historyRunSemantics(
    String date,
    String distance,
    String duration,
    String pace,
  ) =>
      'Run on $date. Distance $distance, duration $duration, '
      'average pace $pace. Opens run summary.';
  static String historyRunCount(int count) =>
      count == 1 ? '1 saved run' : '$count saved runs';

  static const String stoppedUnresolvedTitle = 'Run stopped';
  static const String stoppedUnresolvedMessage =
      "Tracking was stopped outside this screen, so the run result isn't "
      'available here yet.';
}

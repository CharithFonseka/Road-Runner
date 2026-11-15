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
}

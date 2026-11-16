// Road Runner — Settings screen (UI kit Revision 5).
// Owner: Tharushi
// SRS reference: Section 8.4, FR-40, FR-41, NFR-09, NFR-14
//
// Shows the real state of the permissions Road Runner needs and a short
// "About" section. It contains no preference switches: the app has none.
//
// Permission rules:
//   * status is READ only (PermissionGateway.check). Settings never shows a
//     system permission prompt; "Manage permissions" hands over to the
//     Permissions screen, which explains first and then asks;
//   * status is read again when the app resumes (for example after the user
//     changed something in Android Settings);
//   * a failed read shows "Unavailable" and a Try again button.
//
// Navigation is the parent's job (callbacks only, no routes). The drawer
// is attached here; Active Run never offers a way to reach this screen.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../app_strings.dart';
import '../home/widgets/sky_header.dart';
import '../permissions/permission_gateway.dart';
import '../permissions/permissions_controller.dart';
import '../shared/app_navigation_drawer.dart';
import '../shared/permission_status_chip.dart';

/// The three permission rows.
enum SettingsPermissionRow { location, notification, locationServices }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.gateway,
    required this.onBack,
    required this.onOpenHome,
    required this.onOpenHistory,
    required this.onManagePermissions,
    this.appVersion,
  });

  /// Reads permission status and opens the app's system settings page.
  /// Use [PermissionHandlerGateway] in the app and a fake in tests.
  final PermissionGateway gateway;

  /// Header Back button.
  final VoidCallback onBack;

  /// Drawer destinations. Settings itself only closes the drawer.
  final VoidCallback onOpenHome;
  final VoidCallback onOpenHistory;

  /// "Manage permissions": open the existing Permissions screen.
  final VoidCallback onManagePermissions;

  /// Real version text from the app shell (for example "1.0.0 (3)"). Null
  /// or blank hides the Version row; nothing is invented.
  final String? appVersion;

  static const Key backButtonKey = Key('settings.back');
  static const Key menuButtonKey = Key('settings.menu');
  static const Key manageButtonKey = Key('settings.manage');
  static const Key openAppSettingsKey = Key('settings.openAppSettings');
  static const Key retryButtonKey = Key('settings.retry');
  static const Key checkFailedKey = Key('settings.checkFailed');
  static const Key settingsFailedKey = Key('settings.settingsFailed');
  static const Key versionKey = Key('settings.version');
  static Key rowKey(SettingsPermissionRow row) => Key('settings.${row.name}');

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final PermissionsController _controller = PermissionsController(
    gateway: widget.gateway,
  );
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Re-read when the user comes back, e.g. from Android's app settings.
    _lifecycle = AppLifecycleListener(onResume: _controller.refresh);
    unawaited(_controller.refresh());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller.dispose();
    super.dispose();
  }

  PermissionChipStatus _status(SettingsPermissionRow row) {
    final PermissionSnapshot? s = _controller.snapshot;
    if (_controller.issue == PermissionIssue.checkFailed) {
      return PermissionChipStatus.unavailable;
    }
    if (s == null) return PermissionChipStatus.checking;
    switch (row) {
      case SettingsPermissionRow.location:
        return PermissionChipStatus.fromAccess(s.location);
      case SettingsPermissionRow.notification:
        return PermissionChipStatus.fromAccess(s.notification);
      case SettingsPermissionRow.locationServices:
        return PermissionChipStatus.fromServices(
          enabled: s.locationServicesEnabled,
        );
    }
  }

  bool get _anyBlocked {
    final PermissionSnapshot? s = _controller.snapshot;
    if (s == null || _controller.issue == PermissionIssue.checkFailed) {
      return false;
    }
    return s.location == PermissionAccess.permanentlyDenied ||
        s.notification == PermissionAccess.permanentlyDenied;
  }

  bool get _locationBlocked {
    final PermissionSnapshot? s = _controller.snapshot;
    return s?.location == PermissionAccess.permanentlyDenied &&
        _controller.issue != PermissionIssue.checkFailed;
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: palette.background,
      drawer: AppNavigationDrawer(
        selected: AppDestination.settings,
        onOpenHome: widget.onOpenHome,
        onOpenHistory: widget.onOpenHistory,
        onOpenSettings: () {}, // current page: the drawer only closes
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isLandscape =
              constraints.maxWidth > constraints.maxHeight &&
              constraints.maxWidth >= 500;
          if (isLandscape) {
            return _buildLandscape(context, palette, bottomInset);
          }
          return _buildPortrait(context, palette, bottomInset);
        },
      ),
    );
  }

  Widget _buildPortrait(
    BuildContext context,
    AppPalette palette,
    double bottomInset,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Builder(
          builder: (context) => CompactSkyHeader(
            title: AppStrings.settingsTitle,
            subtitle: AppStrings.settingsSubtitle,
            landscapeHeight: 40,
            landscapePainter: DrawerLandscapePainter(palette: palette),
            leading: HeaderIconButton(
              key: SettingsScreen.backButtonKey,
              icon: Icons.arrow_back_rounded,
              tooltip: AppStrings.settingsBack,
              onPressed: widget.onBack,
            ),
            trailing: HeaderIconButton(
              key: SettingsScreen.menuButtonKey,
              icon: Icons.menu_rounded,
              tooltip: AppStrings.homeOpenMenu,
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.medium,
                0,
                AppSpacing.medium,
                AppSpacing.large + bottomInset,
              ),
              children: [
                const _SectionHeading(AppStrings.settingsPermissionsSection),
                _permissionsCard(),
                const _SectionHeading(AppStrings.settingsAboutSection),
                _AboutCard(version: widget.appVersion),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscape(
    BuildContext context,
    AppPalette palette,
    double bottomInset,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Builder(
          builder: (context) => CompactSkyHeader(
            title: AppStrings.settingsTitle,
            subtitle: AppStrings.settingsSubtitle,
            landscapeHeight: 40,
            landscapePainter: DrawerLandscapePainter(palette: palette),
            leading: HeaderIconButton(
              key: SettingsScreen.backButtonKey,
              icon: Icons.arrow_back_rounded,
              tooltip: AppStrings.settingsBack,
              onPressed: widget.onBack,
            ),
            trailing: HeaderIconButton(
              key: SettingsScreen.menuButtonKey,
              icon: Icons.menu_rounded,
              tooltip: AppStrings.homeOpenMenu,
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        Expanded(
          child: SafeArea(
            left: true,
            right: true,
            top: false,
            bottom: false,
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.medium,
                  0,
                  AppSpacing.medium,
                  AppSpacing.large + bottomInset,
                ),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _SectionHeading(
                              AppStrings.settingsPermissionsSection,
                            ),
                            _permissionsCard(),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.medium),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _SectionHeading(
                              AppStrings.settingsAboutSection,
                            ),
                            _AboutCard(version: widget.appVersion),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _permissionsCard() {
    final PermissionIssue? issue = _controller.issue;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PermissionRow(
            key: SettingsScreen.rowKey(SettingsPermissionRow.location),
            icon: Icons.location_on_outlined,
            title: AppStrings.permissionLocationTitle,
            detail: AppStrings.settingsLocationDetail,
            status: _status(SettingsPermissionRow.location),
          ),
          const Divider(height: 1),
          _PermissionRow(
            key: SettingsScreen.rowKey(SettingsPermissionRow.notification),
            icon: Icons.notifications_none_rounded,
            title: AppStrings.permissionNotificationTitle,
            detail: AppStrings.settingsNotificationDetail,
            status: _status(SettingsPermissionRow.notification),
          ),
          const Divider(height: 1),
          _PermissionRow(
            key: SettingsScreen.rowKey(SettingsPermissionRow.locationServices),
            icon: Icons.my_location_rounded,
            title: AppStrings.settingsServicesTitle,
            detail: AppStrings.settingsServicesDetail,
            status: _status(SettingsPermissionRow.locationServices),
          ),
          if (issue == PermissionIssue.checkFailed)
            _Notice(
              key: SettingsScreen.checkFailedKey,
              text: AppStrings.permissionsCheckFailed,
              action: TextButton(
                key: SettingsScreen.retryButtonKey,
                onPressed: _controller.busy ? null : _controller.refresh,
                child: const Text(AppStrings.tryAgain),
              ),
            ),
          if (issue == PermissionIssue.settingsFailed)
            const _Notice(
              key: SettingsScreen.settingsFailedKey,
              text: AppStrings.settingsOpenFailed,
            ),
          if (_controller.snapshot?.notification == PermissionAccess.denied)
            const _Notice(text: AppStrings.settingsNotificationDeniedHint),
          if (_controller.snapshot?.notification ==
                  PermissionAccess.permanentlyDenied &&
              issue != PermissionIssue.settingsFailed)
            const _Notice(text: AppStrings.settingsNotificationBlockedHint),
          if (_locationBlocked && issue != PermissionIssue.settingsFailed)
            const _Notice(text: AppStrings.settingsBlockedHint),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  key: SettingsScreen.manageButtonKey,
                  onPressed: widget.onManagePermissions,
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  label: const Text(AppStrings.managePermissions),
                  style: _outlinedStyle(AppPalette.of(context)),
                ),
                if (_anyBlocked) ...[
                  const SizedBox(height: AppSpacing.itemGap),
                  OutlinedButton.icon(
                    key: SettingsScreen.openAppSettingsKey,
                    onPressed: _controller.busy
                        ? null
                        : _controller.openSettings,
                    icon: const Icon(Icons.open_in_new_rounded, size: 20),
                    label: const Text(AppStrings.openAppSettings),
                    style: _outlinedStyle(AppPalette.of(context)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static ButtonStyle _outlinedStyle(AppPalette palette) =>
      OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        side: BorderSide(color: palette.buttonOutline, width: 1.5),
        backgroundColor: palette.surface,
      );
}

// ─── Pieces ─────────────────────────────────────────────────────────────────

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Semantics(
        header: true,
        label: text,
        excludeSemantics: true,
        child: Text(
          text.toUpperCase(),
          style: AppTextStyles.of(context).caption
              .copyWith(fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: palette.iconTile,
          borderRadius: BorderRadius.all(
            Radius.circular(AppSpacing.radiusTile),
          ),
        ),
        child: Icon(icon, size: 22, color: palette.accent),
      ),
    );
  }
}

TextStyle _rowTitle(BuildContext context) =>
    AppTextStyles.of(context).body
        .copyWith(fontSize: 16, fontWeight: FontWeight.w700, height: 1.3);
TextStyle _rowDetail(BuildContext context) =>
    AppTextStyles.of(context).caption
        .copyWith(fontSize: 13, fontWeight: FontWeight.normal, height: 18 / 13);

/// Tile, title and detail, with the status chip on the right when it fits
/// (at most 45% of the row) and below the text otherwise.
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String detail;
  final PermissionChipStatus status;

  @override
  Widget build(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    return Semantics(
      container: true,
      label: AppStrings.settingsRowSemantics(title, detail, status.label),
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _IconTile(icon),
              const SizedBox(width: 14),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final Widget chip = PermissionStatusChip(status: status);
                    final Widget text = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: _rowTitle(context)),
                        const SizedBox(height: 2),
                        Text(detail, style: _rowDetail(context)),
                      ],
                    );
                    final bool inline =
                        PermissionStatusChip.measureWidth(status, scaler) <=
                        constraints.maxWidth * 0.45;
                    if (inline) {
                      return Row(
                        children: [
                          Expanded(child: text),
                          const SizedBox(width: AppSpacing.small),
                          chip,
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [text, const SizedBox(height: 8), chip],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: AppTextStyles.of(context).body.copyWith(fontSize: 14),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.version});

  final String? version;

  @override
  Widget build(BuildContext context) {
    final String? v = version?.trim();
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AboutRow(
            icon: Icons.directions_run_rounded,
            title: AppStrings.navTagline,
            detail: AppStrings.aboutTrackerDetail,
          ),
          const Divider(height: 1),
          const _AboutRow(
            icon: Icons.smartphone_rounded,
            title: AppStrings.aboutStorageTitle,
            detail: AppStrings.aboutStorageDetail,
          ),
          if (v != null && v.isNotEmpty) ...[
            const Divider(height: 1),
            _AboutRow(
              key: SettingsScreen.versionKey,
              icon: Icons.info_outline_rounded,
              title: AppStrings.aboutVersionTitle,
              detail: v,
            ),
          ],
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _IconTile(icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _rowTitle(context)),
                    const SizedBox(height: 2),
                    Text(detail, style: _rowDetail(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

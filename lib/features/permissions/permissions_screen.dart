// Road Runner — Permissions screen (explain, then ask). UI kit Revision 5.
// Owner: Tharushi
// SRS reference: Section 8.4, FR-40, FR-41, NFR-09, NFR-14
//
// Explains precise location and optional live notifications BEFORE any
// system prompt appears. Prompts only open when the user taps the main
// button. When the app returns from Settings, the state is read again.
//
// Three scenes (see PermissionScene), chosen from the controller's step:
//   * explain        — running figures; explanation and Continue;
//   * locationDenied — standing figures; ordinary denial (ask again) or
//                      blocked (numbered steps + Open app settings);
//   * servicesOff    — standing figures; how to turn Location on, then
//                      Check Again (the gateway cannot open that setting).
//
// Navigation is the parent's job: onContinue when everything is ready,
// onNotNow when the user leaves without granting, onBack for the header
// Back button (falls back to onNotNow). No drawer here.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../app_strings.dart';
import '../home/widgets/sky_header.dart';
import '../shared/app_navigation_drawer.dart' show DrawerLandscapePainter;
import '../shared/permission_status_chip.dart';
import 'permission_gateway.dart';
import 'permissions_controller.dart';
import 'widgets/permission_illustration.dart';

export 'widgets/permission_illustration.dart' show PermissionScene;

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({
    super.key,
    required this.gateway,
    required this.onContinue,
    required this.onNotNow,
    this.onBack,
  });

  /// Reads and requests permissions. Use [PermissionHandlerGateway] in the
  /// app and a fake in tests.
  final PermissionGateway gateway;

  /// Location is ready; continue (e.g. back to Home or into a run).
  final VoidCallback onContinue;

  /// The user chose not to grant permissions now.
  final VoidCallback onNotNow;

  /// Header Back button. Null uses [onNotNow] (leaving without granting).
  final VoidCallback? onBack;

  static const Key primaryButtonKey = Key('permissions.primary');
  static const Key notNowButtonKey = Key('permissions.notNow');
  static const Key messageKey = Key('permissions.message');
  static const Key backButtonKey = Key('permissions.back');
  static const Key continueWithoutNotificationsButtonKey = Key(
    'permissions.continueWithoutNotifications',
  );
  static const Key illustrationKey = Key('permissions.illustration');
  static const Key headingKey = Key('permissions.heading');
  static Key stepKey(int n) => Key('permissions.step.$n');

  /// Scene for a controller state.
  static PermissionScene sceneFor(PermissionStep step, PermissionIssue? issue) {
    if (step == PermissionStep.locationBlocked) {
      return PermissionScene.locationDenied;
    }
    if (step == PermissionStep.needsLocation &&
        issue == PermissionIssue.locationDenied) {
      return PermissionScene.locationDenied;
    }
    if (step == PermissionStep.locationServicesOff) {
      return PermissionScene.servicesOff;
    }
    return PermissionScene.explain;
  }

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  late final PermissionsController _controller;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _controller = PermissionsController(gateway: widget.gateway);
    // Re-read after the user returns from Settings or the quick settings
    // panel. Ignored while a system prompt is open (controller is busy).
    _lifecycle = AppLifecycleListener(onResume: _controller.refresh);
    unawaited(_controller.refresh());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final AppPalette palette = context.palette;
    final PermissionStep step = _controller.step;
    final PermissionIssue? issue = _controller.issue;
    final PermissionScene scene = PermissionsScreen.sceneFor(step, issue);
    final _Action? primary = _primaryAction(step, issue);
    final bool canContinueWithoutNotifications =
        step == PermissionStep.needsNotification ||
        step == PermissionStep.notificationBlocked;
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    final (String header, String? subtitle) = switch (scene) {
      PermissionScene.explain => (
        AppStrings.permissionsIntroTitle,
        AppStrings.permissionsIntroSubtitle,
      ),
      PermissionScene.locationDenied => (AppStrings.locationDeniedHeader, null),
      PermissionScene.servicesOff => (AppStrings.servicesOffHeader, null),
    };
    final (String heading, String body) = switch (scene) {
      PermissionScene.explain => (
        AppStrings.permissionsIntroHeading,
        AppStrings.permissionsIntroBody,
      ),
      PermissionScene.locationDenied => (
        AppStrings.locationDeniedHeading,
        step == PermissionStep.locationBlocked
            ? AppStrings.locationBlockedBody
            : AppStrings.locationDeniedBody,
      ),
      PermissionScene.servicesOff => (
        AppStrings.servicesOffHeading,
        AppStrings.servicesOffBody,
      ),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isLandscape =
            constraints.maxWidth > constraints.maxHeight &&
            constraints.maxWidth >= 500;
        if (isLandscape) {
          return _buildLandscapeContent(
            context,
            palette,
            step,
            issue,
            scene,
            primary,
            canContinueWithoutNotifications,
            header,
            subtitle,
            heading,
            body,
            bottomInset,
            constraints,
          );
        }
        return _buildPortraitContent(
          context,
          palette,
          step,
          issue,
          scene,
          primary,
          canContinueWithoutNotifications,
          header,
          subtitle,
          heading,
          body,
          bottomInset,
        );
      },
    );
  }

  Widget _buildPortraitContent(
    BuildContext context,
    AppPalette palette,
    PermissionStep step,
    PermissionIssue? issue,
    PermissionScene scene,
    _Action? primary,
    bool canContinueWithoutNotifications,
    String header,
    String? subtitle,
    String heading,
    String body,
    double bottomInset,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CompactSkyHeader(
          title: header,
          subtitle: subtitle,
          landscapeHeight: 40,
          landscapePainter: const DrawerLandscapePainter(),
          leading: HeaderIconButton(
            key: PermissionsScreen.backButtonKey,
            icon: Icons.arrow_back_rounded,
            tooltip: AppStrings.permissionsBack,
            onPressed: widget.onBack ?? widget.onNotNow,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.medium,
              AppSpacing.small,
              AppSpacing.medium,
              AppSpacing.medium,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PermissionIllustration(
                  key: PermissionsScreen.illustrationKey,
                  scene: scene,
                ),
                const SizedBox(height: AppSpacing.itemGap),
                Semantics(
                  header: true,
                  child: Text(
                    heading,
                    key: PermissionsScreen.headingKey,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.of(context).heading
                        .copyWith(fontSize: 22, height: 28 / 22),
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    body,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.of(context).body.copyWith(
                      fontSize: 14,
                      height: 20 / 14,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _card(scene, step),
                if (_showMessage(step, issue)) ...[
                  const SizedBox(height: AppSpacing.itemGap),
                  _StatusMessage(
                    key: PermissionsScreen.messageKey,
                    step: step,
                    issue: issue,
                  ),
                ],
                const SizedBox(height: AppSpacing.medium),
                const _Footer(),
              ],
            ),
          ),
        ),
        // Fixed actions, kept above the Android navigation bar.
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.medium,
            AppSpacing.itemGap,
            AppSpacing.medium,
            AppSpacing.medium + bottomInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (primary != null)
                FilledButton.icon(
                  key: PermissionsScreen.primaryButtonKey,
                  onPressed: _controller.busy ? null : primary.onPressed,
                  icon: Icon(primary.icon),
                  label: Text(primary.label),
                ),
              if (primary != null && step != PermissionStep.ready)
                const SizedBox(height: AppSpacing.itemGap),
              if (canContinueWithoutNotifications) ...[
                OutlinedButton(
                  key: PermissionsScreen.continueWithoutNotificationsButtonKey,
                  onPressed: widget.onContinue,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: palette.buttonOutline, width: 1.5),
                    foregroundColor: palette.textPrimary,
                    backgroundColor: palette.isDark
                        ? Colors.transparent
                        : palette.surface,
                  ),
                  child: const Text(AppStrings.continueWithoutNotifications),
                ),
                const SizedBox(height: AppSpacing.itemGap),
              ],
              if (step != PermissionStep.ready)
                OutlinedButton(
                  key: PermissionsScreen.notNowButtonKey,
                  onPressed: widget.onNotNow,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: palette.buttonOutline, width: 1.5),
                    foregroundColor: palette.textPrimary,
                    backgroundColor: palette.isDark
                        ? Colors.transparent
                        : palette.surface,
                  ),
                  child: const Text(AppStrings.notNow),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeContent(
    BuildContext context,
    AppPalette palette,
    PermissionStep step,
    PermissionIssue? issue,
    PermissionScene scene,
    _Action? primary,
    bool canContinueWithoutNotifications,
    String header,
    String? subtitle,
    String heading,
    String body,
    double bottomInset,
    BoxConstraints constraints,
  ) {
    final double leftWidth = math.min(
      320.0,
      (constraints.maxWidth - AppSpacing.medium * 3) * 0.44,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CompactSkyHeader(
          title: header,
          subtitle: subtitle,
          landscapeHeight: 40,
          landscapePainter: const DrawerLandscapePainter(),
          leading: HeaderIconButton(
            key: PermissionsScreen.backButtonKey,
            icon: Icons.arrow_back_rounded,
            tooltip: AppStrings.permissionsBack,
            onPressed: widget.onBack ?? widget.onNotNow,
          ),
        ),
        Expanded(
          child: SafeArea(
            left: true,
            right: true,
            top: false,
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.medium,
                AppSpacing.small,
                AppSpacing.medium,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Column: Illustration + Explanatory Text
                  SizedBox(
                    width: leftWidth,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        bottom: AppSpacing.medium + bottomInset,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PermissionIllustration(
                            key: PermissionsScreen.illustrationKey,
                            scene: scene,
                          ),
                          const SizedBox(height: AppSpacing.small),
                          Semantics(
                            header: true,
                            child: Text(
                              heading,
                              key: PermissionsScreen.headingKey,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.of(context).heading
                                  .copyWith(fontSize: 20, height: 1.2),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              body,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.of(context).body.copyWith(
                                fontSize: 14,
                                height: 20 / 14,
                                color: palette.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.medium),
                  // Right Column: Card + Status Message + Action Buttons + Footer
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        bottom: AppSpacing.medium + bottomInset,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _card(scene, step),
                          if (_showMessage(step, issue)) ...[
                            const SizedBox(height: AppSpacing.itemGap),
                            _StatusMessage(
                              key: PermissionsScreen.messageKey,
                              step: step,
                              issue: issue,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.itemGap),
                          if (canContinueWithoutNotifications) ...[
                            OutlinedButton(
                              key: PermissionsScreen
                                  .continueWithoutNotificationsButtonKey,
                              onPressed: widget.onContinue,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: palette.buttonOutline,
                                  width: 1.5,
                                ),
                                foregroundColor: palette.textPrimary,
                                backgroundColor: palette.isDark
                                    ? Colors.transparent
                                    : palette.surface,
                                minimumSize: const Size.fromHeight(
                                  AppSpacing.buttonHeight,
                                ),
                              ),
                              child: const Text(
                                AppStrings.continueWithoutNotifications,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.itemGap),
                          ],
                          if (step != PermissionStep.ready)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    key: PermissionsScreen.notNowButtonKey,
                                    onPressed: widget.onNotNow,
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: palette.buttonOutline,
                                        width: 1.5,
                                      ),
                                      foregroundColor: palette.textPrimary,
                                      backgroundColor: palette.isDark
                                          ? Colors.transparent
                                          : palette.surface,
                                      minimumSize: const Size.fromHeight(
                                        AppSpacing.buttonHeight,
                                      ),
                                    ),
                                    child: const Text(AppStrings.notNow),
                                  ),
                                ),
                                if (primary != null) ...[
                                  const SizedBox(width: AppSpacing.itemGap),
                                  Expanded(
                                    child: FilledButton.icon(
                                      key: PermissionsScreen.primaryButtonKey,
                                      onPressed: _controller.busy
                                          ? null
                                          : primary.onPressed,
                                      icon: Icon(primary.icon),
                                      label: Text(primary.label),
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size.fromHeight(
                                          AppSpacing.buttonHeight,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            )
                          else if (primary != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 320,
                                ),
                                child: FilledButton.icon(
                                  key: PermissionsScreen.primaryButtonKey,
                                  onPressed: _controller.busy
                                      ? null
                                      : primary.onPressed,
                                  icon: Icon(primary.icon),
                                  label: Text(primary.label),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(
                                      AppSpacing.buttonHeight,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: AppSpacing.small),
                          const _Footer(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The status box is shown when it adds something the scene text does
  /// not already say (progress, success, failures, the notification step).
  bool _showMessage(PermissionStep step, PermissionIssue? issue) {
    if (issue == PermissionIssue.requestFailed ||
        issue == PermissionIssue.settingsFailed ||
        issue == PermissionIssue.notificationDenied) {
      return true;
    }
    switch (step) {
      case PermissionStep.checking:
      case PermissionStep.checkFailed:
      case PermissionStep.needsNotification:
      case PermissionStep.notificationBlocked:
      case PermissionStep.ready:
        return true;
      case PermissionStep.needsLocation:
      case PermissionStep.locationBlocked:
      case PermissionStep.locationServicesOff:
        return false;
    }
  }

  Widget _card(PermissionScene scene, PermissionStep step) {
    final PermissionSnapshot? s = _controller.snapshot;
    switch (scene) {
      case PermissionScene.explain:
        return _InfoCard(
          children: [
            _ReasonRow(
              icon: Icons.location_on_outlined,
              title: AppStrings.permissionLocationTitle,
              reason: AppStrings.permissionLocationReason,
              status: s == null
                  ? null
                  : PermissionChipStatus.fromAccess(s.location),
            ),
            _ReasonRow(
              icon: Icons.notifications_none_rounded,
              title: AppStrings.permissionNotificationTitle,
              reason: AppStrings.permissionNotificationReason,
              status: s == null
                  ? null
                  : PermissionChipStatus.fromAccess(s.notification),
            ),
            if (s != null && !s.locationServicesEnabled)
              const _ReasonRow(
                icon: Icons.location_disabled_rounded,
                title: AppStrings.locationServicesTitle,
                reason: AppStrings.locationServicesReason,
                status: PermissionChipStatus.off,
              ),
          ],
        );
      case PermissionScene.locationDenied:
        if (step == PermissionStep.locationBlocked) {
          return const _InfoCard(
            children: [
              _StepRow(n: 1, text: AppStrings.locationBlockedStep1),
              _StepRow(n: 2, text: AppStrings.locationBlockedStep2),
              _StepRow(n: 3, text: AppStrings.locationBlockedStep3),
            ],
          );
        }
        return const _InfoCard(
          children: [
            _ReasonRow(
              icon: Icons.location_on_outlined,
              title: AppStrings.permissionLocationTitle,
              reason: AppStrings.permissionLocationReason,
              status: PermissionChipStatus.notAllowed,
            ),
          ],
        );
      case PermissionScene.servicesOff:
        return const _InfoCard(
          children: [
            _ReasonRow(
              icon: Icons.location_off_outlined,
              title: AppStrings.servicesOffStepTitle,
              reason: AppStrings.servicesOffStepDetail,
              status: PermissionChipStatus.off,
            ),
          ],
        );
    }
  }

  _Action? _primaryAction(PermissionStep step, PermissionIssue? issue) {
    switch (step) {
      case PermissionStep.checking:
        return null;
      case PermissionStep.checkFailed:
      case PermissionStep.locationServicesOff:
        return _Action(
          AppStrings.checkAgain,
          Icons.refresh_rounded,
          _controller.refresh,
        );
      case PermissionStep.needsLocation:
        // First time: "Continue" after the explanation. After an ordinary
        // denial: ask again, by name.
        return issue == PermissionIssue.locationDenied
            ? _Action(
                AppStrings.allowLocationAccess,
                Icons.location_on_outlined,
                _controller.requestAccess,
              )
            : _Action(
                AppStrings.continueAction,
                Icons.check_rounded,
                _controller.requestAccess,
              );
      case PermissionStep.needsNotification:
        return _Action(
          AppStrings.allowNotifications,
          Icons.notifications_active_outlined,
          _controller.requestAccess,
        );
      case PermissionStep.locationBlocked:
      case PermissionStep.notificationBlocked:
        return _Action(
          AppStrings.openAppSettings,
          Icons.open_in_new_rounded,
          _controller.openSettings,
        );
      case PermissionStep.ready:
        return _Action(
          AppStrings.continueAction,
          Icons.arrow_forward_rounded,
          widget.onContinue,
        );
    }
  }
}

class _Action {
  const _Action(this.label, this.icon, this.onPressed);

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}

// ─── Card rows ──────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({this.icon, this.number});

  final IconData? icon;
  final int? number;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return ExcludeSemantics(
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.iconTile,
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        child: number != null
            ? Text(
                '$number',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: palette.onIconTile,
                ),
              )
            : Icon(icon, size: 20, color: palette.accent),
      ),
    );
  }
}

/// Icon tile, title, reason and (when known) a status chip.
class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.icon,
    required this.title,
    required this.reason,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String reason;
  final PermissionChipStatus? status;

  @override
  Widget build(BuildContext context) {
    final PermissionChipStatus? st = status;
    return Semantics(
      container: true,
      label: st == null
          ? '$title. $reason'
          : '${AppStrings.permissionRowSemantics(title, st.label)}. $reason',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Tile(icon: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.small,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.of(context).body.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      if (st != null) PermissionStatusChip(status: st),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reason,
                    style: AppTextStyles.of(context).caption
                        .copyWith(fontSize: 13, height: 18 / 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Numbered instruction (blocked location).
class _StepRow extends StatelessWidget {
  const _StepRow({required this.n, required this.text});

  final int n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: PermissionsScreen.stepKey(n),
      container: true,
      label: AppStrings.stepSemantics(n, text),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _Tile(number: n),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.of(context).body.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 20 / 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Status message ─────────────────────────────────────────────────────────

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({super.key, required this.step, required this.issue});

  final PermissionStep step;
  final PermissionIssue? issue;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final (String text, _Tone tone) = _message();
    final Color accent = switch (tone) {
      _Tone.info => palette.textSecondary,
      _Tone.success => palette.stat,
      _Tone.problem => palette.error,
    };
    final IconData icon = switch (tone) {
      _Tone.info => Icons.info_outline,
      _Tone.success => Icons.check_circle_outline,
      _Tone.problem => Icons.error_outline,
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.itemGap),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.all(
            Radius.circular(AppSpacing.radiusTile),
          ),
          border: Border.all(color: accent, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (step == PermissionStep.checking)
              const SizedBox.square(
                dimension: 24,
                child: Padding(
                  padding: EdgeInsets.all(2),
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            else
              ExcludeSemantics(child: Icon(icon, color: accent)),
            const SizedBox(width: AppSpacing.small),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.of(context).body.copyWith(
                  fontSize: 15,
                  color: palette.isDark
                      ? palette.textPrimary
                      : AppColors.canyonBrownDeep,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, _Tone) _message() {
    switch (issue) {
      case PermissionIssue.requestFailed:
        return (AppStrings.permissionRequestFailed, _Tone.problem);
      case PermissionIssue.settingsFailed:
        return (AppStrings.settingsOpenFailed, _Tone.problem);
      case PermissionIssue.locationDenied:
        if (step == PermissionStep.needsLocation) {
          return (AppStrings.locationDeniedMessage, _Tone.problem);
        }
      case PermissionIssue.notificationDenied:
        if (step == PermissionStep.needsNotification) {
          return (AppStrings.notificationDeniedMessage, _Tone.problem);
        }
      case PermissionIssue.checkFailed:
      case null:
        break;
    }
    switch (step) {
      case PermissionStep.checking:
        return (AppStrings.permissionsChecking, _Tone.info);
      case PermissionStep.checkFailed:
        return (AppStrings.permissionsCheckFailed, _Tone.problem);
      case PermissionStep.needsLocation:
        return (AppStrings.permissionLocationReason, _Tone.info);
      case PermissionStep.locationBlocked:
        return (AppStrings.locationBlockedMessage, _Tone.problem);
      case PermissionStep.locationServicesOff:
        return (AppStrings.locationServicesOffMessage, _Tone.problem);
      case PermissionStep.needsNotification:
        return (AppStrings.notificationNeededMessage, _Tone.info);
      case PermissionStep.notificationBlocked:
        return (AppStrings.notificationBlockedMessage, _Tone.problem);
      case PermissionStep.ready:
        return (AppStrings.permissionsReady, _Tone.success);
    }
  }
}

enum _Tone { info, success, problem }

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ExcludeSemantics(
          child: Icon(
            Icons.lock_outline,
            size: 16,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.small),
        Flexible(
          child: Text(
            AppStrings.permissionsFooter,
            style: AppTextStyles.of(context).caption
                .copyWith(fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }
}

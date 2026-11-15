// Road Runner — Permissions screen (explain, then ask).
// Owner: Tharushi
// SRS reference: Section 8.4, FR-40, FR-41, NFR-09, NFR-14
//
// Explains why precise location and notifications are needed BEFORE any
// system prompt appears. Prompts only open when the user taps the main
// button. When the app returns from Settings, the state is read again.
//
// Navigation is the parent's job: onContinue when everything is ready,
// onNotNow when the user leaves without granting.

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../app_strings.dart';
import '../home/widgets/icon_tile.dart';
import 'permission_gateway.dart';
import 'permissions_controller.dart';
import 'widgets/permission_illustration.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({
    super.key,
    required this.gateway,
    required this.onContinue,
    required this.onNotNow,
  });

  /// Reads and requests permissions. Use [PermissionHandlerGateway] in the
  /// app and a fake in tests.
  final PermissionGateway gateway;

  /// Everything is ready; continue (e.g. back to Home or into a run).
  final VoidCallback onContinue;

  /// The user chose not to grant permissions now.
  final VoidCallback onNotNow;

  static const Key primaryButtonKey = Key('permissions.primary');
  static const Key notNowButtonKey = Key('permissions.notNow');
  static const Key messageKey = Key('permissions.message');

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
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) => _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final PermissionStep step = _controller.step;
    final _Action? primary = _primaryAction(step);
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: const Text(
              AppStrings.permissionsScreenTitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.heading,
            ),
          ),
          const SizedBox(height: AppSpacing.itemGap),
          const PermissionIllustration(),
          const SizedBox(height: AppSpacing.medium),
          _ReasonsCard(snapshot: _controller.snapshot),
          const SizedBox(height: AppSpacing.medium),
          _StatusMessage(
            key: PermissionsScreen.messageKey,
            step: step,
            issue: _controller.issue,
          ),
          const SizedBox(height: AppSpacing.medium),
          if (primary != null)
            FilledButton.icon(
              key: PermissionsScreen.primaryButtonKey,
              onPressed: _controller.busy ? null : primary.onPressed,
              icon: Icon(primary.icon),
              label: Text(primary.label),
            ),
          if (step != PermissionStep.ready) ...[
            const SizedBox(height: AppSpacing.itemGap),
            OutlinedButton(
              key: PermissionsScreen.notNowButtonKey,
              onPressed: widget.onNotNow,
              child: const Text(AppStrings.notNow),
            ),
          ],
          const SizedBox(height: AppSpacing.medium),
          const _Footer(),
        ],
      ),
    );
  }

  _Action? _primaryAction(PermissionStep step) {
    switch (step) {
      case PermissionStep.checking:
        return null;
      case PermissionStep.checkFailed:
        return _Action(
          AppStrings.checkAgain,
          Icons.refresh,
          _controller.refresh,
        );
      case PermissionStep.needsLocation:
        return _Action(
          AppStrings.allowLocationAccess,
          Icons.location_on_outlined,
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
          AppStrings.openSettings,
          Icons.settings_outlined,
          _controller.openSettings,
        );
      case PermissionStep.locationServicesOff:
        return _Action(
          AppStrings.checkAgain,
          Icons.refresh,
          _controller.refresh,
        );
      case PermissionStep.ready:
        return _Action(
          AppStrings.continueAction,
          Icons.arrow_forward,
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

// ─── Reasons card ───────────────────────────────────────────────────────────

class _ReasonsCard extends StatelessWidget {
  const _ReasonsCard({required this.snapshot});

  final PermissionSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final PermissionSnapshot? s = snapshot;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(AppStrings.permissionsIntro, style: AppTextStyles.body),
            const SizedBox(height: AppSpacing.itemGap),
            _ReasonRow(
              icon: Icons.my_location,
              title: AppStrings.permissionLocationTitle,
              reason: AppStrings.permissionLocationReason,
              status: s == null ? null : _PermissionStatus.of(s.location),
            ),
            const SizedBox(height: AppSpacing.itemGap),
            _ReasonRow(
              icon: Icons.notifications_none,
              title: AppStrings.permissionNotificationTitle,
              reason: AppStrings.permissionNotificationReason,
              status: s == null ? null : _PermissionStatus.of(s.notification),
            ),
            if (s != null && !s.locationServicesEnabled) ...[
              const SizedBox(height: AppSpacing.itemGap),
              const _ReasonRow(
                icon: Icons.location_disabled,
                title: AppStrings.locationServicesTitle,
                reason: AppStrings.locationServicesReason,
                status: _PermissionStatus.off,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Row status, shown with an icon AND a word (never colour alone).
enum _PermissionStatus {
  allowed(
    AppStrings.permissionStatusAllowed,
    Icons.check_circle,
    AppColors.tealDeep,
  ),
  notAllowed(
    AppStrings.permissionStatusNotAllowed,
    Icons.radio_button_unchecked,
    AppColors.canyonBrownMuted,
  ),
  blocked(AppStrings.permissionStatusBlocked, Icons.block, AppColors.error),
  off(AppStrings.permissionStatusOff, Icons.location_off, AppColors.error);

  const _PermissionStatus(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static _PermissionStatus of(PermissionAccess access) {
    switch (access) {
      case PermissionAccess.granted:
        return allowed;
      case PermissionAccess.denied:
        return notAllowed;
      case PermissionAccess.permanentlyDenied:
        return blocked;
    }
  }
}

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
  final _PermissionStatus? status;

  @override
  Widget build(BuildContext context) {
    final _PermissionStatus? st = status;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon),
          const SizedBox(width: AppSpacing.itemGap),
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
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (st != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ExcludeSemantics(
                            child: Icon(st.icon, size: 16, color: st.color),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              st.label,
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                color: st.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Text(reason, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
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
    final (String text, _Tone tone) = _message();
    final Color accent = switch (tone) {
      _Tone.info => AppColors.canyonBrownMuted,
      _Tone.success => AppColors.tealDeep,
      _Tone.problem => AppColors.error,
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
          color: AppColors.sandLight,
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
                style: AppTextStyles.body.copyWith(
                  color: AppColors.canyonBrownDeep,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const ExcludeSemantics(
          child: Icon(
            Icons.lock_outline,
            size: 16,
            color: AppColors.canyonBrownMuted,
          ),
        ),
        const SizedBox(width: AppSpacing.small),
        Flexible(
          child: Text(
            AppStrings.permissionsFooter,
            style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }
}

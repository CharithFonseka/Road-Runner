// Road Runner — permission status chip (UI kit Revision 5, Settings).
// Owner: Tharushi
// SRS reference: Section 8.4, FR-40, FR-41, NFR-09, NFR-14
//
// A small pill showing one permission's state with an icon AND a word, so
// the state never depends on colour alone. Display only: not tappable.

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../app_strings.dart';
import '../permissions/permission_gateway.dart';

/// Every state a Settings permission row can show.
enum PermissionChipStatus {
  /// Permission granted.
  allowed,

  /// Not granted yet; the app may still ask (from the Permissions screen).
  notAllowed,

  /// Blocked: only the app's system settings page can change it.
  blocked,

  /// Device Location Services switched on.
  on,

  /// Device Location Services switched off.
  off,

  /// The status is being read.
  checking,

  /// The status could not be read.
  unavailable;

  static PermissionChipStatus fromAccess(PermissionAccess access) {
    switch (access) {
      case PermissionAccess.granted:
        return allowed;
      case PermissionAccess.denied:
        return notAllowed;
      case PermissionAccess.permanentlyDenied:
        return blocked;
    }
  }

  static PermissionChipStatus fromServices({required bool enabled}) =>
      enabled ? on : off;

  String get label {
    switch (this) {
      case allowed:
        return AppStrings.permissionStatusAllowed;
      case notAllowed:
        return AppStrings.permissionStatusNotAllowed;
      case blocked:
        return AppStrings.permissionStatusBlocked;
      case on:
        return AppStrings.permissionStatusOn;
      case off:
        return AppStrings.permissionStatusOff;
      case checking:
        return AppStrings.permissionStatusChecking;
      case unavailable:
        return AppStrings.permissionStatusUnavailable;
    }
  }

  IconData get icon {
    switch (this) {
      case allowed:
      case on:
        return Icons.check_rounded;
      case notAllowed:
        return Icons.highlight_off_rounded;
      case blocked:
        return Icons.block_rounded;
      case off:
        return Icons.location_off_outlined;
      case checking:
        return Icons.more_horiz_rounded;
      case unavailable:
        return Icons.help_outline_rounded;
    }
  }

  /// Text and icon colour for the active palette.
  Color foregroundFor(AppPalette palette) {
    if (palette.isDark) {
      switch (this) {
        case allowed:
        case on:
          return palette.statLive;
        case notAllowed:
        case blocked:
        case off:
          return palette.error;
        case checking:
        case unavailable:
          return palette.textSecondary;
      }
    }
    switch (this) {
      case allowed:
      case on:
        return AppColors.liveBlue;
      case notAllowed:
        return AppColors.canyonBrownDeep;
      case blocked:
      case off:
        return AppColors.error;
      case checking:
      case unavailable:
        return AppColors.canyonBrown;
    }
  }

  /// Fill drawn over the card colour.
  Color backgroundFor(AppPalette palette) {
    if (palette.isDark) {
      switch (this) {
        case allowed:
        case on:
          return palette.statLiveTint;
        case notAllowed:
        case blocked:
        case off:
          return palette.errorTint;
        case checking:
        case unavailable:
          return palette.hairline;
      }
    }
    switch (this) {
      case allowed:
      case on:
        return AppColors.liveBlue.withValues(alpha: 0.10);
      case notAllowed:
        return AppColors.iconTile;
      case blocked:
      case off:
        return AppColors.error.withValues(alpha: 0.10);
      case checking:
      case unavailable:
        return AppColors.divider;
    }
  }

  /// Light-mode colours retained for existing callers.
  Color get foreground => foregroundFor(AppPalette.light);
  Color get background => backgroundFor(AppPalette.light);
}

class PermissionStatusChip extends StatelessWidget {
  const PermissionStatusChip({super.key, required this.status});

  final PermissionChipStatus status;

  static const double height = 32;
  static const double horizontalPadding = 12;
  static const double iconSize = 16;
  static const double gap = 6;
  static const TextStyle textStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Width the chip needs at [textScaler] (used to decide whether it fits
  /// beside a row's text).
  static double measureWidth(
    PermissionChipStatus status,
    TextScaler textScaler,
  ) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: status.label, style: textStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final double width = painter.width + 2 * horizontalPadding + iconSize + gap;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Semantics(
      label: status.label,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: height),
        padding: const EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 4,
        ),
        decoration: ShapeDecoration(
          color: status.backgroundFor(palette),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.icon, size: iconSize, color: status.foregroundFor(palette)),
            const SizedBox(width: gap),
            Flexible(
              child: Text(
                status.label,
                style: textStyle.copyWith(color: status.foregroundFor(palette)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

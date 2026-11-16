// Road Runner — GPS badge and run-status pill for the Run screen.
// Owner: Tharushi
// SRS reference: Section 4.2, 8.4, NFR-09
//
// Status is always shown with an icon AND words, never colour alone.
// Foregrounds and fills come from the active semantic palette.

import 'package:flutter/material.dart';

import '../../../core/contract/contract.dart';
import '../../../core/theme/app_palette.dart';
import '../active_run_controller.dart';
import '../../app_strings.dart';

/// Rounded chip with an icon and text, read as one [semanticsLabel].
class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.texts,
    required this.foreground,
    required this.semanticsLabel,
    this.background,
    this.outlined = false,
  });

  final IconData icon;
  final List<String> texts;
  final Color foreground;
  final Color? background;
  final bool outlined;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: background,
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            border: outlined ? Border.all(color: foreground, width: 1.5) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: foreground),
              for (final String text in texts) ...[
                const SizedBox(width: 6),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// GPS signal quality: Searching, Weak or Good.
class GpsStatusBadge extends StatelessWidget {
  const GpsStatusBadge({super.key, required this.quality});

  /// kGpsSearching, kGpsWeak or kGpsGood. Unknown values show Searching.
  final String quality;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    switch (quality) {
      case kGpsGood:
        return _StatusChip(
          icon: Icons.gps_fixed,
          texts: const [AppStrings.gpsLabel, AppStrings.gpsGood],
          foreground: palette.statLive,
          background: palette.statLiveTint,
          semanticsLabel: AppStrings.gpsSemantics(AppStrings.gpsGood),
        );
      case kGpsWeak:
        return _StatusChip(
          icon: Icons.warning_amber_rounded,
          texts: const [AppStrings.gpsLabel, AppStrings.gpsWeak],
          foreground: palette.isDark ? palette.gpsWeak : palette.accent,
          outlined: true,
          semanticsLabel: AppStrings.gpsSemantics(AppStrings.gpsWeak),
        );
      default:
        return _StatusChip(
          icon: Icons.gps_not_fixed,
          texts: const [AppStrings.gpsLabel, AppStrings.gpsSearching],
          foreground: palette.textSecondary,
          background: palette.textPrimary.withValues(alpha: 0.08),
          semanticsLabel: AppStrings.gpsSemantics(AppStrings.gpsSearching),
        );
    }
  }
}

/// Run status: Starting, Recording, Paused or Finishing.
class RunStatusPill extends StatelessWidget {
  const RunStatusPill({super.key, required this.phase});

  final RunPhase phase;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    switch (phase) {
      case RunPhase.running:
        return _StatusChip(
          icon: Icons.fiber_manual_record,
          texts: const [AppStrings.runStatusRecording],
          foreground: palette.statLive,
          background: palette.statLiveTint,
          semanticsLabel: AppStrings.runStatusSemantics(
            AppStrings.runStatusRecording,
          ),
        );
      case RunPhase.paused:
        return _StatusChip(
          icon: Icons.pause,
          texts: const [AppStrings.runStatusPaused],
          foreground: palette.accent,
          outlined: true,
          semanticsLabel: AppStrings.runStatusSemantics(
            AppStrings.runStatusPaused,
          ),
        );
      case RunPhase.stopping:
      case RunPhase.finished:
      case RunPhase.stoppedUnresolved:
        return _muted(
          context,
          Icons.flag_outlined,
          AppStrings.runStatusFinishing,
        );
      case RunPhase.starting:
      case RunPhase.startFailed:
        return _muted(
          context,
          Icons.hourglass_empty,
          AppStrings.runStatusStarting,
        );
    }
  }

  Widget _muted(BuildContext context, IconData icon, String text) {
    final AppPalette palette = context.palette;
    return _StatusChip(
      icon: icon,
      texts: [text],
      foreground: palette.textSecondary,
      background: palette.textPrimary.withValues(alpha: 0.08),
      semanticsLabel: AppStrings.runStatusSemantics(text),
    );
  }
}

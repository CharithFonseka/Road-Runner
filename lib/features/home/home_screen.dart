// Road Runner — Home screen.
// Owner: Tharushi
// SRS reference: Section 8.4, FR-01 (trigger), FR-71, NFR-09, NFR-14
//
// Home only displays data and reports taps. It never starts a run or talks
// to TrackingBridge / repositories directly: the app flow (owned by the
// integration shell) supplies [lastRun] and handles the callbacks.

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../app_strings.dart';
import 'last_run_summary.dart';
import 'widgets/last_run_card.dart';
import 'widgets/nav_row.dart';
import 'widgets/sky_header.dart';

/// The first screen: Start Run, the last run, and links to History and
/// Permissions.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    this.lastRun,
    required this.onStartRun,
    required this.onOpenHistory,
    required this.onOpenPermissions,
  });

  /// Most recent saved run, already formatted. Null shows the empty state.
  final LastRunSummary? lastRun;

  /// Called when the user taps Start Run.
  final VoidCallback onStartRun;

  /// Called when the user taps the History row.
  final VoidCallback onOpenHistory;

  /// Called when the user taps the Permissions row.
  final VoidCallback onOpenPermissions;

  /// Key for the Start Run button (used by tests and integration).
  static const Key startRunButtonKey = Key('home_start_run_button');

  /// Font size of the hero button label (UI kit: 22 bold).
  static const double _heroLabelSize = 22;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SkyHeader(
              title: AppStrings.appName,
              subtitle: AppStrings.homeTagline,
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.medium,
                AppSpacing.medium,
                AppSpacing.medium,
                AppSpacing.large + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _startRunButton(),
                  const SizedBox(height: AppSpacing.medium),
                  LastRunCard(lastRun: lastRun),
                  const SizedBox(height: AppSpacing.medium),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          NavRow(
                            icon: Icons.bar_chart_rounded,
                            title: AppStrings.historyTitle,
                            subtitle: AppStrings.historySubtitle,
                            onTap: onOpenHistory,
                          ),
                          const Divider(
                            indent: AppSpacing.medium,
                            endIndent: AppSpacing.medium,
                          ),
                          NavRow(
                            icon: Icons.location_on_outlined,
                            title: AppStrings.permissionsTitle,
                            subtitle: AppStrings.permissionsSubtitle,
                            onTap: onOpenPermissions,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.large),
                  const _Footer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _startRunButton() {
    return SizedBox(
      height: AppSpacing.heroButtonHeight,
      child: FilledButton.icon(
        key: startRunButtonKey,
        onPressed: onStartRun,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.heroButtonHeight),
          textStyle: AppTextStyles.button.copyWith(fontSize: _heroLabelSize),
          elevation: 4,
          shadowColor: AppColors.burntOrangeDeep.withValues(alpha: 0.5),
        ),
        icon: const Icon(Icons.directions_run_rounded, size: 26),
        label: const Text(AppStrings.startRun),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ExcludeSemantics(
          child: Icon(
            Icons.landscape_outlined,
            size: 32,
            color: AppColors.duskPink,
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        Text(
          AppStrings.homeFooter,
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            color: AppColors.canyonBrownMuted,
          ),
        ),
      ],
    );
  }
}

// Road Runner — "Finish your run?" confirmation.
// Owner: Tharushi
// SRS reference: Section 4.2, 8.4, FR-22, NFR-09
//
// Two large full-width buttons, no sliders. Tapping outside or pressing
// Back counts as "Continue Running": only an explicit "Finish Run" stops.

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../app_strings.dart';

/// Builds the confirmation route. Push it with Navigator.push. It completes
/// with true only if the user chose Finish Run.
///
/// The caller keeps the route so it can close the dialog itself if the run
/// ends elsewhere (e.g. stopped from the notification) while it is open.
DialogRoute<bool> buildStopRunDialogRoute(BuildContext context) {
  return DialogRoute<bool>(
    context: context,
    themes: InheritedTheme.capture(
      from: context,
      to: Navigator.of(context).context,
    ),
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    builder: (_) => const StopRunDialog(),
  );
}

class StopRunDialog extends StatelessWidget {
  const StopRunDialog({super.key});

  static const Key finishButtonKey = Key('stopRunDialog.finish');
  static const Key continueButtonKey = Key('stopRunDialog.continue');

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final bool isLandscape = size.width > size.height && size.width >= 500;

    final Widget finishBtn = FilledButton.icon(
      key: finishButtonKey,
      onPressed: () => Navigator.of(context).pop(true),
      icon: const Icon(Icons.flag),
      label: const Text(AppStrings.finishRun),
    );

    final Widget continueBtn = OutlinedButton.icon(
      key: continueButtonKey,
      onPressed: () => Navigator.of(context).pop(false),
      icon: const Icon(Icons.directions_run),
      label: const Text(AppStrings.continueRunning),
    );

    return AlertDialog(
      title: Semantics(
        header: true,
        child: const Text(AppStrings.stopDialogTitle),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(AppStrings.stopDialogMessage),
            const SizedBox(height: AppSpacing.large),
            if (isLandscape)
              Row(
                children: [
                  Expanded(child: continueBtn),
                  const SizedBox(width: AppSpacing.itemGap),
                  Expanded(child: finishBtn),
                ],
              )
            else ...[
              finishBtn,
              const SizedBox(height: AppSpacing.itemGap),
              continueBtn,
            ],
          ],
        ),
      ),
    );
  }
}

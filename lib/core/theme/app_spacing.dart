// Road Runner — spacing tokens.
// Owner: Tharushi
// SRS reference: Section 8.4, NFR-09
//
// All sizes are in logical pixels (dp). Using only these values keeps
// gaps consistent on every screen.

import 'package:flutter/widgets.dart';

/// Spacing and size tokens for the Road Runner design system.
class AppSpacing {
  AppSpacing._();

  /// Small gap — between a label and its value, or an icon and its text.
  static const double small = 8.0;

  /// Medium gap — between related items, e.g. two stat tiles.
  static const double medium = 16.0;

  /// Large gap — between sections of a screen.
  static const double large = 24.0;

  /// Padding around the edge of every screen.
  static const EdgeInsets screenPadding = EdgeInsets.all(medium);

  /// Minimum size of any tappable control (NFR-09: 48dp or larger).
  static const double minTouchTarget = 48.0;
}

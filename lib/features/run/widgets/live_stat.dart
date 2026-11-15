// Road Runner — one live running statistic (label + large value).
// Owner: Tharushi
// SRS reference: Section 8.4, NFR-09
//
// NFR-09: live statistics are never drawn below 32sp. Large values (the
// timer) shrink to fit narrow screens, but stop at the 32sp floor. No
// FittedBox is used, because FittedBox would scale text below 32sp.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';

/// Style of the small unit text after a value ("km", "km/h", "/km").
const TextStyle liveUnitStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  height: 1.2,
  color: AppColors.canyonBrownMuted,
);

/// Width of [value] (+ optional [unit]) laid out on one line.
double measureStatWidth({
  required String value,
  required TextStyle style,
  String? unit,
  required TextScaler textScaler,
}) {
  final TextPainter painter = TextPainter(
    text: _statSpan(value, style, unit),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();
  final double width = painter.width;
  painter.dispose();
  return width;
}

/// Largest font size from [style]'s size down to [minFontSize] at which
/// [template] (+ [unit]) fits in [maxWidth]. Never returns less than
/// [minFontSize].
double fitStatFontSize({
  required String template,
  required TextStyle style,
  String? unit,
  required double maxWidth,
  required TextScaler textScaler,
  double minFontSize = AppTextStyles.minStatFontSize,
}) {
  double size = math.max(style.fontSize ?? minFontSize, minFontSize);
  while (size > minFontSize) {
    final double width = measureStatWidth(
      value: template,
      style: style.copyWith(fontSize: size),
      unit: unit,
      textScaler: textScaler,
    );
    if (width <= maxWidth) return size;
    size = math.max(size - 2, minFontSize);
  }
  return minFontSize;
}

TextSpan _statSpan(
  String value,
  TextStyle style,
  String? unit, {
  bool unitOnNewLine = false,
}) {
  return TextSpan(
    children: [
      TextSpan(text: value, style: style),
      if (unit != null)
        TextSpan(
          text: unitOnNewLine ? '\n$unit' : ' $unit',
          style: liveUnitStyle,
        ),
    ],
  );
}

/// A label above a large live value, read by screen readers as one item
/// ("Distance, 3.42 km").
class LiveStat extends StatelessWidget {
  const LiveStat({
    super.key,
    required this.label,
    required this.value,
    required this.style,
    this.unit,
    this.template,
    this.labelTrailing,
    this.valueKey,
  });

  final String label;
  final String value;
  final String? unit;

  /// Value style. Its font size is the preferred size (never below 32sp).
  final TextStyle style;

  /// Widest expected value, used to pick one stable font size so the text
  /// does not jump as the value changes. Defaults to [value].
  final String? template;

  /// Optional widget after the label, e.g. the PAUSED badge.
  final Widget? labelTrailing;

  /// Key for the value [Text], so tests can find it.
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    return MergeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double fontSize = fitStatFontSize(
            template: template ?? value,
            style: style,
            unit: unit,
            maxWidth: constraints.maxWidth,
            textScaler: scaler,
          );
          final TextStyle valueStyle = style.copyWith(fontSize: fontSize);
          // Even at 32sp, value + unit may not fit on one line (very large
          // system text on a narrow phone). Then the unit moves to its own
          // line, so the number itself is never broken or clipped.
          final bool unitOnNewLine =
              unit != null &&
              measureStatWidth(
                    value: template ?? value,
                    style: valueStyle,
                    unit: unit,
                    textScaler: scaler,
                  ) >
                  constraints.maxWidth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: AppSpacing.small,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(label, style: AppTextStyles.caption),
                  ?labelTrailing,
                ],
              ),
              const SizedBox(height: 4),
              Text.rich(
                _statSpan(
                  value,
                  valueStyle,
                  unit,
                  unitOnNewLine: unitOnNewLine,
                ),
                key: valueKey,
              ),
            ],
          );
        },
      ),
    );
  }
}

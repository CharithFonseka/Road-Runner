import 'package:flutter/material.dart';

import '../../domain/achievements/achievements.dart';

IconData badgeIcon(BadgeType type) => switch (type) {
  BadgeType.firstRun => Icons.directions_run_rounded,
  BadgeType.first5Km => Icons.flag_rounded,
  BadgeType.fastestKm => Icons.bolt_rounded,
  BadgeType.sevenDayStreak => Icons.local_fire_department_rounded,
};

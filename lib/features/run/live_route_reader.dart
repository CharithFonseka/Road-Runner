import 'dart:convert';
import 'dart:io';

import '../../bridge/tracking_bridge.dart';
import '../../core/contract/contract.dart';

/// Reads accepted points from the app-private run file while it is being written.
/// A trailing incomplete line is ignored; subsequent point events keep the map live.
class LiveRouteReader {
  const LiveRouteReader();

  Future<List<TrackingPoint>> read(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return const [];
    final points = <TrackingPoint>[];
    for (final line in await file.readAsLines()) {
      try {
        final raw = jsonDecode(line);
        if (raw is! Map<String, dynamic> ||
            raw[kRunFileKeyKind] != kRunFileKindPoint ||
            raw[kRunFileKeyAccepted] != true) {
          continue;
        }
        final point = TrackingPoint.fromMap({
          kKeySeq: raw[kRunFileKeySeq],
          kKeyLat: raw[kRunFileKeyLat],
          kKeyLon: raw[kRunFileKeyLon],
        });
        if (point != null) points.add(point);
      } on FormatException {
        // The recorder may be writing its last line during this read.
      }
    }
    return points;
  }
}

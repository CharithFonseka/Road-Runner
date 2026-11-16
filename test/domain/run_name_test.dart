// Road Runner — Unit Tests for makeRunName
// Owner: Nadeesha
// SRS reference: Section 8.5

import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/domain/run_name.dart';

void main() {
  group('makeRunName Tests', () {
    test('generates Morning run for hours < 12', () {
      final dt = DateTime(2026, 11, 16, 8, 30);
      expect(makeRunName(dt, null), 'Morning run');
      expect(makeRunName(dt, 'Parramatta'), 'Morning run in Parramatta');
    });

    test('generates Afternoon run for hours 12 to 16', () {
      final dt1 = DateTime(2026, 11, 16, 12, 0);
      final dt2 = DateTime(2026, 11, 16, 16, 59);
      expect(makeRunName(dt1, null), 'Afternoon run');
      expect(makeRunName(dt2, 'Sydney'), 'Afternoon run in Sydney');
    });

    test('generates Evening run for hours >= 17', () {
      final dt1 = DateTime(2026, 11, 16, 17, 0);
      final dt2 = DateTime(2026, 11, 16, 23, 15);
      expect(makeRunName(dt1, null), 'Evening run');
      expect(makeRunName(dt2, 'Manly Beach'), 'Evening run in Manly Beach');
    });
  });
}

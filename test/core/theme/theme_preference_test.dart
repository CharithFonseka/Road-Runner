import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/core/theme/theme_preference.dart';

void main() {
  test('theme choice survives a new preference instance', () async {
    final directory = await Directory.systemTemp.createTemp(
      'road-runner-theme-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final first = ThemePreference(directoryProvider: () async => directory);
    expect(await first.load(), ThemeMode.system);
    await first.save(ThemeMode.dark);
    final reopened = ThemePreference(directoryProvider: () async => directory);
    expect(await reopened.load(), ThemeMode.dark);
    await reopened.save(ThemeMode.light);
    expect(await first.load(), ThemeMode.light);
  });
}

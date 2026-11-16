import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Keeps the runner's appearance choice across app launches.
class ThemePreference {
  ThemePreference({Future<Directory> Function()? directoryProvider})
      : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  static const _fileName = 'appearance.txt';
  final Future<Directory> Function() _directoryProvider;

  Future<File> _file() async => File(
    '${(await _directoryProvider()).path}${Platform.pathSeparator}$_fileName',
  );

  Future<ThemeMode> load() async {
    try {
      final value = (await (await _file()).readAsString()).trim();
      return ThemeMode.values.firstWhere(
        (mode) => mode.name == value,
        orElse: () => ThemeMode.system,
      );
    } catch (_) {
      return ThemeMode.system;
    }
  }

  Future<void> save(ThemeMode mode) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(mode.name, flush: true);
  }
}

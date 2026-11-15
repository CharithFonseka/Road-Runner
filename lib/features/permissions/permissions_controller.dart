// Road Runner — Permissions screen state (explain-then-ask flow).
// Owner: Tharushi
// SRS reference: FR-40, FR-41
//
// Local to the Permissions feature. All requests happen in response to a
// user action (never in build), are guarded against duplicates, and are
// skipped for permissions that are already granted.

import 'package:flutter/foundation.dart';

import 'permission_gateway.dart';

/// What the user needs to do next, in priority order.
enum PermissionStep {
  /// Reading the current state.
  checking,

  /// The state could not be read.
  checkFailed,

  /// Location not allowed yet: explain, then ask.
  needsLocation,

  /// Location blocked: only Settings can fix it.
  locationBlocked,

  /// Permission is fine but the phone's Location setting is off.
  locationServicesOff,

  /// Location ready; notifications not allowed yet.
  needsNotification,

  /// Notifications blocked: only Settings can fix it.
  notificationBlocked,

  /// Everything Road Runner needs is ready.
  ready,
}

/// Problems shown to the user.
enum PermissionIssue {
  checkFailed,
  requestFailed,
  settingsFailed,
  locationDenied,
  notificationDenied,
}

class PermissionsController extends ChangeNotifier {
  PermissionsController({required this.gateway});

  final PermissionGateway gateway;

  PermissionSnapshot? _snapshot;
  PermissionSnapshot? get snapshot => _snapshot;

  bool _busy = false;

  /// True while talking to the system. Actions are ignored meanwhile.
  bool get busy => _busy;

  PermissionIssue? _issue;
  PermissionIssue? get issue => _issue;

  bool _disposed = false;

  PermissionStep get step {
    final PermissionSnapshot? s = _snapshot;
    if (s == null) {
      return _issue == PermissionIssue.checkFailed
          ? PermissionStep.checkFailed
          : PermissionStep.checking;
    }
    switch (s.location) {
      case PermissionAccess.denied:
        return PermissionStep.needsLocation;
      case PermissionAccess.permanentlyDenied:
        return PermissionStep.locationBlocked;
      case PermissionAccess.granted:
        break;
    }
    if (!s.locationServicesEnabled) return PermissionStep.locationServicesOff;
    switch (s.notification) {
      case PermissionAccess.denied:
        return PermissionStep.needsNotification;
      case PermissionAccess.permanentlyDenied:
        return PermissionStep.notificationBlocked;
      case PermissionAccess.granted:
        return PermissionStep.ready;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Runs [action] unless another action is in progress.
  Future<void> _guarded(Future<void> Function() action) async {
    if (_disposed || _busy) return;
    _busy = true;
    _notify();
    try {
      await action();
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Reads the current state (on open, Check Again, and on app resume
  /// after visiting Settings). Never shows a system prompt.
  Future<void> refresh() => _guarded(_refresh);

  Future<void> _refresh() async {
    try {
      _snapshot = await gateway.check();
      if (_issue == PermissionIssue.checkFailed) _issue = null;
    } catch (_) {
      _issue = PermissionIssue.checkFailed;
    }
  }

  /// "Allow" pressed: asks for location, then notifications — only for
  /// permissions that are not granted and can still be asked.
  Future<void> requestAccess() => _guarded(() async {
    final PermissionSnapshot? current = _snapshot;
    if (current == null) return;
    _issue = null;
    try {
      PermissionSnapshot s = current;

      if (s.location == PermissionAccess.denied) {
        final PermissionAccess result = await gateway.requestLocation();
        s = s.copyWith(location: result);
        _snapshot = s;
        if (result == PermissionAccess.denied) {
          _issue = PermissionIssue.locationDenied;
        }
        if (result != PermissionAccess.granted) return;
      }

      if (s.location == PermissionAccess.granted &&
          s.notification == PermissionAccess.denied) {
        final PermissionAccess result = await gateway.requestNotification();
        _snapshot = s.copyWith(notification: result);
        if (result == PermissionAccess.denied) {
          _issue = PermissionIssue.notificationDenied;
        }
      }

      // Re-read so the Location services switch is current too.
      final PermissionSnapshot latest = await gateway.check();
      _snapshot = latest;
    } catch (_) {
      _issue = PermissionIssue.requestFailed;
    }
  });

  /// Opens the app's system Settings page (for blocked permissions).
  Future<void> openSettings() => _guarded(() async {
    _issue = null;
    try {
      final bool opened = await gateway.openAppSettings();
      if (!opened) _issue = PermissionIssue.settingsFailed;
    } catch (_) {
      _issue = PermissionIssue.settingsFailed;
    }
  });

  void clearIssue() {
    if (_issue == null) return;
    _issue = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

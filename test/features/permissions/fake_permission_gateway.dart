// Road Runner — controllable PermissionGateway for tests.
// Owner: Tharushi

import 'dart:async';

import 'package:road_runner/features/permissions/permission_gateway.dart';

class FakePermissionGateway implements PermissionGateway {
  FakePermissionGateway({
    this.location = PermissionAccess.denied,
    this.notification = PermissionAccess.denied,
    this.servicesEnabled = true,
  });

  PermissionAccess location;
  PermissionAccess notification;
  bool servicesEnabled;

  /// What the next system prompt returns (null = grant).
  PermissionAccess? locationAnswer;
  PermissionAccess? notificationAnswer;

  Object? checkError;
  Object? requestError;
  bool settingsOpens = true;

  /// When set, requestLocation waits for it.
  Completer<void>? locationGate;

  int checkCalls = 0;
  int locationRequests = 0;
  int notificationRequests = 0;
  int settingsCalls = 0;

  @override
  Future<PermissionSnapshot> check() async {
    checkCalls++;
    final Object? error = checkError;
    if (error != null) throw error;
    return PermissionSnapshot(
      location: location,
      notification: notification,
      locationServicesEnabled: servicesEnabled,
    );
  }

  @override
  Future<PermissionAccess> requestLocation() async {
    locationRequests++;
    await locationGate?.future;
    final Object? error = requestError;
    if (error != null) throw error;
    location = locationAnswer ?? PermissionAccess.granted;
    return location;
  }

  @override
  Future<PermissionAccess> requestNotification() async {
    notificationRequests++;
    final Object? error = requestError;
    if (error != null) throw error;
    notification = notificationAnswer ?? PermissionAccess.granted;
    return notification;
  }

  @override
  Future<bool> openAppSettings() async {
    settingsCalls++;
    return settingsOpens;
  }
}

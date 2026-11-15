// Road Runner — PermissionsController tests.
// Owner: Tharushi

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/features/permissions/permission_gateway.dart';
import 'package:road_runner/features/permissions/permissions_controller.dart';

import 'fake_permission_gateway.dart';

void main() {
  late FakePermissionGateway gateway;
  late PermissionsController controller;

  void build() => controller = PermissionsController(gateway: gateway);

  setUp(() {
    gateway = FakePermissionGateway();
    build();
  });

  tearDown(() => controller.dispose());

  test('is checking before the first read', () {
    expect(controller.step, PermissionStep.checking);
  });

  group('steps follow the snapshot in priority order', () {
    final Map<String, (FakePermissionGateway, PermissionStep)> cases = {
      'location not allowed': (
        FakePermissionGateway(servicesEnabled: false),
        PermissionStep.needsLocation,
      ),
      'location blocked': (
        FakePermissionGateway(location: PermissionAccess.permanentlyDenied),
        PermissionStep.locationBlocked,
      ),
      'services off (permission fine)': (
        FakePermissionGateway(
          location: PermissionAccess.granted,
          servicesEnabled: false,
        ),
        PermissionStep.locationServicesOff,
      ),
      'notification not allowed': (
        FakePermissionGateway(location: PermissionAccess.granted),
        PermissionStep.needsNotification,
      ),
      'notification blocked': (
        FakePermissionGateway(
          location: PermissionAccess.granted,
          notification: PermissionAccess.permanentlyDenied,
        ),
        PermissionStep.notificationBlocked,
      ),
      'all granted': (
        FakePermissionGateway(
          location: PermissionAccess.granted,
          notification: PermissionAccess.granted,
        ),
        PermissionStep.ready,
      ),
    };
    for (final MapEntry<String, (FakePermissionGateway, PermissionStep)> c
        in cases.entries) {
      test(c.key, () async {
        gateway = c.value.$1;
        controller.dispose();
        build();
        await controller.refresh();
        expect(controller.step, c.value.$2);
      });
    }
  });

  test('check failure is reported and recoverable', () async {
    gateway.checkError = StateError('x');
    await controller.refresh();
    expect(controller.step, PermissionStep.checkFailed);
    gateway.checkError = null;
    await controller.refresh();
    expect(controller.step, PermissionStep.needsLocation);
    expect(controller.issue, isNull);
  });

  test('requestAccess asks location then notification once each', () async {
    await controller.refresh();
    await controller.requestAccess();
    expect(gateway.locationRequests, 1);
    expect(gateway.notificationRequests, 1);
    expect(controller.step, PermissionStep.ready);
  });

  test('already granted permissions are never requested again', () async {
    gateway
      ..location = PermissionAccess.granted
      ..notification = PermissionAccess.granted;
    await controller.refresh();
    await controller.requestAccess();
    expect(gateway.locationRequests, 0);
    expect(gateway.notificationRequests, 0);
  });

  test('location denied stops the flow and reports it', () async {
    gateway.locationAnswer = PermissionAccess.denied;
    await controller.refresh();
    await controller.requestAccess();
    expect(controller.step, PermissionStep.needsLocation);
    expect(controller.issue, PermissionIssue.locationDenied);
    expect(gateway.notificationRequests, 0);
  });

  test('permanent denial moves to the blocked step', () async {
    gateway.locationAnswer = PermissionAccess.permanentlyDenied;
    await controller.refresh();
    await controller.requestAccess();
    expect(controller.step, PermissionStep.locationBlocked);
  });

  test('duplicate requests while busy are ignored', () async {
    await controller.refresh();
    gateway.locationGate = Completer<void>();
    final Future<void> first = controller.requestAccess();
    final Future<void> second = controller.requestAccess();
    await controller.refresh(); // also ignored while busy
    expect(controller.busy, isTrue);
    gateway.locationGate!.complete();
    await Future.wait([first, second]);
    expect(gateway.locationRequests, 1);
    expect(controller.busy, isFalse);
  });

  test('request error is reported', () async {
    await controller.refresh();
    gateway.requestError = StateError('x');
    await controller.requestAccess();
    expect(controller.issue, PermissionIssue.requestFailed);
  });

  test('settings that fail to open are reported', () async {
    gateway.settingsOpens = false;
    await controller.openSettings();
    expect(gateway.settingsCalls, 1);
    expect(controller.issue, PermissionIssue.settingsFailed);
  });
}

// Road Runner — permission access used by the Permissions screen.
// Owner: Tharushi
// SRS reference: Section 3.1, 3.3, FR-40, FR-41
//
// The screen talks only to [PermissionGateway], so tests (and any later
// native implementation) can be swapped in. The default implementation
// uses permission_handler (approved in SRS §3.1). No new platform-channel
// methods are defined here.

import 'package:permission_handler/permission_handler.dart' as ph;

/// Access state of one runtime permission.
enum PermissionAccess {
  /// Allowed.
  granted,

  /// Not allowed yet; the app may still ask.
  denied,

  /// Blocked: Android will not show the prompt again. Only the app's
  /// system Settings page can change it.
  permanentlyDenied,
}

/// Everything the Permissions screen needs to know at one moment.
class PermissionSnapshot {
  const PermissionSnapshot({
    required this.location,
    required this.notification,
    required this.locationServicesEnabled,
  });

  /// Precise location (ACCESS_FINE_LOCATION).
  final PermissionAccess location;

  /// Notifications (POST_NOTIFICATIONS, Android 13+). Reported as granted
  /// on older Android versions, where no runtime permission exists.
  final PermissionAccess notification;

  /// Device-wide Location setting (GPS switch), separate from permission.
  final bool locationServicesEnabled;

  PermissionSnapshot copyWith({
    PermissionAccess? location,
    PermissionAccess? notification,
    bool? locationServicesEnabled,
  }) {
    return PermissionSnapshot(
      location: location ?? this.location,
      notification: notification ?? this.notification,
      locationServicesEnabled:
          locationServicesEnabled ?? this.locationServicesEnabled,
    );
  }
}

/// Reads and requests the permissions Road Runner needs.
abstract class PermissionGateway {
  /// Current state. Never shows a system prompt.
  Future<PermissionSnapshot> check();

  /// Shows the system location prompt and returns the result.
  Future<PermissionAccess> requestLocation();

  /// Shows the system notification prompt and returns the result.
  Future<PermissionAccess> requestNotification();

  /// Opens this app's page in system Settings. Returns false if it could
  /// not be opened.
  Future<bool> openAppSettings();
}

/// [PermissionGateway] backed by the permission_handler package.
class PermissionHandlerGateway implements PermissionGateway {
  const PermissionHandlerGateway();

  @override
  Future<PermissionSnapshot> check() async {
    final ph.PermissionStatus location = await ph.Permission.location.status;
    final ph.PermissionStatus notification =
        await ph.Permission.notification.status;
    final ph.ServiceStatus service = await ph.Permission.location.serviceStatus;
    return PermissionSnapshot(
      location: _map(location),
      notification: _map(notification),
      // notApplicable (no GPS hardware) is treated as "not off"; tracking
      // will then report its own error.
      locationServicesEnabled: service != ph.ServiceStatus.disabled,
    );
  }

  @override
  Future<PermissionAccess> requestLocation() async {
    await ph.Permission.location.request();
    // Read the actual permission after Android's prompt. The prompt result
    // alone must not mark approximate access as ready for GPS tracking.
    return _map(await ph.Permission.location.status);
  }

  @override
  Future<PermissionAccess> requestNotification() async =>
      _map(await ph.Permission.notification.request());

  @override
  Future<bool> openAppSettings() => ph.openAppSettings();

  static PermissionAccess _map(ph.PermissionStatus status) {
    switch (status) {
      case ph.PermissionStatus.granted:
      case ph.PermissionStatus.limited:
      case ph.PermissionStatus.provisional:
        return PermissionAccess.granted;
      case ph.PermissionStatus.permanentlyDenied:
      case ph.PermissionStatus.restricted:
        return PermissionAccess.permanentlyDenied;
      case ph.PermissionStatus.denied:
        return PermissionAccess.denied;
    }
  }
}

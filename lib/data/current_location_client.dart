import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

/// Reads one foreground location fix without starting a run or tracking.
class CurrentLocationClient {
  const CurrentLocationClient();

  static const MethodChannel _channel = MethodChannel('roadrunner/location');

  Future<LatLng?> currentLocation() async {
    final position = await _channel.invokeMapMethod<String, dynamic>(
      'getCurrentLocation',
    );
    final latitude = (position?['latitude'] as num?)?.toDouble();
    final longitude = (position?['longitude'] as num?)?.toDouble();
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return null;
    }
    return LatLng(latitude, longitude);
  }
}

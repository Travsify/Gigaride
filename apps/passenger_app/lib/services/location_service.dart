import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  static const LatLng defaultLagosLocation = LatLng(6.5244, 3.3792);

  /// In-memory cache of the user's latest resolved coordinates
  static LatLng? lastKnownUserLocation;

  /// Check and request location permission.
  static Future<bool> requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Instant lookup of device's last known position (0ms delay)
  static Future<LatLng?> getLastKnownLocation() async {
    if (lastKnownUserLocation != null) {
      return lastKnownUserLocation;
    }
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null) {
        final loc = LatLng(pos.latitude, pos.longitude);
        lastKnownUserLocation = loc;
        return loc;
      }
    } catch (_) {}
    return null;
  }

  /// Get current user device location with instant fallback to last known position
  static Future<LatLng> getCurrentLocation() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        return lastKnownUserLocation ?? defaultLagosLocation;
      }

      // Check last known position first
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        lastKnownUserLocation = LatLng(lastPos.latitude, lastPos.longitude);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final loc = LatLng(position.latitude, position.longitude);
      lastKnownUserLocation = loc;
      return loc;
    } catch (_) {
      return lastKnownUserLocation ?? defaultLagosLocation;
    }
  }

  /// Stream of position updates for live tracking
  static Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3, // Every 3 meters
      ),
    );
  }
}

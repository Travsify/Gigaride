import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  static const LatLng defaultLagosLocation = LatLng(6.5244, 3.3792);

  /// In-memory cache of the driver's latest resolved coordinates
  static LatLng? lastKnownDriverLocation;

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

  /// Instant lookup of driver's last known position (0ms delay)
  static Future<LatLng?> getLastKnownLocation() async {
    if (lastKnownDriverLocation != null) {
      return lastKnownDriverLocation;
    }
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null) {
        final loc = LatLng(pos.latitude, pos.longitude);
        lastKnownDriverLocation = loc;
        return loc;
      }
    } catch (_) {}
    return null;
  }

  /// Get current driver device location with instant fallback to last known position
  static Future<LatLng> getCurrentLocation() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        return lastKnownDriverLocation ?? defaultLagosLocation;
      }

      // Check last known position first
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        lastKnownDriverLocation = LatLng(lastPos.latitude, lastPos.longitude);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final loc = LatLng(position.latitude, position.longitude);
      lastKnownDriverLocation = loc;
      return loc;
    } catch (_) {
      return lastKnownDriverLocation ?? defaultLagosLocation;
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

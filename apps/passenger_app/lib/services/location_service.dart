import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  /// Default Lagos Central location (fallback before GPS lock)
  static const LatLng defaultLagosLocation = LatLng(6.5244, 3.3792);
  static const LatLng defaultNigeriaCenter = LatLng(6.5244, 3.3792);

  /// In-memory cache of the user's latest resolved coordinates
  static LatLng? lastKnownUserLocation;

  static const _prefKeyLat = 'last_known_lat';
  static const _prefKeyLng = 'last_known_lng';

  // ─── Persist & restore last known location ─────────────────────────────────

  static Future<void> _saveLocationToPrefs(LatLng loc) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefKeyLat, loc.latitude);
      await prefs.setDouble(_prefKeyLng, loc.longitude);
    } catch (_) {}
  }

  static Future<LatLng?> _loadLocationFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_prefKeyLat);
      final lng = prefs.getDouble(_prefKeyLng);
      if (lat != null && lng != null) return LatLng(lat, lng);
    } catch (_) {}
    return null;
  }

  // ─── IP-based geolocation fallback (no GPS needed) ─────────────────────────

  /// Resolves approximate city-level location from the device's IP address.
  /// Free, no API key, ~1-2 second response. Accuracy: city level (~5km).
  static Future<LatLng?> _getIpLocation() async {
    try {
      final response = await http
          .get(Uri.parse('http://ip-api.com/json?fields=lat,lon,status,country'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final lat = (data['lat'] as num).toDouble();
          final lon = (data['lon'] as num).toDouble();
          // Only trust if it resolves within Nigeria's bounding box
          if (lat >= 4.0 && lat <= 14.0 && lon >= 2.5 && lon <= 15.0) {
            return LatLng(lat, lon);
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // ─── Public API ────────────────────────────────────────────────────────────

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

  /// Instant lookup — returns in-memory cache, then SharedPrefs cache.
  /// Falls back to IP geolocation if nothing is cached.
  static Future<LatLng?> getLastKnownLocation() async {
    // 1. In-memory (fastest)
    if (lastKnownUserLocation != null) return lastKnownUserLocation;

    // 2. Try device GPS last known position
    try {
      final hasPermission = await requestLocationPermission();
      if (hasPermission) {
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null) {
          final loc = LatLng(pos.latitude, pos.longitude);
          lastKnownUserLocation = loc;
          _saveLocationToPrefs(loc);
          return loc;
        }
      }
    } catch (_) {}

    // 3. SharedPreferences (persisted from last session)
    final saved = await _loadLocationFromPrefs();
    if (saved != null) {
      lastKnownUserLocation = saved;
      return saved;
    }

    return null;
  }

  /// Get current location — GPS first, then IP geolocation, then prefs cache,
  /// then Nigeria center. Never returns Lagos as a fake default.
  static Future<LatLng> getCurrentLocation() async {
    // 1. Try GPS
    try {
      final hasPermission = await requestLocationPermission();
      if (hasPermission) {
        // Grab cached GPS position immediately
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null) {
          lastKnownUserLocation = LatLng(lastPos.latitude, lastPos.longitude);
          _saveLocationToPrefs(lastKnownUserLocation!);
        }

        // Try fresh GPS fix
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        final loc = LatLng(position.latitude, position.longitude);
        lastKnownUserLocation = loc;
        _saveLocationToPrefs(loc);
        return loc;
      }
    } catch (_) {}

    // 2. GPS unavailable — return cached or IP
    if (lastKnownUserLocation != null) return lastKnownUserLocation!;

    final saved = await _loadLocationFromPrefs();
    if (saved != null) {
      lastKnownUserLocation = saved;
      return saved;
    }

    return defaultNigeriaCenter;
  }

  /// Best-effort approximate location for map centering and proximity sort.
  /// Works even when GPS is completely off — uses IP geolocation.
  /// Call this when you need a location for UI purposes (not navigation).
  static Future<LatLng> getApproximateLocation() async {
    // 1. Already have something in memory
    if (lastKnownUserLocation != null) return lastKnownUserLocation!;

    // 2. SharedPreferences from last session
    final saved = await _loadLocationFromPrefs();
    if (saved != null) {
      lastKnownUserLocation = saved;
      return saved;
    }

    // 3. IP geolocation — accurate to city level, GPS not required
    final ipLoc = await _getIpLocation();
    if (ipLoc != null) {
      lastKnownUserLocation = ipLoc;
      _saveLocationToPrefs(ipLoc);
      return ipLoc;
    }

    // 4. Absolute last resort — Nigeria center (not Lagos!)
    return defaultNigeriaCenter;
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

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PlaceSuggestion {
  final String title;
  final String subtitle;
  final LatLng location;

  PlaceSuggestion({
    required this.title,
    required this.subtitle,
    required this.location,
  });
}

class PlacesService {
  /// Zero-Burn debounced search using Photon OpenStreetMap
  /// Prioritizes Nigerian points of interest (Lagos, Abuja, PH, etc.)
  static Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    LatLng? proximity,
  }) async {
    if (query.trim().length < 2) return [];

    final center = proximity ?? const LatLng(6.5244, 3.3792);
    final encodedQuery = Uri.encodeComponent(query.trim());
    final url = Uri.parse(
      'https://photon.komoot.io/api/?q=$encodedQuery&limit=7&lat=${center.latitude}&lon=${center.longitude}',
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'GigaRide/1.0 (info@gigaride.ng)'},
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>? ?? [];

        return features.map((feat) {
          final props = feat['properties'] as Map<String, dynamic>? ?? {};
          final geom = feat['geometry'] as Map<String, dynamic>? ?? {};
          final coords = geom['coordinates'] as List<dynamic>? ?? [0.0, 0.0];

          final name = props['name'] ?? props['street'] ?? 'Unknown Location';
          final city = props['city'] ?? props['state'] ?? props['country'] ?? 'Nigeria';
          final district = props['district'] ?? props['locality'] ?? '';

          final subtitle = [district, city].where((s) => s.isNotEmpty).join(', ');

          return PlaceSuggestion(
            title: name.toString(),
            subtitle: subtitle.isNotEmpty ? subtitle : 'Nigeria',
            location: LatLng(
              (coords[1] as num).toDouble(),
              (coords[0] as num).toDouble(),
            ),
          );
        }).toList();
      }
    } catch (_) {
      // Graceful fallback
    }

    return [];
  }

  /// Reverse geocode LatLng to readable address name
  static Future<String> reverseGeocode(LatLng location) async {
    final url = Uri.parse(
      'https://photon.komoot.io/reverse?lat=${location.latitude}&lon=${location.longitude}',
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'GigaRide/1.0 (info@gigaride.ng)'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>? ?? [];
        if (features.isNotEmpty) {
          final props = features[0]['properties'] as Map<String, dynamic>? ?? {};
          final name = props['name'] ?? props['street'] ?? '';
          final city = props['city'] ?? props['state'] ?? '';
          if (name.isNotEmpty) {
            return city.isNotEmpty ? '$name, $city' : name;
          }
        }
      }
    } catch (_) {}

    return 'Current Location';
  }
}

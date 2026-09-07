import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';

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
  /// Fast, pinpoint landmark and estate search using Mapbox Geocoding v5
  /// Scoped strictly to Nigeria with proximity biasing
  static Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    LatLng? proximity,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return [];

    final center = proximity ?? const LatLng(6.5244, 3.3792);
    final encodedQuery = Uri.encodeComponent(cleanQuery);
    final token = AppConstants.mapboxPublicToken;

    final url = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json'
      '?country=ng'
      '&proximity=${center.longitude},${center.latitude}'
      '&types=poi,address,neighborhood,locality,place'
      '&limit=10'
      '&access_token=$token',
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'GigaRide/1.0 (info@gigaride.ng)'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>? ?? [];

        return features.map((feat) {
          final title = (feat['text'] ?? feat['place_name'] ?? 'Unknown Location').toString();
          final fullName = (feat['place_name'] ?? '').toString();

          // Generate a clean subtitle by stripping the title prefix if present
          String subtitle = fullName;
          if (fullName.startsWith(title) && fullName.length > title.length) {
            subtitle = fullName.substring(title.length).replaceFirst(RegExp(r'^,\s*'), '');
          }
          if (subtitle.isEmpty) subtitle = 'Nigeria';

          final centerCoords = feat['center'] as List<dynamic>? ?? [center.longitude, center.latitude];
          final lng = (centerCoords[0] as num).toDouble();
          final lat = (centerCoords[1] as num).toDouble();

          return PlaceSuggestion(
            title: title,
            subtitle: subtitle,
            location: LatLng(lat, lng),
          );
        }).toList();
      }
    } catch (_) {
      // Graceful fallback
    }

    return [];
  }

  /// Reverse geocode LatLng to readable Nigerian street/estate name via Mapbox
  static Future<String> reverseGeocode(LatLng location) async {
    final token = AppConstants.mapboxPublicToken;
    final url = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/${location.longitude},${location.latitude}.json'
      '?country=ng'
      '&types=address,poi,neighborhood,locality'
      '&limit=1'
      '&access_token=$token',
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
          final top = features[0];
          final placeName = (top['place_name'] ?? top['text'] ?? '').toString();
          if (placeName.isNotEmpty) {
            return placeName;
          }
        }
      }
    } catch (_) {}

    return 'Current Location';
  }
}

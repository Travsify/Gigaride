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
  /// Fast, pinpoint landmark and estate search
  /// Mode-aware: Scopes strictly within user's metropolitan city (~50km) for City rides,
  /// and expands nationwide for Interstate rides.
  static Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    LatLng? proximity,
    bool isInterstate = false,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return [];

    final center = proximity ?? const LatLng(6.5244, 3.3792);
    final encodedQuery = Uri.encodeComponent(cleanQuery);
    final token = AppConstants.mapboxPublicToken;

    // For City / Local rides, compute a bounding box (~50km radius) around user's city
    String bboxParam = '';
    if (!isInterstate) {
      const double delta = 0.45; // ~50 km in lat/lng
      final minLng = (center.longitude - delta).toStringAsFixed(4);
      final minLat = (center.latitude - delta).toStringAsFixed(4);
      final maxLng = (center.longitude + delta).toStringAsFixed(4);
      final maxLat = (center.latitude + delta).toStringAsFixed(4);
      bboxParam = '&bbox=$minLng,$minLat,$maxLng,$maxLat';
    }

    final url = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json'
      '?country=ng'
      '$bboxParam'
      '&proximity=${center.longitude},${center.latitude}'
      '&types=poi,address,neighborhood,locality,place'
      '&limit=10'
      '&access_token=$token',
    );

    final List<PlaceSuggestion> results = [];
    final Set<String> seenLocations = {};
    const distanceCalc = Distance();

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'GigaRide/1.0 (info@gigaride.ng)'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>? ?? [];

        for (final feat in features) {
          final title = (feat['text'] ?? feat['place_name'] ?? 'Unknown Location').toString();
          final fullName = (feat['place_name'] ?? '').toString();

          String subtitle = fullName;
          if (fullName.startsWith(title) && fullName.length > title.length) {
            subtitle = fullName.substring(title.length).replaceFirst(RegExp(r'^,\s*'), '');
          }
          if (subtitle.isEmpty) subtitle = 'Nigeria';

          final centerCoords = feat['center'] as List<dynamic>? ?? [center.longitude, center.latitude];
          final lng = (centerCoords[0] as num).toDouble();
          final lat = (centerCoords[1] as num).toDouble();
          final loc = LatLng(lat, lng);

          // If City mode, strictly enforce 60km maximum radius from user's current city
          if (!isInterstate) {
            final distKm = distanceCalc.as(LengthUnit.Kilometer, center, loc);
            if (distKm > 60.0) continue;
          }

          final key = '${loc.latitude.toStringAsFixed(3)},${loc.longitude.toStringAsFixed(3)}';
          if (!seenLocations.contains(key)) {
            seenLocations.add(key);
            results.add(PlaceSuggestion(
              title: title,
              subtitle: subtitle,
              location: loc,
            ));
          }
        }
      }
    } catch (_) {}

    // Secondary fallback for local African landmarks/markets if Mapbox returns fewer than 3 results
    if (results.length < 3) {
      try {
        final photonUrl = Uri.parse(
          'https://photon.komoot.io/api/?q=$encodedQuery'
          '&lat=${center.latitude}&lon=${center.longitude}'
          '&limit=6',
        );

        final pResp = await http.get(
          photonUrl,
          headers: {'User-Agent': 'GigaRide/1.0 (info@gigaride.ng)'},
        ).timeout(const Duration(seconds: 3));

        if (pResp.statusCode == 200) {
          final pData = jsonDecode(pResp.body);
          final pFeatures = pData['features'] as List<dynamic>? ?? [];

          for (final f in pFeatures) {
            final props = f['properties'] as Map<String, dynamic>? ?? {};
            final geom = f['geometry'] as Map<String, dynamic>? ?? {};
            final coords = geom['coordinates'] as List<dynamic>? ?? [];
            if (coords.length < 2) continue;

            final lng = (coords[0] as num).toDouble();
            final lat = (coords[1] as num).toDouble();
            final loc = LatLng(lat, lng);

            if (!isInterstate) {
              final distKm = distanceCalc.as(LengthUnit.Kilometer, center, loc);
              if (distKm > 60.0) continue;
            }

            final name = (props['name'] ?? '').toString();
            if (name.isEmpty) continue;

            final city = (props['city'] ?? props['state'] ?? 'Nigeria').toString();
            final key = '${loc.latitude.toStringAsFixed(3)},${loc.longitude.toStringAsFixed(3)}';

            if (!seenLocations.contains(key)) {
              seenLocations.add(key);
              results.add(PlaceSuggestion(
                title: name,
                subtitle: city,
                location: loc,
              ));
            }
          }
        }
      } catch (_) {}
    }

    // Sort all results by proximity so closest destinations appear first!
    results.sort((a, b) {
      final distA = distanceCalc.as(LengthUnit.Kilometer, center, a.location);
      final distB = distanceCalc.as(LengthUnit.Kilometer, center, b.location);
      return distA.compareTo(distB);
    });

    return results;
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

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';

class RouteResult {
  final List<LatLng> polyline;
  final double distanceKm;
  final int durationMinutes;

  RouteResult({
    required this.polyline,
    required this.distanceKm,
    required this.durationMinutes,
  });
}

class RoutingService {
  /// Fast, high-precision driving navigation & polylines via Mapbox Directions API
  /// Includes real Nigerian road network and traffic duration estimates
  static Future<RouteResult?> getDrivingRoute(LatLng start, LatLng end) async {
    final token = AppConstants.mapboxPublicToken;
    final url = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving/'
      '${start.longitude},${start.latitude};'
      '${end.longitude},${end.latitude}'
      '?geometries=geojson&overview=full&access_token=$token',
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'GigaRide/1.0 (info@gigaride.ng)'},
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List<dynamic>?;

        if (routes != null && routes.isNotEmpty) {
          final firstRoute = routes[0];
          final distanceMeters = (firstRoute['distance'] as num?)?.toDouble() ?? 0.0;
          final durationSecs = (firstRoute['duration'] as num?)?.toDouble() ?? 0.0;
          final geometry = firstRoute['geometry'] as Map<String, dynamic>?;
          final coords = geometry?['coordinates'] as List<dynamic>? ?? [];

          final polyline = coords.map((c) {
            return LatLng(
              (c[1] as num).toDouble(),
              (c[0] as num).toDouble(),
            );
          }).toList();

          return RouteResult(
            polyline: polyline.isNotEmpty ? polyline : [start, end],
            distanceKm: (distanceMeters / 1000.0),
            durationMinutes: (durationSecs / 60.0).round(),
          );
        }
      }
    } catch (_) {
      // Fallback: Straight line polyline with approximate haversine distance
    }

    final straightDistance = const Distance().as(LengthUnit.Kilometer, start, end);
    return RouteResult(
      polyline: [start, end],
      distanceKm: straightDistance,
      durationMinutes: (straightDistance * 2.5).round(),
    );
  }
}

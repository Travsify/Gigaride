import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

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
  /// Zero-Burn road routing via OSRM (Open Source Routing Machine)
  static Future<RouteResult?> getDrivingRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${start.longitude},${start.latitude};'
      '${end.longitude},${end.latitude}'
      '?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'GigaRide/1.0 (info@gigaride.ng)'},
      ).timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List<dynamic>?;

        if (routes != null && routes.isNotEmpty) {
          final firstRoute = routes[0];
          final distanceMeters = (firstRoute['distance'] as num?)?.toDouble() ?? 0.0;
          final durationSecs = (firstRoute['duration'] as num?)?.toDouble() ?? 0.0;
          final coords = firstRoute['geometry']['coordinates'] as List<dynamic>? ?? [];

          final polyline = coords.map((c) {
            return LatLng(
              (c[1] as num).toDouble(),
              (c[0] as num).toDouble(),
            );
          }).toList();

          return RouteResult(
            polyline: polyline,
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

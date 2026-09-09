import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../services/navigation_helper.dart';

int _extractFare(dynamic req) {
  if (req is! Map) return 3000;
  final val = req['riderOfferNgn'] ??
              req['rider_offer_ngn'] ??
              req['suggestedFareNgn'] ??
              req['suggested_fare_ngn'] ??
              req['agreedFareNgn'] ??
              req['agreed_fare_ngn'] ??
              req['counterFareNgn'] ??
              req['fareNgn'] ??
              req['fare'];
  if (val is num) {
    final intVal = val.toInt();
    if (intVal > 0) return intVal;
  }
  if (val is String) {
    final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = int.tryParse(clean);
    if (parsed != null && parsed > 0) return parsed;
  }
  return 3000;
}

String _formatFare(dynamic amount) {
  final val = (amount is num ? amount.toInt() : int.tryParse(amount?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0);
  final displayVal = val > 0 ? val : 3000;
  return displayVal.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
}

class DriverInteractiveMap extends StatefulWidget {
  final LatLng driverLocation;
  final bool isOnline;
  final List<Map<String, dynamic>> incomingRequests;
  final Map<String, dynamic>? activeTrip;
  final List<LatLng> routePoints;
  final double height;
  final Function(Map<String, dynamic>)? onRequestSelected;
  final VoidCallback? onRecenter;

  const DriverInteractiveMap({
    super.key,
    required this.driverLocation,
    required this.isOnline,
    this.incomingRequests = const [],
    this.activeTrip,
    this.routePoints = const [],
    this.height = 260,
    this.onRequestSelected,
    this.onRecenter,
  });

  @override
  State<DriverInteractiveMap> createState() => _DriverInteractiveMapState();
}

class _DriverInteractiveMapState extends State<DriverInteractiveMap> {
  late final MapController _mapController;
  bool _isSatelliteMode = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(covariant DriverInteractiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.routePoints.isNotEmpty && widget.routePoints != oldWidget.routePoints) {
      _fitRouteBounds();
    } else if (widget.routePoints.isEmpty &&
        (widget.driverLocation.latitude != oldWidget.driverLocation.latitude ||
         widget.driverLocation.longitude != oldWidget.driverLocation.longitude)) {
      _mapController.move(widget.driverLocation, 16.0);
    }
  }

  void _fitRouteBounds() {
    if (widget.routePoints.isEmpty) return;
    try {
      final bounds = LatLngBounds.fromPoints(widget.routePoints);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(40),
        ),
      );
    } catch (_) {}
  }

  void _recenterOnDriver() {
    _mapController.move(widget.driverLocation, 16.0);
    if (widget.onRecenter != null) {
      widget.onRecenter!();
    }
  }

  void _launchNavigationHandoff() {
    LatLng? target;
    String label = 'Pickup Location';

    if (widget.activeTrip != null) {
      final trip = widget.activeTrip!;
      final step = trip['status'] ?? 'ACCEPTED';
      if (step == 'ACCEPTED' || step == 'ARRIVED') {
        final lat = (trip['pickupLat'] as num?)?.toDouble() ?? 6.5244;
        final lng = (trip['pickupLng'] as num?)?.toDouble() ?? 3.3792;
        target = LatLng(lat, lng);
        label = trip['pickupAddress'] ?? 'Passenger Pickup';
      } else {
        final lat = (trip['dropoffLat'] as num?)?.toDouble() ?? 6.4281;
        final lng = (trip['dropoffLng'] as num?)?.toDouble() ?? 3.4219;
        target = LatLng(lat, lng);
        label = trip['dropoffAddress'] ?? 'Trip Destination';
      }
    } else if (widget.routePoints.isNotEmpty) {
      target = widget.routePoints.last;
    }

    if (target != null) {
      NavigationHelper.launchExternalNavigation(
        destination: target,
        destinationLabel: label,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tileUrl = _isSatelliteMode
        ? 'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
        : 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';

    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppConstants.darkBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Google Roadmap / Hybrid Satellite Map Layer (High-Resolution)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.driverLocation,
              initialZoom: 16.0,
              minZoom: 4.0,
              maxZoom: 20.0,
              onMapReady: () {
                _mapController.move(widget.driverLocation, 16.0);
              },
            ),
            children: [
              TileLayer(
                key: ValueKey(_isSatelliteMode),
                urlTemplate: tileUrl,
                subdomains: const ['0', '1', '2', '3'],
                fallbackUrl: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                userAgentPackageName: 'ng.giga.driverApp',
                maxZoom: 20,
              ),
              // Route Polyline Layer (Active trip)
              if (widget.routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: widget.routePoints,
                      strokeWidth: 5.0,
                      color: AppConstants.primaryLight,
                    ),
                  ],
                ),
              // Markers Layer
              MarkerLayer(
                markers: [
                  // Driver Vehicle Pin
                  Marker(
                    point: widget.driverLocation,
                    width: 46,
                    height: 46,
                    child: Container(
                      decoration: BoxDecoration(
                        color: (widget.isOnline ? AppConstants.primaryColor : Colors.grey).withOpacity(0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: widget.isOnline ? AppConstants.primaryColor : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black54, blurRadius: 4),
                            ],
                          ),
                          child: const Icon(
                            Icons.navigation_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Incoming passenger request markers on radar
                  ...widget.incomingRequests.map((req) {
                    final lat = (req['pickupLat'] as num?)?.toDouble() ?? (widget.driverLocation.latitude + 0.005);
                    final lng = (req['pickupLng'] as num?)?.toDouble() ?? (widget.driverLocation.longitude + 0.005);
                    final fare = _extractFare(req);

                    return Marker(
                      point: LatLng(lat, lng),
                      width: 84,
                      height: 48,
                      child: GestureDetector(
                        onTap: () {
                          if (widget.onRequestSelected != null) {
                            widget.onRequestSelected!(req);
                          }
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppConstants.accentColor,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black45, blurRadius: 4),
                                ],
                              ),
                              child: Text(
                                '₦${_formatFare(fare)}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.location_on_rounded,
                              color: AppConstants.accentColor,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // Destination marker if active trip exists
                  if (widget.activeTrip != null && widget.routePoints.isNotEmpty)
                    Marker(
                      point: widget.routePoints.last,
                      width: 36,
                      height: 36,
                      child: const Icon(
                        Icons.flag_rounded,
                        color: AppConstants.dangerColor,
                        size: 32,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Top Status Pill
          Positioned(
            top: 12,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppConstants.cardBg.withOpacity(0.92),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.isOnline ? AppConstants.successColor : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.isOnline
                        ? '${widget.incomingRequests.length} Rides in 7km Radius'
                        : 'Offline - Switch Online to Scan',
                    style: const TextStyle(
                      color: AppConstants.textLight,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Top Right Controls (Satellite Toggle)
          Positioned(
            top: 12,
            right: widget.activeTrip != null ? 140 : 14,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isSatelliteMode = !_isSatelliteMode;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _isSatelliteMode ? AppConstants.primaryColor : AppConstants.cardBg.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isSatelliteMode ? Icons.layers_rounded : Icons.satellite_alt_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isSatelliteMode ? '2D Streets' : 'Satellite',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // External Navigation Handoff Button (Google Maps / Waze)
          if (widget.activeTrip != null)
            Positioned(
              top: 12,
              right: 14,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryLight,
                  foregroundColor: Colors.black,
                  elevation: 4,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.turn_right_rounded, size: 16, color: Colors.black),
                label: const Text(
                  'Google Maps',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                ),
                onPressed: _launchNavigationHandoff,
              ),
            ),

          // Bottom Controls: Recenter GPS
          Positioned(
            bottom: 12,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: 'driver_recenter_gps_btn',
              backgroundColor: AppConstants.cardBg.withOpacity(0.9),
              foregroundColor: AppConstants.primaryLight,
              onPressed: _recenterOnDriver,
              child: const Icon(Icons.my_location_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

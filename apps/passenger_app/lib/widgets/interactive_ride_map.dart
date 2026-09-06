import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';

class InteractiveRideMap extends StatefulWidget {
  final LatLng currentLocation;
  final LatLng? pickupLocation;
  final LatLng? dropoffLocation;
  final List<LatLng> routePoints;
  final List<LatLng> nearbyDrivers;
  final double height;
  final bool isExpanded;
  final VoidCallback? onToggleExpand;
  final VoidCallback? onRecenter;

  const InteractiveRideMap({
    super.key,
    required this.currentLocation,
    this.pickupLocation,
    this.dropoffLocation,
    this.routePoints = const [],
    this.nearbyDrivers = const [],
    this.height = 240,
    this.isExpanded = false,
    this.onToggleExpand,
    this.onRecenter,
  });

  @override
  State<InteractiveRideMap> createState() => _InteractiveRideMapState();
}

class _InteractiveRideMapState extends State<InteractiveRideMap> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(covariant InteractiveRideMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.routePoints.isNotEmpty && widget.routePoints != oldWidget.routePoints) {
      _fitRouteBounds();
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

  void _recenterOnUser() {
    _mapController.move(widget.currentLocation, 15.0);
    if (widget.onRecenter != null) {
      widget.onRecenter!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = widget.isExpanded ? MediaQuery.of(context).size.height * 0.65 : widget.height;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: effectiveHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppConstants.darkBg,
        borderRadius: BorderRadius.circular(widget.isExpanded ? 0 : 20),
        border: Border.all(color: Colors.white10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // FlutterMap OpenStreetMap Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.currentLocation,
              initialZoom: 14.5,
              minZoom: 5.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.gigaride.passenger',
              ),
              // Route Polyline Layer
              if (widget.routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: widget.routePoints,
                      strokeWidth: 4.5,
                      color: AppConstants.primaryLight,
                    ),
                  ],
                ),
              // Markers Layer
              MarkerLayer(
                markers: [
                  // User / Pickup Marker
                  Marker(
                    point: widget.pickupLocation ?? widget.currentLocation,
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppConstants.primaryLight.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: AppConstants.primaryLight,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppConstants.primaryLight,
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.person, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  // Dropoff Marker
                  if (widget.dropoffLocation != null)
                    Marker(
                      point: widget.dropoffLocation!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: AppConstants.dangerColor,
                        size: 38,
                      ),
                    ),
                  // Nearby Drivers Car Markers
                  ...widget.nearbyDrivers.map((driverPos) {
                    return Marker(
                      point: driverPos,
                      width: 32,
                      height: 32,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppConstants.cardBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppConstants.accentColor, width: 1.5),
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 4),
                          ],
                        ),
                        child: const Icon(
                          Icons.directions_car_filled_rounded,
                          size: 16,
                          color: AppConstants.accentColor,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // Top Floating Bar: Live GPS Status & Fullscreen Toggle
          Positioned(
            top: 12,
            left: 14,
            right: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppConstants.cardBg.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppConstants.successColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Live GPS Radar Active',
                        style: TextStyle(
                          color: AppConstants.textLight,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onToggleExpand != null)
                  GestureDetector(
                    onTap: widget.onToggleExpand,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppConstants.cardBg.withOpacity(0.9),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Icon(
                        widget.isExpanded ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                        color: AppConstants.textLight,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Right Controls: Recenter GPS
          Positioned(
            bottom: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'recenter_gps_btn',
                  backgroundColor: AppConstants.cardBg.withOpacity(0.9),
                  foregroundColor: AppConstants.primaryLight,
                  onPressed: _recenterOnUser,
                  child: const Icon(Icons.my_location_rounded, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

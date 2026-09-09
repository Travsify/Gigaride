import 'dart:math' as math;
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

  // 🚗 Live Driver Telemetry & Heading
  final LatLng? assignedDriverLocation;
  final double assignedDriverHeading;
  final String? driverVehicleModel;

  // 🏛️ Corridor Environs & Landmarks
  final List<Map<String, dynamic>>? corridorLandmarks;

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
    this.assignedDriverLocation,
    this.assignedDriverHeading = 0.0,
    this.driverVehicleModel,
    this.corridorLandmarks,
  });

  @override
  State<InteractiveRideMap> createState() => _InteractiveRideMapState();
}

class _InteractiveRideMapState extends State<InteractiveRideMap> with TickerProviderStateMixin {
  late final MapController _mapController;
  bool _isSatelliteMode = false;
  late AnimationController _pulseAnimCtrl;
  late Animation<double> _pulseAnimation;

  // Smooth Vehicle Interpolation & Rotation Controller
  late AnimationController _driverAnimCtrl;
  LatLng? _prevDriverPos;
  LatLng? _currDriverPos;
  double _prevHeading = 0.0;
  double _currHeading = 0.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pulseAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.3).animate(
      CurvedAnimation(parent: _pulseAnimCtrl, curve: Curves.easeInOut),
    );

    _driverAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..addListener(() {
      if (mounted) setState(() {});
    });
    _prevDriverPos = widget.assignedDriverLocation;
    _currDriverPos = widget.assignedDriverLocation;
    _prevHeading = widget.assignedDriverHeading;
    _currHeading = widget.assignedDriverHeading;
  }

  LatLng get _interpolatedDriverPos {
    final p0 = _prevDriverPos ?? widget.assignedDriverLocation ?? widget.currentLocation;
    final p1 = _currDriverPos ?? widget.assignedDriverLocation ?? widget.currentLocation;
    final t = CurvedAnimation(
      parent: _driverAnimCtrl,
      curve: Curves.easeOutCubic,
    ).value;
    return LatLng(
      p0.latitude + (p1.latitude - p0.latitude) * t,
      p0.longitude + (p1.longitude - p0.longitude) * t,
    );
  }

  double get _interpolatedDriverHeading {
    final t = CurvedAnimation(
      parent: _driverAnimCtrl,
      curve: Curves.easeOutCubic,
    ).value;
    return _prevHeading + (_currHeading - _prevHeading) * t;
  }

  @override
  void dispose() {
    _pulseAnimCtrl.dispose();
    _driverAnimCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant InteractiveRideMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Smoothly animate driver car to new coordinates with easing curve
    if (widget.assignedDriverLocation != null &&
        (oldWidget.assignedDriverLocation == null ||
         widget.assignedDriverLocation!.latitude != oldWidget.assignedDriverLocation!.latitude ||
         widget.assignedDriverLocation!.longitude != oldWidget.assignedDriverLocation!.longitude ||
         widget.assignedDriverHeading != oldWidget.assignedDriverHeading)) {
      _prevDriverPos = _currDriverPos ?? widget.assignedDriverLocation;
      _currDriverPos = widget.assignedDriverLocation;
      _prevHeading = _currHeading;
      _currHeading = widget.assignedDriverHeading;
      _driverAnimCtrl.forward(from: 0.0);
    }
    if (widget.routePoints.isNotEmpty && widget.routePoints != oldWidget.routePoints) {
      _fitRouteBounds();
    } else if (widget.routePoints.isEmpty &&
        (widget.currentLocation.latitude != oldWidget.currentLocation.latitude ||
         widget.currentLocation.longitude != oldWidget.currentLocation.longitude)) {
      // Smoothly update camera to user's live position
      _mapController.move(widget.currentLocation, 16.0);
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
    _mapController.move(widget.currentLocation, 16.0);
    if (widget.onRecenter != null) {
      widget.onRecenter!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = widget.isExpanded ? MediaQuery.of(context).size.height * 0.65 : widget.height;
    final token = AppConstants.mapboxPublicToken;

    final tileUrl = _isSatelliteMode
        ? 'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$token'
        : 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=$token';

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
          // FlutterMap Mapbox Streets / Satellite Layer (Watermark-Free)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.currentLocation,
              initialZoom: 16.0,
              minZoom: 4.0,
              maxZoom: 19.0,
              onMapReady: () {
                _mapController.move(widget.currentLocation, 16.0);
              },
            ),
            children: [
              TileLayer(
                key: ValueKey(_isSatelliteMode),
                urlTemplate: tileUrl,
                fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'ng.giga.passengerApp',
                maxZoom: 19,
              ),
              // Route Polyline Layer
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
                  // Live GPS User Location Marker with Pulsing Accuracy Ring
                  Marker(
                    point: widget.currentLocation,
                    width: 50,
                    height: 50,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Pulsing outer radar glow
                              Container(
                                width: 38 * _pulseAnimation.value,
                                height: 38 * _pulseAnimation.value,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.blueAccent.withOpacity(0.25 / _pulseAnimation.value),
                                ),
                              ),
                              // White outer ring
                              Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black38,
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              // Core blue GPS dot
                              Container(
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF2563EB), // High-visibility royal blue
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Dedicated Pickup Marker (if user custom-dragged pickup away from live GPS)
                  if (widget.pickupLocation != null &&
                      (widget.pickupLocation!.latitude != widget.currentLocation.latitude ||
                       widget.pickupLocation!.longitude != widget.currentLocation.longitude))
                    Marker(
                      point: widget.pickupLocation!,
                      width: 44,
                      height: 44,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppConstants.primaryLight.withOpacity(0.25),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 24,
                            height: 24,
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
                            child: const Icon(Icons.person_pin_circle_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ),

                  // Destination / Dropoff Marker
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

                  // 🏛️ Real-Time Environs & Nigerian Landmarks Corridor
                  if (widget.corridorLandmarks != null)
                    ...widget.corridorLandmarks!.take(6).map((lm) {
                      final name = (lm['name'] ?? '').toString().split('(').first.trim();
                      final lat = (lm['lat'] as num).toDouble();
                      final lng = (lm['lng'] as num).toDouble();
                      return Marker(
                        point: LatLng(lat, lng),
                        width: 110,
                        height: 32,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xDD0F172A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4), width: 1),
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 4),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.account_balance_rounded, size: 12, color: Color(0xFF38BDF8)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                  // 🚗 Smooth Animated Assigned Driver Vehicle Marker (with Heading Rotation)
                  if (widget.assignedDriverLocation != null)
                    Marker(
                      point: _interpolatedDriverPos,
                      width: 64,
                      height: 64,
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Glowing radar aura around driver vehicle
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppConstants.accentColor.withOpacity(0.22),
                              ),
                            ),
                            // Heading-rotated Navigation Pointer & Vehicle Disc
                            Transform.rotate(
                              angle: (_interpolatedDriverHeading * math.pi) / 180.0,
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppConstants.accentColor, width: 2.5),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black54,
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.navigation_rounded,
                                    size: 22,
                                    color: AppConstants.accentColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Nearby Drivers Car Markers (when searching / idle)
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

          // Top Floating Bar: Live GPS Status & Layer Switcher
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
                      Text(
                        _isSatelliteMode ? 'Real Satellite Visuals' : 'Live GPS Radar Active',
                        style: const TextStyle(
                          color: AppConstants.textLight,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Satellite / Real Visuals Toggle Button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isSatelliteMode = !_isSatelliteMode;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: _isSatelliteMode ? AppConstants.primaryColor : AppConstants.cardBg.withOpacity(0.9),
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
              ],
            ),
          ),

          // Bottom Right Controls: Recenter GPS
          Positioned(
            bottom: 12,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: 'recenter_gps_btn',
              backgroundColor: AppConstants.cardBg.withOpacity(0.9),
              foregroundColor: AppConstants.primaryLight,
              onPressed: _recenterOnUser,
              tooltip: 'Center on my live location',
              child: const Icon(Icons.my_location_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../services/places_service.dart';
import '../services/location_service.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng initialLocation;
  final String title;
  final bool isPickup;

  const MapPickerScreen({
    super.key,
    required this.initialLocation,
    this.title = 'Set Location on Map',
    this.isPickup = true,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late final MapController _mapController;
  late LatLng _centerLocation;
  String _address = 'Locating address...';
  bool _isLoadingAddress = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _centerLocation = widget.initialLocation;
    _resolveAddress(_centerLocation);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      _centerLocation = camera.center;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _resolveAddress(_centerLocation);
      });
    }
  }

  Future<void> _resolveAddress(LatLng pos) async {
    if (!mounted) return;
    setState(() => _isLoadingAddress = true);
    try {
      final addr = await PlacesService.reverseGeocode(pos);
      if (mounted) {
        setState(() {
          _address = addr.isNotEmpty ? addr : 'Selected Map Location';
          _isLoadingAddress = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _address = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
          _isLoadingAddress = false;
        });
      }
    }
  }

  Future<void> _recenterGPS() async {
    try {
      final pos = await LocationService.getCurrentLocation();
      _mapController.move(pos, 16.0);
      _centerLocation = pos;
      _resolveAddress(pos);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      body: Stack(
        children: [
          // 1. High-Performance Retina Map Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialLocation,
              initialZoom: 16.0,
              minZoom: 4.0,
              maxZoom: 18.5,
              onPositionChanged: _onPositionChanged,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token=${AppConstants.mapboxPublicToken}',
                additionalOptions: {
                  'accessToken': AppConstants.mapboxPublicToken,
                },
                maxZoom: 19,
              ),
            ],
          ),

          // 2. Fixed Center Crosshair Pin
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 38),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppConstants.darkBg.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.isPickup ? AppConstants.successColor : AppConstants.dangerColor,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.isPickup ? 'Pickup Here' : 'Dropoff Here',
                      style: TextStyle(
                        color: widget.isPickup ? AppConstants.successColor : AppConstants.dangerColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.location_on,
                    size: 42,
                    color: widget.isPickup ? AppConstants.successColor : AppConstants.dangerColor,
                  ),
                ],
              ),
            ),
          ),

          // 3. Top Floating App Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppConstants.cardBg,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppConstants.cardBg.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppConstants.surfaceBg),
                      ),
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Floating Recenter on GPS button
          Positioned(
            right: 16,
            bottom: 220,
            child: FloatingActionButton.small(
              backgroundColor: AppConstants.cardBg,
              foregroundColor: AppConstants.primaryLight,
              onPressed: _recenterGPS,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),

          // 5. Bottom Confirmation Card
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppConstants.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppConstants.surfaceBg),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (widget.isPickup ? AppConstants.successColor : AppConstants.dangerColor).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.isPickup ? Icons.circle : Icons.location_on_rounded,
                          size: 14,
                          color: widget.isPickup ? AppConstants.successColor : AppConstants.dangerColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.isPickup ? 'Selected Pickup Point' : 'Selected Destination',
                          style: const TextStyle(color: AppConstants.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_isLoadingAddress)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.primaryLight),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _address,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isPickup ? AppConstants.primaryColor : AppConstants.accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.pop(
                          context,
                          PlaceSuggestion(
                            title: _address,
                            subtitle: 'Pinned on Map',
                            location: _centerLocation,
                          ),
                        );
                      },
                      child: Text(
                        widget.isPickup ? 'Confirm Pickup Location' : 'Confirm Destination',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

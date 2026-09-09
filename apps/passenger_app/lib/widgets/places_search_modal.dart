import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../services/places_service.dart';
import '../services/location_service.dart';
import '../screens/map_picker_screen.dart';

class PlacesSearchModal extends StatefulWidget {
  final String initialQuery;
  final LatLng userLocation;
  final String title;
  final bool isInterstate;

  const PlacesSearchModal({
    super.key,
    this.initialQuery = '',
    required this.userLocation,
    this.title = 'Search Destination',
    this.isInterstate = false,
  });

  static Future<PlaceSuggestion?> show(
    BuildContext context, {
    String initialQuery = '',
    required LatLng userLocation,
    String title = 'Search Destination',
    bool isInterstate = false,
  }) {
    return showModalBottomSheet<PlaceSuggestion>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PlacesSearchModal(
        initialQuery: initialQuery,
        userLocation: userLocation,
        title: title,
        isInterstate: isInterstate,
      ),
    );
  }

  @override
  State<PlacesSearchModal> createState() => _PlacesSearchModalState();
}

class _PlacesSearchModalState extends State<PlacesSearchModal> {
  late final TextEditingController _searchCtrl;
  Timer? _debounceTimer;
  List<PlaceSuggestion> _suggestions = [];
  List<PlaceSuggestion> _popularHubs = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.initialQuery);
    _popularHubs = PlacesService.getPopularHubs(widget.userLocation);
    if (widget.initialQuery.isNotEmpty) {
      _performSearch(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await PlacesService.searchPlaces(
      query,
      proximity: widget.userLocation,
      isInterstate: widget.isInterstate,
    );

    if (mounted) {
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    }
  }

  void _selectCurrentLocation() async {
    final pos = await LocationService.getCurrentLocation();
    final address = await PlacesService.reverseGeocode(pos);
    if (mounted) {
      Navigator.pop(
        context,
        PlaceSuggestion(
          title: address.isNotEmpty ? address : 'Current Location',
          subtitle: 'Your active GPS position',
          location: pos,
        ),
      );
    }
  }

  void _selectOnMap() async {
    final place = await Navigator.push<PlaceSuggestion>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLocation: widget.userLocation,
          title: widget.title,
          isPickup: widget.title.toLowerCase().contains('pickup'),
        ),
      ),
    );
    if (place != null && mounted) {
      Navigator.pop(context, place);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppConstants.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  color: AppConstants.textLight,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AppConstants.textMuted),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppConstants.surfaceBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppConstants.primaryLight.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: AppConstants.primaryLight, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    style: const TextStyle(color: AppConstants.textLight, fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'Search street, landmark, estate, or city...',
                      hintStyle: TextStyle(color: AppConstants.textMuted, fontSize: 13),
                      border: InputBorder.none,
                    ),
                    onChanged: _onQueryChanged,
                  ),
                ),
                if (_isSearching)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.primaryLight),
                  )
                else if (_searchCtrl.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _suggestions = []);
                    },
                    child: const Icon(Icons.clear_rounded, color: AppConstants.textMuted, size: 20),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 1. Current Location Button
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.my_location_rounded, color: AppConstants.primaryLight, size: 20),
            ),
            title: const Text('Use Current Location', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text('Auto-detect active GPS position', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
            onTap: _selectCurrentLocation,
          ),
          const SizedBox(height: 4),

          // 2. Set Location on Map (Crosshair Draggable Pin)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppConstants.accentColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.map_rounded, color: AppConstants.accentColor, size: 20),
            ),
            title: const Text('Set Location on Map', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text('Drag crosshair pin to exact building or gate', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
            onTap: _selectOnMap,
          ),
          const Divider(color: Colors.white10),

          // 3. Search Results or Popular Landmarks / Empty State
          Expanded(
            child: _suggestions.isNotEmpty
                ? ListView.separated(
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, _) => const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (ctx, idx) {
                      final item = _suggestions[idx];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppConstants.surfaceBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.location_on_outlined, color: AppConstants.accentColor, size: 20),
                        ),
                        title: Text(
                          item.title,
                          style: const TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          item.subtitle,
                          style: const TextStyle(color: AppConstants.textMuted, fontSize: 11),
                        ),
                        onTap: () => Navigator.pop(context, item),
                      );
                    },
                  )
                : (_searchCtrl.text.isEmpty && _popularHubs.isNotEmpty)
                    ? ListView.separated(
                        itemCount: _popularHubs.length + 1,
                        separatorBuilder: (_, _) => const Divider(color: Colors.white10, height: 1),
                        itemBuilder: (ctx, idx) {
                          if (idx == 0) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'POPULAR NEARBY LANDMARKS',
                                style: TextStyle(
                                  color: AppConstants.primaryLight,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            );
                          }
                          final item = _popularHubs[idx - 1];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 2),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppConstants.primaryColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.star_rounded, color: AppConstants.primaryLight, size: 18),
                            ),
                            title: Text(
                              item.title,
                              style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              item.subtitle,
                              style: const TextStyle(color: AppConstants.textMuted, fontSize: 11),
                            ),
                            onTap: () => Navigator.pop(context, item),
                          );
                        },
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.travel_explore_rounded, size: 40, color: AppConstants.textMuted.withOpacity(0.4)),
                              const SizedBox(height: 10),
                              Text(
                                _searchCtrl.text.isEmpty
                                    ? 'Type an address or set directly on map'
                                    : 'No locations found for "${_searchCtrl.text}". Try "Set Location on Map".',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

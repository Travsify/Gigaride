import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../services/places_service.dart';
import '../services/location_service.dart';

class PlacesSearchModal extends StatefulWidget {
  final String initialQuery;
  final LatLng userLocation;
  final String title;

  const PlacesSearchModal({
    super.key,
    this.initialQuery = '',
    required this.userLocation,
    this.title = 'Search Destination',
  });

  static Future<PlaceSuggestion?> show(
    BuildContext context, {
    String initialQuery = '',
    required LatLng userLocation,
    String title = 'Search Destination',
  }) {
    return showModalBottomSheet<PlaceSuggestion>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PlacesSearchModal(
        initialQuery: initialQuery,
        userLocation: userLocation,
        title: title,
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
  bool _isSearching = false;

  final List<Map<String, dynamic>> _quickSpots = [
    {
      'title': 'Victoria Island',
      'subtitle': 'Adetokunbo Ademola, Lagos',
      'lat': 6.4281,
      'lng': 3.4219,
      'icon': Icons.business_rounded,
    },
    {
      'title': 'Murtala Muhammed Airport (MMA2)',
      'subtitle': 'Airport Road, Ikeja, Lagos',
      'lat': 6.5774,
      'lng': 3.3214,
      'icon': Icons.flight_takeoff_rounded,
    },
    {
      'title': 'Lekki Phase 1',
      'subtitle': 'Admiralty Way, Lekki, Lagos',
      'lat': 6.4474,
      'lng': 3.4723,
      'icon': Icons.apartment_rounded,
    },
    {
      'title': 'Ikeja City Mall (ICM)',
      'subtitle': 'Obafemi Awolowo Way, Alausa, Ikeja',
      'lat': 6.6194,
      'lng': 3.3581,
      'icon': Icons.shopping_bag_rounded,
    },
    {
      'title': 'Yaba Tech / Tech Corridor',
      'subtitle': 'Herbert Macaulay Way, Yaba, Lagos',
      'lat': 6.5167,
      'lng': 3.3778,
      'icon': Icons.code_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.initialQuery);
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
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
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
                      hintText: 'Type address, estate, street or landmark...',
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

          // 1-Tap Option: Current Location
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
            subtitle: const Text('Auto-detect via high-precision phone GPS', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
            onTap: _selectCurrentLocation,
          ),
          const Divider(color: Colors.white10),

          // Results or Quick Suggestions
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
                : ListView(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Popular Lagos Locations',
                          style: TextStyle(color: AppConstants.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ..._quickSpots.map((spot) {
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 2),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppConstants.surfaceBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(spot['icon'] as IconData, color: AppConstants.primaryLight, size: 18),
                          ),
                          title: Text(
                            spot['title'] as String,
                            style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            spot['subtitle'] as String,
                            style: const TextStyle(color: AppConstants.textMuted, fontSize: 11),
                          ),
                          onTap: () {
                            Navigator.pop(
                              context,
                              PlaceSuggestion(
                                title: spot['title'] as String,
                                subtitle: spot['subtitle'] as String,
                                location: LatLng(
                                  (spot['lat'] as num).toDouble(),
                                  (spot['lng'] as num).toDouble(),
                                ),
                              ),
                            );
                          },
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

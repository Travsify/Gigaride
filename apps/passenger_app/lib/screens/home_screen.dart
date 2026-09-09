import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../providers/passenger_provider.dart';
import 'offer_room_screen.dart';
import 'wallet_screen.dart';
import 'activity_screen.dart';
import 'profile_screen.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import '../services/places_service.dart';
import '../widgets/interactive_ride_map.dart';
import '../widgets/places_search_modal.dart';
import '../widgets/fare_offer_sheet.dart';
import 'tracking_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);



  // Controllers
  final _pickupCtrl = TextEditingController(text: 'Current Location');
  final _dropoffCtrl = TextEditingController();
  final _stopCtrl = TextEditingController();
  final _offerCtrl = TextEditingController();
  final _flightCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _gatePassCtrl = TextEditingController();
  final _corporateTagCtrl = TextEditingController();

  // Coordinates & Map State — Nigeria center until real location resolves
  LatLng _currentLocation = LocationService.defaultNigeriaCenter;
  LatLng _pickupLocation = LocationService.defaultNigeriaCenter;
  LatLng? _dropoffLocation;
  List<LatLng> _routePoints = [];
  List<LatLng> _nearbyDrivers = [];
  double _distanceKm = 0.0;
  int _durationMins = 0;
  bool _isMapExpanded = false;

  double get _pickupLat => _pickupLocation.latitude;
  double get _pickupLng => _pickupLocation.longitude;
  double get _dropoffLat => _dropoffLocation?.latitude ?? 6.4281;
  double get _dropoffLng => _dropoffLocation?.longitude ?? 3.4219;

  String _selectedCategory = 'CITY'; // 'CITY', 'AIRPORT', 'INTERSTATE'
  String _selectedVehicleTier = 'ECONOMY'; // 'ECONOMY', 'COMFORT', 'XL_SUV'
  DateTime? _scheduledDateTime;
  final bool _isCorporateMode = false;
  bool _showNotesField = false;
  bool _showStopField = false;
  bool _showGatePassField = false;

  // Rider Selection Mode ('SELF' or 'FRIEND')
  String _riderType = 'SELF';
  String? _friendName;
  String? _friendPhone;

  @override
  void initState() {
    super.initState();


    _dropoffCtrl.addListener(() {
      setState(() {});
    });
    _pickupCtrl.addListener(() {
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<PassengerProvider>();
      p.loadSavedPlaces();
      p.loadPreferences();
      _initLocationAndDrivers();
    });
  }


  StreamSubscription<Position>? _positionSub;

  void _initLocationAndDrivers() async {
    // 0. Approximate location immediately — IP-based, works even with GPS OFF
    //    This ensures the map never shows Lagos when user is in Ibadan/Abuja/PH
    final approx = await LocationService.getApproximateLocation();
    if (mounted && _currentLocation == LocationService.defaultNigeriaCenter) {
      setState(() {
        _currentLocation = approx;
        if (_pickupCtrl.text.isEmpty || _pickupCtrl.text == 'Current Location') {
          _pickupLocation = approx;
        }
        _updateNearbyDrivers(approx);
      });
      _reverseGeocodePickup(approx);
    }

    // 1. Instant check for cached last known position (0ms)
    final cached = await LocationService.getLastKnownLocation();
    if (cached != null && mounted) {
      setState(() {
        _currentLocation = cached;
        if (_pickupCtrl.text.isEmpty || _pickupCtrl.text == 'Current Location') {
          _pickupLocation = cached;
        }
        _updateNearbyDrivers(cached);
      });
      _reverseGeocodePickup(cached);
    }

    // 2. Fetch fresh high-accuracy satellite GPS coordinates
    final pos = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _currentLocation = pos;
        if (_pickupCtrl.text.isEmpty || _pickupCtrl.text == 'Current Location') {
          _pickupLocation = pos;
        }
        _updateNearbyDrivers(pos);
      });
      _reverseGeocodePickup(pos);
    }

    // 3. Keep location live as user moves
    _positionSub?.cancel();
    _positionSub = LocationService.getPositionStream().listen((Position newPos) {
      if (!mounted) return;
      final livePos = LatLng(newPos.latitude, newPos.longitude);
      setState(() {
        _currentLocation = livePos;
        if (_routePoints.isEmpty && (_pickupCtrl.text.isEmpty || _pickupCtrl.text == 'Current Location')) {
          _pickupLocation = livePos;
        }
      });
    });
  }

  void _updateNearbyDrivers(LatLng center) {
    _nearbyDrivers = [
      LatLng(center.latitude + 0.0035, center.longitude + 0.0028),
      LatLng(center.latitude - 0.0028, center.longitude + 0.0042),
      LatLng(center.latitude + 0.0045, center.longitude - 0.0025),
      LatLng(center.latitude - 0.0038, center.longitude - 0.0035),
    ];
  }

  Future<void> _reverseGeocodePickup(LatLng pos) async {
    try {
      final address = await PlacesService.reverseGeocode(pos);
      if (mounted && address.isNotEmpty && address != 'Current Location') {
        setState(() {
          if (_pickupCtrl.text.isEmpty || _pickupCtrl.text == 'Current Location') {
            _pickupCtrl.text = address;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _openDestinationSearch() async {
    final place = await PlacesSearchModal.show(
      context,
      userLocation: _currentLocation,
      initialQuery: _dropoffCtrl.text,
      title: 'Where to?',
      isInterstate: _selectedCategory == 'INTERSTATE',
    );

    if (place != null && mounted) {
      setState(() {
        _dropoffCtrl.text = place.title;
        _dropoffLocation = place.location;
      });
      _fetchRouteAndCalculateFare();
    }
  }

  Future<void> _openPickupSearch() async {
    final place = await PlacesSearchModal.show(
      context,
      userLocation: _currentLocation,
      initialQuery: _pickupCtrl.text == 'Current Location' ? '' : _pickupCtrl.text,
      title: 'Set Pickup Location',
      isInterstate: _selectedCategory == 'INTERSTATE',
    );

    if (place != null && mounted) {
      setState(() {
        _pickupCtrl.text = place.title;
        _pickupLocation = place.location;
      });
      if (_dropoffLocation != null) {
        _fetchRouteAndCalculateFare();
      }
    }
  }

  Future<void> _fetchRouteAndCalculateFare() async {
    if (_dropoffLocation == null) return;

    final route = await RoutingService.getDrivingRoute(_pickupLocation, _dropoffLocation!);
    if (route != null && mounted) {
      setState(() {
        _routePoints = route.polyline;
        _distanceKm = route.distanceKm;
        _durationMins = route.durationMinutes;
      });
    }

    _calculateFareEstimate();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _pickupCtrl.dispose();
    _dropoffCtrl.dispose();
    _stopCtrl.dispose();
    _offerCtrl.dispose();
    _flightCtrl.dispose();
    _notesCtrl.dispose();
    _gatePassCtrl.dispose();
    _corporateTagCtrl.dispose();
    super.dispose();
  }

  void _showOfflineBookingModal(BuildContext context) {
    final pickup = _pickupCtrl.text.trim().isNotEmpty ? _pickupCtrl.text.trim() : 'Current Location';
    final dropoff = _dropoffCtrl.text.trim().isNotEmpty ? _dropoffCtrl.text.trim() : 'Destination';
    final fare = _offerCtrl.text.trim().isNotEmpty ? _offerCtrl.text.trim() : 'Agreed Fare';
    final bookingMsg = 'Hello Giga Ride! Requesting ride from *$pickup* to *$dropoff*. Offer: ₦$fare';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppConstants.accentColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.offline_bolt_rounded, color: AppConstants.accentColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Low Data & Offline Booking', style: TextStyle(color: AppConstants.textLight, fontSize: 17, fontWeight: FontWeight.bold)),
                        Text('Book without mobile internet or on slow network', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // WhatsApp AI Dispatcher
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppConstants.surfaceBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, color: Colors.greenAccent, size: 18),
                        SizedBox(width: 8),
                        Text('WhatsApp AI Automated Dispatch', style: TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Transmits your trip request directly to Giga WhatsApp AI Dispatcher (+234 810 000 GIGA) for automated driver matching.', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                        icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 16),
                        label: const Text('Copy Booking Text for WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: bookingMsg));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied booking request! Paste in WhatsApp to +234 810 000 GIGA'),
                              backgroundColor: Color(0xFF25D366),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // USSD Instant Shortcode
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppConstants.surfaceBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppConstants.primaryLight.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.dialpad_rounded, color: AppConstants.accentColor, size: 18),
                        SizedBox(width: 8),
                        Text('Instant USSD Dial (*384*234#)', style: TextStyle(color: AppConstants.accentColor, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text('Works with zero data on all Nigerian mobile telecom lines (MTN, Airtel, Glo, 9mobile).', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppConstants.accentColor)),
                        icon: const Icon(Icons.call, color: AppConstants.accentColor, size: 16),
                        label: const Text('Copy USSD Code *384*234#', style: TextStyle(color: AppConstants.accentColor, fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () {
                          Clipboard.setData(const ClipboardData(text: '*384*234#'));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('USSD *384*234# copied! Open your phone dialer to book instantly.'),
                              backgroundColor: AppConstants.primaryColor,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRiderSelectorModal() {
    final nameCtrl = TextEditingController(text: _friendName ?? '');
    final phoneCtrl = TextEditingController(text: _friendPhone ?? '');
    String tempRiderType = _riderType;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const Text(
                  'Who is taking this ride?',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Drivers will see the rider details and contact the passenger directly.',
                  style: TextStyle(color: AppConstants.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 16),
                // Option 1: For Me
                Container(
                  decoration: BoxDecoration(
                    color: tempRiderType == 'SELF' ? AppConstants.primaryColor.withOpacity(0.15) : AppConstants.surfaceBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: tempRiderType == 'SELF' ? AppConstants.primaryLight : Colors.transparent,
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppConstants.primaryColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_rounded, color: AppConstants.primaryLight, size: 20),
                    ),
                    title: const Text('For Me', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('You are taking this ride yourself', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    trailing: tempRiderType == 'SELF' ? const Icon(Icons.check_circle_rounded, color: AppConstants.primaryLight) : null,
                    onTap: () {
                      setModalState(() => tempRiderType = 'SELF');
                    },
                  ),
                ),
                const SizedBox(height: 10),
                // Option 2: For a Friend
                Container(
                  decoration: BoxDecoration(
                    color: tempRiderType == 'FRIEND' ? AppConstants.accentColor.withOpacity(0.15) : AppConstants.surfaceBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: tempRiderType == 'FRIEND' ? AppConstants.accentColor : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppConstants.accentColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.group_rounded, color: AppConstants.accentColor, size: 20),
                        ),
                        title: const Text('For a Friend or Colleague', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Book for someone at a different location', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                        trailing: tempRiderType == 'FRIEND' ? const Icon(Icons.check_circle_rounded, color: AppConstants.accentColor) : null,
                        onTap: () {
                          setModalState(() => tempRiderType = 'FRIEND');
                        },
                      ),
                      if (tempRiderType == 'FRIEND') ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                          child: Column(
                            children: [
                              TextField(
                                controller: nameCtrl,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: "Friend's Full Name",
                                  labelStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
                                  hintText: 'e.g. Adaeze Okafor',
                                  hintStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
                                  filled: true,
                                  fillColor: AppConstants.darkBg,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: phoneCtrl,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: "Friend's Phone Number",
                                  labelStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
                                  hintText: 'e.g. 08012345678',
                                  hintStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
                                  filled: true,
                                  fillColor: AppConstants.darkBg,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (tempRiderType == 'FRIEND') {
                        final name = nameCtrl.text.trim();
                        final phone = phoneCtrl.text.trim();
                        if (name.isEmpty || phone.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please enter your friend's name and phone number")),
                          );
                          return;
                        }
                        setState(() {
                          _riderType = 'FRIEND';
                          _friendName = name;
                          _friendPhone = phone;
                        });
                      } else {
                        setState(() {
                          _riderType = 'SELF';
                          _friendName = null;
                          _friendPhone = null;
                        });
                      }
                      Navigator.pop(ctx);
                    },
                    child: const Text('Confirm Rider Selection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleSavedPlaceTap(String label) {
    final provider = context.read<PassengerProvider>();
    final currentAddress = provider.savedPlaces[label];

    if (currentAddress != null && currentAddress.trim().isNotEmpty) {
      setState(() {
        _dropoffCtrl.text = currentAddress.trim();
      });
      _calculateFareEstimate();
    } else {
      // Prompt user to set their saved address
      final editCtrl = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppConstants.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(label == 'Home' ? Icons.home_rounded : Icons.work_rounded, color: AppConstants.primaryLight, size: 24),
              const SizedBox(width: 10),
              Text('Set $label Address', style: const TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter your regular $label address in Lagos for 1-tap booking.', style: const TextStyle(color: AppConstants.textMuted, fontSize: 13)),
              const SizedBox(height: 14),
              TextField(
                controller: editCtrl,
                style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. 14 Admiralty Way, Lekki',
                  hintStyle: const TextStyle(color: AppConstants.textMuted),
                  filled: true,
                  fillColor: AppConstants.surfaceBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppConstants.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
              onPressed: () {
                final addr = editCtrl.text.trim();
                if (addr.isNotEmpty) {
                  provider.savePlace(label, addr);
                  setState(() => _dropoffCtrl.text = addr);
                  _calculateFareEstimate();
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save & Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _pickScheduleDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledDateTime ?? now.add(const Duration(hours: 3)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppConstants.primaryColor,
            onPrimary: Colors.white,
            surface: AppConstants.cardBg,
            onSurface: AppConstants.textLight,
          ),
        ),
        child: child!,
      ),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledDateTime ?? now.add(const Duration(hours: 3))),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppConstants.primaryColor,
            onPrimary: Colors.white,
            surface: AppConstants.cardBg,
            onSurface: AppConstants.textLight,
          ),
        ),
        child: child!,
      ),
    );

    if (pickedTime != null && mounted) {
      setState(() {
        _scheduledDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    }
  }

  void _calculateFareEstimate() {
    final provider = context.read<PassengerProvider>();
    final double dist = _distanceKm > 0 ? _distanceKm : 5.0;
    final int dur = _durationMins > 0 ? _durationMins : 15;

    // Instant offline fallback based on actual road distance so user never sees static 2500
    final int instantBase = ((1500 + (dist * 350) + (dur * 80)) / 100).round() * 100;
    num baseRec = instantBase;
    if (_selectedVehicleTier == 'COMFORT') {
      baseRec = (baseRec * 1.25).round();
    } else if (_selectedVehicleTier == 'XL_SUV') {
      baseRec = (baseRec * 1.70).round();
    }
    setState(() {
      _offerCtrl.text = baseRec.toString();
    });

    provider.calculateEstimate(
      pickupLat: _pickupLat,
      pickupLng: _pickupLng,
      dropoffLat: _dropoffLat,
      dropoffLng: _dropoffLng,
      distanceKm: dist,
      durationMinutes: dur,
    ).then((_) {
      if (!mounted) return;
      final estimate = provider.currentEstimate;
      if (estimate != null) {
        num rec = estimate['suggestedFareNgn'] ??
            estimate['recommendedFareNgn'] ??
            estimate['estimatedFareNgn'] ??
            instantBase;
        if (_selectedVehicleTier == 'COMFORT') {
          rec = estimate['tiers']?['comfortFareNgn'] ?? (rec * 1.25).round();
        } else if (_selectedVehicleTier == 'XL_SUV') {
          rec = estimate['tiers']?['xlSuvFareNgn'] ?? (rec * 1.70).round();
        }
        setState(() {
          _offerCtrl.text = rec.toString();
        });
      }
    });
  }


  String? _assembleNotes() {
    final provider = context.read<PassengerProvider>();
    final List<String> notesList = [];
    if (_riderType == 'FRIEND' && _friendName != null && _friendPhone != null) {
      notesList.add('[Rider: $_friendName • Phone: $_friendPhone]');
    }
    if (_stopCtrl.text.trim().isNotEmpty) {
      notesList.add('[Intermediate Stop: ${_stopCtrl.text.trim()}]');
    }
    if (_gatePassCtrl.text.trim().isNotEmpty) {
      notesList.add('[Estate Gate Pass: ${_gatePassCtrl.text.trim()}]');
    }
    if (provider.alwaysAcOn) {
      notesList.add('[❄️ AC: Must Be ON]');
    }
    if (provider.preferQuiet) {
      notesList.add('[🤫 Quiet Ride]');
    }
    if (provider.luggageAssistance) {
      notesList.add('[🧳 Luggage Assistance]');
    }
    if (_notesCtrl.text.trim().isNotEmpty) {
      notesList.add(_notesCtrl.text.trim());
    }
    return notesList.isNotEmpty ? notesList.join(' • ') : null;
  }

  void _openFareOfferSheet() {
    final dropoffText = _dropoffCtrl.text.trim();
    if (dropoffText.isEmpty) {
      _showSnack('Please enter your destination first.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: FareOfferSheet(
          pickupAddress: _pickupCtrl.text.trim(),
          dropoffAddress: dropoffText,
          pickupLat: _pickupLat,
          pickupLng: _pickupLng,
          dropoffLat: _dropoffLat,
          dropoffLng: _dropoffLng,
          distanceKm: _distanceKm > 0 ? _distanceKm : 5.0,
          durationMins: _durationMins > 0 ? _durationMins : 15,
          notes: _assembleNotes(),
          isBusiness: _isCorporateMode,
          riderName: _friendName,
          riderPhone: _friendPhone,
          riderType: _riderType,
          selectedCategory: _selectedCategory,
        ),
      ),
    );
  }

  void _findDrivers() async {
    final dropoffText = _dropoffCtrl.text.trim();
    if (dropoffText.isEmpty) {
      _showSnack('Please enter your destination.');
      return;
    }

    final offer = int.tryParse(_offerCtrl.text.replaceAll(',', '').trim()) ?? 0;
    final provider = context.read<PassengerProvider>();
    final estimate = provider.currentEstimate;

    if (estimate != null && offer < (estimate['minimumBidFloorNgn'] ?? 1200)) {
      _showSnack(
        'Minimum bid floor is ${currencyFormat.format(estimate['minimumBidFloorNgn'])}. Drivers will ignore lower offers.',
      );
      return;
    }

    // Assemble comprehensive driver notes
    final List<String> notesList = [];
    if (_riderType == 'FRIEND' && _friendName != null && _friendPhone != null) {
      notesList.add('[Rider: $_friendName • Phone: $_friendPhone]');
    }
    if (_stopCtrl.text.trim().isNotEmpty) {
      notesList.add('[Intermediate Stop: ${_stopCtrl.text.trim()}]');
    }
    if (_gatePassCtrl.text.trim().isNotEmpty) {
      notesList.add('[Estate Gate Pass: ${_gatePassCtrl.text.trim()}]');
    }
    // Ride Comfort Preferences & Vehicle Tier
    if (provider.alwaysAcOn) {
      notesList.add('[❄️ AC: Must Be ON]');
    }
    if (provider.preferQuiet) {
      notesList.add('[🤫 Quiet Ride]');
    }
    if (provider.luggageAssistance) {
      notesList.add('[🧳 Luggage Assistance]');
    }
    if (_selectedVehicleTier == 'COMFORT') {
      notesList.add('[✨ Comfort AC Tier]');
    } else if (_selectedVehicleTier == 'XL_SUV') {
      notesList.add('[🚙 XL SUV Tier]');
    }
    if (_notesCtrl.text.trim().isNotEmpty) {
      notesList.add(_notesCtrl.text.trim());
    }
    final combinedNotes = notesList.isNotEmpty ? notesList.join(' • ') : null;

    // Advance Booking Handling (Airport / Interstate)
    if (_selectedCategory == 'AIRPORT' || _selectedCategory == 'INTERSTATE') {
      final scheduleTarget = _scheduledDateTime ?? DateTime.now().add(
        Duration(hours: _selectedCategory == 'AIRPORT' ? 3 : 6),
      );

      try {
        final res = await provider.scheduleAdvanceTrip(
          pickupLat: _pickupLat,
          pickupLng: _pickupLng,
          pickupAddress: _pickupCtrl.text.trim(),
          dropoffLat: _dropoffLat,
          dropoffLng: _dropoffLng,
          dropoffAddress: dropoffText,
          scheduledFor: scheduleTarget.toIso8601String(),
          riderOfferNgn: offer > 0 ? offer : (_selectedCategory == 'AIRPORT' ? 8000 : 25000),
          flightNumber: _flightCtrl.text.trim().isNotEmpty ? _flightCtrl.text.trim() : null,
          isAirport: _selectedCategory == 'AIRPORT',
          isInterstate: _selectedCategory == 'INTERSTATE',
        );

        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppConstants.cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppConstants.successColor, size: 26),
                  SizedBox(width: 10),
                  Text('Trip Scheduled!', style: TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your ${_selectedCategory == 'AIRPORT' ? 'Airport VIP Transfer' : 'Interstate Ride'} has been queued in Giga Dispatch.',
                    style: const TextStyle(color: AppConstants.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppConstants.surfaceBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pickup: ${DateFormat('EEE, MMM d • h:mm a').format(scheduleTarget)}', style: const TextStyle(color: AppConstants.textLight, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Target Fare: ${currencyFormat.format(offer > 0 ? offer : (_selectedCategory == 'AIRPORT' ? 8000 : 25000))}', style: const TextStyle(color: AppConstants.accentColor, fontSize: 12, fontWeight: FontWeight.bold)),
                        if (_flightCtrl.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Flight: ${_flightCtrl.text.trim()}', style: const TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                        ],
                        if (res['id'] != null) ...[
                          const SizedBox(height: 4),
                          Text('Booking Ref: ${res['id'].toString().substring(0, 8).toUpperCase()}', style: const TextStyle(color: AppConstants.textMuted, fontSize: 10)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Assigned drivers will be dispatched 2 hours prior to pickup with zero cancellation penalty.', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _dropoffCtrl.clear();
                      _flightCtrl.clear();
                    });
                  },
                  child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        _showSnack(e.toString().replaceAll('Exception: ', ''));
      }
      return;
    }

    // On-Demand City Ride Handling
    final double dist = _distanceKm > 0 ? _distanceKm : 5.0;
    final int dur = _durationMins > 0 ? _durationMins : 15;
    final int dynamicFallbackFare = ((1500 + (dist * 350) + (dur * 80)) / 100).round() * 100;

    try {
      await provider.submitRideRequest(
        pickupLat: _pickupLat,
        pickupLng: _pickupLng,
        pickupAddress: _pickupCtrl.text.trim(),
        dropoffLat: _dropoffLat,
        dropoffLng: _dropoffLng,
        dropoffAddress: dropoffText,
        riderOfferNgn: offer > 0 ? offer : dynamicFallbackFare,
        notes: combinedNotes,
        isBusiness: _isCorporateMode,
        riderName: _friendName,
        riderPhone: _friendPhone,
        riderType: _riderType,
        distanceKm: dist,
        durationMinutes: dur,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OfferRoomScreen()),
        );
      }
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppConstants.dangerColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildRidesTab(),
          const WalletScreen(isTab: true),
          ActivityScreen(onBookRidePressed: () => setState(() => _currentIndex = 0)),
          ProfileScreen(onOfflineBookingPressed: () => _showOfflineBookingModal(context)),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActiveTripHud(),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ==========================================
  // PERSISTENT ACTIVE TRIP FLOATING HUD
  // Visible across all tabs whenever a ride is active
  // ==========================================
  Widget _buildActiveTripHud() {
    final provider = context.watch<PassengerProvider>();
    final ride = provider.currentRide;
    if (ride == null) return const SizedBox.shrink();

    final status = provider.tripStatus ?? ride['status'] ?? 'REQUESTED';
    if (status == 'COMPLETED' || status == 'CANCELLED') return const SizedBox.shrink();

    final isAssigned = (status == 'ACCEPTED' || status == 'ARRIVED' || status == 'IN_TRANSIT');
    final driver = provider.selectedDriverBid;
    final driverName = driver?['driverName'] ?? 'Driver';
    final vehicle = driver?['vehicleModel'] ?? 'Verified Vehicle';
    final fare = provider.finalFarePaid ?? driver?['counterFareNgn'] ?? ride['riderOfferNgn'] ?? ride['rider_offer_ngn'] ?? 2500;
    final bidsCount = provider.incomingBids.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isAssigned
              ? [const Color(0xFF064E3B), const Color(0xFF0D9488)]
              : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isAssigned ? AppConstants.primaryLight : AppConstants.accentColor.withOpacity(0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isAssigned ? AppConstants.primaryLight : AppConstants.accentColor).withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            if (isAssigned) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RideTrackingScreen()),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OfferRoomScreen()),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Animated pulsing icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (isAssigned ? AppConstants.successColor : AppConstants.accentColor).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isAssigned ? Icons.directions_car_filled_rounded : Icons.wifi_tethering_rounded,
                    color: isAssigned ? AppConstants.successColor : AppConstants.accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            isAssigned ? 'Active Trip in Progress' : 'Offer Room Active',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isAssigned ? AppConstants.successColor : AppConstants.accentColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isAssigned ? status : (bidsCount > 0 ? '$bidsCount BIDS' : 'SEARCHING'),
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isAssigned
                            ? '$driverName • $vehicle • ${currencyFormat.format(fare)}'
                            : 'Broadcast active • Tap to view driver bids',
                        style: const TextStyle(
                          color: AppConstants.textLight,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'OPEN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // FOOTER BOTTOM NAVIGATION BAR
  // ==========================================
  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.cardBg,
        border: const Border(top: BorderSide(color: AppConstants.surfaceBg)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.directions_car_filled_rounded, 'Rides'),
              _buildNavItem(1, Icons.account_balance_wallet_rounded, 'Wallet'),
              _buildNavItem(2, Icons.receipt_long_rounded, 'Activity'),
              _buildNavItem(3, Icons.person_rounded, 'Account'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentIndex = index);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.primaryLight.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppConstants.primaryLight : AppConstants.textMuted,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppConstants.primaryLight : AppConstants.textMuted,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 0: RIDES BOOKING HOME
  // ==========================================
  Widget _buildRidesTab() {
    final provider = context.watch<PassengerProvider>();
    final estimate = provider.currentEstimate;
    final hasRoute = _pickupCtrl.text.trim().isNotEmpty && _dropoffCtrl.text.trim().isNotEmpty;
    final homeAddress = provider.savedPlaces['Home'];
    final workAddress = provider.savedPlaces['Work'];

    return SafeArea(
      child: Column(
        children: [
          // Clean, Spacious Header (Logo + 0% Cut + Offline Action)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: AppConstants.cardBg,
              border: Border(bottom: BorderSide(color: AppConstants.surfaceBg)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Brand Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppConstants.primaryLight.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppConstants.primaryLight.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_rounded, color: AppConstants.accentColor, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'GIGA RIDE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppConstants.successColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '0% Cut',
                        style: TextStyle(color: AppConstants.successColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),

                // Clearly clickable Offline Booking button
                GestureDetector(
                  onTap: () => _showOfflineBookingModal(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, color: Colors.amberAccent, size: 15),
                        SizedBox(width: 4),
                        Text(
                          'Offline Mode',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Pulsating Live Geo-Radar Canvas
                  _buildMapSection(),

                  const SizedBox(height: 14),

                  // 2. Service Category Pills (City, Airport, Interstate)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _buildCategoryPill('CITY', '🚗 City Ride', Icons.directions_car_rounded),
                        const SizedBox(width: 8),
                        _buildCategoryPill('AIRPORT', '✈️ Airport VIP', Icons.flight_rounded),
                        const SizedBox(width: 8),
                        _buildCategoryPill('INTERSTATE', '🛣️ Interstate', Icons.alt_route_rounded),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  const SizedBox(height: 14),

                  // 4. Address Input Card (Pickup, Multi-Stop & Where to)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppConstants.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppConstants.surfaceBg),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Rider Selector ("Who is riding?")
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: _showRiderSelectorModal,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _riderType == 'FRIEND' ? AppConstants.accentColor.withOpacity(0.15) : AppConstants.surfaceBg,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _riderType == 'FRIEND' ? AppConstants.accentColor : Colors.white12,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _riderType == 'FRIEND' ? Icons.group_rounded : Icons.person_rounded,
                                        size: 14,
                                        color: _riderType == 'FRIEND' ? AppConstants.accentColor : AppConstants.primaryLight,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _riderType == 'FRIEND' ? 'Rider: $_friendName' : 'For Me',
                                        style: TextStyle(
                                          color: _riderType == 'FRIEND' ? AppConstants.accentColor : AppConstants.textLight,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.arrow_drop_down_rounded, size: 16, color: AppConstants.textMuted),
                                    ],
                                  ),
                                ),
                              ),
                              if (_riderType == 'FRIEND')
                                Text(
                                  _friendPhone ?? '',
                                  style: const TextStyle(color: AppConstants.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Pickup
                          Row(
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: AppConstants.successColor.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.circle, color: AppConstants.successColor, size: 10),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextField(
                                  controller: _pickupCtrl,
                                  readOnly: true,
                                  onTap: _openPickupSearch,
                                  style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                                  decoration: const InputDecoration(
                                    labelText: 'Pickup Location',
                                    labelStyle: TextStyle(color: AppConstants.textMuted, fontSize: 12),
                                    hintText: 'Current Location',
                                    hintStyle: TextStyle(color: AppConstants.textMuted),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Intermediate Stop (Multi-Stop Route)
                          if (_showStopField) ...[
                            const Divider(color: AppConstants.surfaceBg, height: 24),
                            Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.add_location_alt_rounded, color: Colors.orangeAccent, size: 14),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: TextField(
                                    controller: _stopCtrl,
                                    style: const TextStyle(color: AppConstants.textLight, fontSize: 13),
                                    decoration: const InputDecoration(
                                      labelText: 'Intermediate Stop (Drop colleague / errand)',
                                      labelStyle: TextStyle(color: AppConstants.textMuted, fontSize: 11),
                                      hintText: 'e.g. Yaba Tech, Surulere',
                                      hintStyle: TextStyle(color: AppConstants.textMuted),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16, color: AppConstants.textMuted),
                                  onPressed: () {
                                    setState(() {
                                      _stopCtrl.clear();
                                      _showStopField = false;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],

                          const Divider(color: AppConstants.surfaceBg, height: 24),

                          // Destination ("Where to?")
                          Row(
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: AppConstants.dangerColor.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.location_on_rounded, color: AppConstants.dangerColor, size: 16),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: TextField(
                                  controller: _dropoffCtrl,
                                  readOnly: true,
                                  onTap: _openDestinationSearch,
                                  style: const TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(
                                    labelText: 'Destination',
                                    labelStyle: TextStyle(color: AppConstants.textMuted, fontSize: 12),
                                    hintText: 'Where to? (e.g. Lekki, Ikeja, VI)',
                                    hintStyle: TextStyle(color: AppConstants.textMuted, fontWeight: FontWeight.normal),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                  onSubmitted: (_) => _calculateFareEstimate(),
                                ),
                              ),
                              if (_dropoffCtrl.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear_rounded, color: AppConstants.textMuted, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _dropoffCtrl.clear();
                                      _offerCtrl.clear();
                                    });
                                  },
                                ),
                            ],
                          ),

                          // Extra actions under inputs: Add Stop, Gate Pass, Driver Notes
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (!_showStopField)
                                GestureDetector(
                                  onTap: () => setState(() => _showStopField = true),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                    child: Row(
                                      children: [
                                        Icon(Icons.add, color: AppConstants.accentColor, size: 14),
                                        SizedBox(width: 3),
                                        Text('Add Stop', style: TextStyle(color: AppConstants.accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 14),
                              if (!_showGatePassField)
                                GestureDetector(
                                  onTap: () => setState(() => _showGatePassField = true),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                    child: Row(
                                      children: [
                                        Icon(Icons.vpn_key_rounded, color: AppConstants.primaryLight, size: 13),
                                        SizedBox(width: 3),
                                        Text('Estate Pass', style: TextStyle(color: AppConstants.primaryLight, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 14),
                              if (!_showNotesField)
                                GestureDetector(
                                  onTap: () => setState(() => _showNotesField = true),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                    child: Row(
                                      children: [
                                        Icon(Icons.notes_rounded, color: AppConstants.textMuted, size: 13),
                                        SizedBox(width: 3),
                                        Text('Instructions', style: TextStyle(color: AppConstants.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          // Expandable Estate Gate Pass Field
                          if (_showGatePassField) ...[
                            const Divider(color: AppConstants.surfaceBg, height: 20),
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: AppConstants.primaryLight.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.vpn_key_rounded, color: AppConstants.primaryLight, size: 12),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _gatePassCtrl,
                                    style: const TextStyle(color: AppConstants.textLight, fontSize: 12),
                                    decoration: const InputDecoration(
                                      hintText: 'Estate Gate Access Code (e.g. VGC-8891, Chevron-92)',
                                      hintStyle: TextStyle(color: AppConstants.textMuted, fontSize: 11),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16, color: AppConstants.textMuted),
                                  onPressed: () => setState(() => _showGatePassField = false),
                                ),
                              ],
                            ),
                          ],

                          // Expandable Driver Notes Field
                          if (_showNotesField) ...[
                            const Divider(color: AppConstants.surfaceBg, height: 20),
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: AppConstants.accentColor.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.notes_rounded, color: AppConstants.accentColor, size: 12),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _notesCtrl,
                                    style: const TextStyle(color: AppConstants.textLight, fontSize: 12),
                                    decoration: const InputDecoration(
                                      hintText: 'Driver note (e.g. Call at gate, 2 travel bags)',
                                      hintStyle: TextStyle(color: AppConstants.textMuted, fontSize: 11),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16, color: AppConstants.textMuted),
                                  onPressed: () => setState(() => _showNotesField = false),
                                ),
                              ],
                            ),
                          ],

                          // Advance Booking Schedule for Airport / Interstate
                          if (_selectedCategory != 'CITY') ...[
                            const Divider(color: AppConstants.surfaceBg, height: 24),
                            GestureDetector(
                              onTap: _pickScheduleDateTime,
                              child: Row(
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: AppConstants.accentColor.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.calendar_today_rounded, color: AppConstants.accentColor, size: 14),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Pickup Schedule', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                                        Text(
                                          DateFormat('EEE, MMM d • h:mm a').format(
                                            _scheduledDateTime ?? DateTime.now().add(Duration(hours: _selectedCategory == 'AIRPORT' ? 3 : 6)),
                                          ),
                                          style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppConstants.surfaceBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('Change', style: TextStyle(color: AppConstants.accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (_selectedCategory == 'AIRPORT') ...[
                            const Divider(color: AppConstants.surfaceBg, height: 24),
                            Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: AppConstants.primaryLight.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.flight_takeoff_rounded, color: AppConstants.primaryLight, size: 14),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: TextField(
                                    controller: _flightCtrl,
                                    style: const TextStyle(color: AppConstants.textLight, fontSize: 13),
                                    decoration: const InputDecoration(
                                      hintText: 'Flight Number (e.g. BA075) [Optional]',
                                      hintStyle: TextStyle(color: AppConstants.textMuted, fontSize: 13),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 5. Saved Places (1-Tap Home & Work Bookmarks)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _handleSavedPlaceTap('Home'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppConstants.cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppConstants.surfaceBg),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.home_rounded, color: AppConstants.primaryLight, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Home', style: TextStyle(color: AppConstants.textLight, fontSize: 12, fontWeight: FontWeight.bold)),
                                        Text(
                                          (homeAddress != null && homeAddress.isNotEmpty) ? homeAddress : 'Tap to set address',
                                          style: const TextStyle(color: AppConstants.textMuted, fontSize: 10),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _handleSavedPlaceTap('Work'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppConstants.cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppConstants.surfaceBg),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.work_rounded, color: AppConstants.accentColor, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Work / Office', style: TextStyle(color: AppConstants.textLight, fontSize: 12, fontWeight: FontWeight.bold)),
                                        Text(
                                          (workAddress != null && workAddress.isNotEmpty) ? workAddress : 'Tap to set address',
                                          style: const TextStyle(color: AppConstants.textMuted, fontSize: 10),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // =========================================================================
                  // 7. PROPOSED FARE TAB (ONLY VISIBLE WHEN PICKUP & DESTINATION ARE ENTERED)
                  // =========================================================================
                  if (!hasRoute) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                        decoration: BoxDecoration(
                          color: AppConstants.cardBg.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withOpacity(0.06)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppConstants.primaryLight.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.alt_route_rounded, color: AppConstants.primaryLight, size: 22),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Set Your Route to Bid',
                                    style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Enter your destination above to unlock instant fare estimates and live driver bidding.',
                                    style: TextStyle(color: AppConstants.textMuted, fontSize: 12, height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // CLEAN ROUTE SUMMARY & REVIEW FARE CTA
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppConstants.cardBg,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppConstants.primaryLight.withOpacity(0.4)),
                          boxShadow: [
                            BoxShadow(
                              color: AppConstants.primaryLight.withOpacity(0.12),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppConstants.primaryColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.route_rounded, color: AppConstants.primaryLight, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${_distanceKm > 0 ? _distanceKm.toStringAsFixed(1) : "5.0"} km Route',
                                          style: const TextStyle(color: AppConstants.textLight, fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          'Estimated ~${_durationMins > 0 ? _durationMins : 15} mins',
                                          style: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppConstants.accentColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'PMS: ₦${estimate?['petrolPriceNgn'] ?? 1050}/L',
                                    style: const TextStyle(color: AppConstants.accentColor, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 18),

                            // Review Fare & Broadcast Button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _selectedCategory == 'CITY'
                                    ? _openFareOfferSheet
                                    : (provider.isLoading ? null : _findDrivers),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppConstants.primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 6,
                                  shadowColor: AppConstants.primaryColor.withOpacity(0.4),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _selectedCategory == 'CITY' ? Icons.tune_rounded : Icons.calendar_month_rounded,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _selectedCategory == 'CITY'
                                          ? 'Review Fare & Choose Vehicle'
                                          : _selectedCategory == 'AIRPORT'
                                              ? 'Schedule Airport VIP Transfer'
                                              : 'Book Advance Interstate Ride',
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.arrow_forward_rounded, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PULSATING RADAR CANVAS
  // ==========================================

  Widget _buildMapSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          InteractiveRideMap(
            currentLocation: _currentLocation,
            pickupLocation: _pickupLocation,
            dropoffLocation: _dropoffLocation,
            routePoints: _routePoints,
            nearbyDrivers: _nearbyDrivers,
            height: 250,
            isExpanded: _isMapExpanded,
            onToggleExpand: () => setState(() => _isMapExpanded = !_isMapExpanded),
            onRecenter: () async {
              final pos = await LocationService.getCurrentLocation();
              if (mounted) {
                setState(() {
                  _currentLocation = pos;
                  if (_pickupCtrl.text.isEmpty || _pickupCtrl.text == 'Current Location') {
                    _pickupLocation = pos;
                  }
                });
              }
            },
          ),
          if (_distanceKm > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppConstants.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppConstants.primaryLight.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.route_rounded, color: AppConstants.primaryLight, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Route: ${_distanceKm.toStringAsFixed(1)} km (~$_durationMins mins)',
                        style: const TextStyle(color: AppConstants.textLight, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Text('OSRM Zero-Cost Routing', style: TextStyle(color: AppConstants.accentColor, fontSize: 10, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryPill(String id, String label, IconData icon) {
    final isSelected = _selectedCategory == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppConstants.primaryColor : AppConstants.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppConstants.primaryLight : AppConstants.surfaceBg,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppConstants.primaryColor.withOpacity(0.35),
                      blurRadius: 8,
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppConstants.textMuted,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../providers/passenger_provider.dart';
import 'offer_room_screen.dart';
import 'wallet_screen.dart';
import 'phone_auth_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

  // Controllers (clean default state, NO dummy values)
  final _pickupCtrl = TextEditingController(text: 'Current Location');
  final _dropoffCtrl = TextEditingController();
  final _offerCtrl = TextEditingController();
  final _flightCtrl = TextEditingController();

  // Active coordinates (default center: Lagos Mainland / Island corridor)
  final double _pickupLat = 6.5244;
  final double _pickupLng = 3.3792;
  double _dropoffLat = 6.4281;
  double _dropoffLng = 3.4219;

  String _selectedCategory = 'CITY'; // 'CITY', 'AIRPORT', 'INTERSTATE'
  DateTime? _scheduledDateTime;

  final List<Map<String, dynamic>> _quickDestinations = [
    {
      'name': 'Victoria Island',
      'address': 'Adetokunbo Ademola, VI',
      'lat': 6.4281,
      'lng': 3.4219,
      'icon': Icons.business_rounded,
    },
    {
      'name': 'MMA2 Airport',
      'address': 'Murtala Muhammed Airport, Ikeja',
      'lat': 6.5774,
      'lng': 3.3214,
      'icon': Icons.flight_takeoff_rounded,
    },
    {
      'name': 'Lekki Phase 1',
      'address': 'Admiralty Way, Lekki',
      'lat': 6.4474,
      'lng': 3.4723,
      'icon': Icons.apartment_rounded,
    },
    {
      'name': 'Ikeja City Mall',
      'address': 'Alausa, Ikeja',
      'lat': 6.6194,
      'lng': 3.3581,
      'icon': Icons.shopping_bag_rounded,
    },
  ];

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _dropoffCtrl.dispose();
    _offerCtrl.dispose();
    _flightCtrl.dispose();
    super.dispose();
  }

  void _selectQuickDestination(Map<String, dynamic> dest) {
    setState(() {
      _dropoffCtrl.text = dest['address'];
      _dropoffLat = dest['lat'];
      _dropoffLng = dest['lng'];
    });
    _calculateFareEstimate();
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
    provider.calculateEstimate(
      pickupLat: _pickupLat,
      pickupLng: _pickupLng,
      dropoffLat: _dropoffLat,
      dropoffLng: _dropoffLng,
    ).then((_) {
      if (!mounted) return;
      final estimate = provider.currentEstimate;
      if (estimate != null) {
        final rec = estimate['recommendedFareNgn'] ?? estimate['estimatedFareNgn'] ?? 2500;
        setState(() {
          _offerCtrl.text = rec.toString();
        });
      }
    });
  }

  void _adjustOffer(int delta) {
    final current = int.tryParse(_offerCtrl.text.replaceAll(',', '').trim()) ?? 2000;
    final updated = (current + delta).clamp(1000, 200000);
    setState(() {
      _offerCtrl.text = updated.toString();
    });
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
              title: Row(
                children: const [
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
    try {
      await provider.submitRideRequest(
        pickupLat: _pickupLat,
        pickupLng: _pickupLng,
        pickupAddress: _pickupCtrl.text.trim(),
        dropoffLat: _dropoffLat,
        dropoffLng: _dropoffLng,
        dropoffAddress: dropoffText,
        riderOfferNgn: offer > 0 ? offer : 2500,
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
    final provider = context.watch<PassengerProvider>();
    final user = provider.user;
    final estimate = provider.currentEstimate;
    final userName = user?['fullName'] ?? user?['full_name'] ?? 'Passenger';

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header: Greeting, Living Wallet, and Drawer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: AppConstants.cardBg,
                border: Border(bottom: BorderSide(color: AppConstants.surfaceBg)),
              ),
              child: Row(
                children: [
                  // Profile Avatar
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppConstants.primaryLight.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppConstants.primaryLight.withOpacity(0.5)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'P',
                      style: const TextStyle(
                        color: AppConstants.primaryLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Greeting
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, $userName 👋',
                          style: const TextStyle(
                            color: AppConstants.textLight,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Row(
                          children: [
                            Icon(Icons.circle, color: AppConstants.successColor, size: 7),
                            SizedBox(width: 4),
                            Text(
                              'Zero Commission Network',
                              style: TextStyle(
                                color: AppConstants.textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Living Wallet Balance Pill
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WalletScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppConstants.accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppConstants.accentColor.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.account_balance_wallet_rounded, color: AppConstants.accentColor, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'Wallet',
                            style: TextStyle(
                              color: AppConstants.accentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Logout
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: AppConstants.textMuted, size: 20),
                    tooltip: 'Sign Out',
                    onPressed: () async {
                      await provider.logout();
                      if (!context.mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
                        (r) => false,
                      );
                    },
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
                    // Simulated Live Geo-Radar Canvas
                    Container(
                      height: 140,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF0F2321),
                            AppConstants.darkBg,
                          ],
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Radar Ring 1
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppConstants.primaryLight.withOpacity(0.15)),
                            ),
                          ),
                          // Radar Ring 2
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppConstants.primaryLight.withOpacity(0.25)),
                            ),
                          ),
                          // Center Pin (Passenger Location)
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppConstants.primaryLight,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppConstants.primaryLight.withOpacity(0.6),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 16),
                          ),
                          // Top Radar Badge
                          Positioned(
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppConstants.cardBg.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppConstants.surfaceBg),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.radar_rounded, color: AppConstants.primaryLight, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    'Verified Drivers Active Nearby',
                                    style: TextStyle(
                                      color: AppConstants.textLight,
                                      fontSize: 10,
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

                    // Service Category Pills
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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

                    // Address Booking Box
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppConstants.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppConstants.surfaceBg),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Pickup
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: AppConstants.successColor.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.circle, color: AppConstants.successColor, size: 10),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _pickupCtrl,
                                    style: const TextStyle(color: AppConstants.textLight, fontSize: 13),
                                    decoration: const InputDecoration(
                                      hintText: 'Pickup Location',
                                      hintStyle: TextStyle(color: AppConstants.textMuted),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const Divider(color: AppConstants.surfaceBg, height: 20),

                            // Destination
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: AppConstants.dangerColor.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.location_on_rounded, color: AppConstants.dangerColor, size: 14),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _dropoffCtrl,
                                    style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.bold),
                                    decoration: const InputDecoration(
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
                                    icon: const Icon(Icons.clear_rounded, color: AppConstants.textMuted, size: 16),
                                    onPressed: () => setState(() => _dropoffCtrl.clear()),
                                  ),
                              ],
                            ),

                            // Advance Booking Fields (Airport / Interstate)
                            if (_selectedCategory != 'CITY') ...[
                              const Divider(color: AppConstants.surfaceBg, height: 20),
                              GestureDetector(
                                onTap: _pickScheduleDateTime,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: AppConstants.accentColor.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.calendar_today_rounded, color: AppConstants.accentColor, size: 12),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Pickup Schedule', style: TextStyle(color: AppConstants.textMuted, fontSize: 10)),
                                          Text(
                                            DateFormat('EEE, MMM d • h:mm a').format(
                                              _scheduledDateTime ?? DateTime.now().add(Duration(hours: _selectedCategory == 'AIRPORT' ? 3 : 6)),
                                            ),
                                            style: const TextStyle(color: AppConstants.textLight, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                    child: const Icon(Icons.flight_takeoff_rounded, color: AppConstants.primaryLight, size: 13),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _flightCtrl,
                                      style: const TextStyle(color: AppConstants.textLight, fontSize: 12),
                                      decoration: const InputDecoration(
                                        hintText: 'Flight Number (e.g. BA075) [Optional]',
                                        hintStyle: TextStyle(color: AppConstants.textMuted, fontSize: 12),
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

                    // Quick Destination Chips
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Popular Destinations in Lagos',
                            style: TextStyle(
                              color: AppConstants.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _quickDestinations.map((d) {
                              return GestureDetector(
                                onTap: () => _selectQuickDestination(d),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppConstants.cardBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppConstants.surfaceBg),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(d['icon'] as IconData, size: 13, color: AppConstants.primaryLight),
                                      const SizedBox(width: 6),
                                      Text(
                                        d['name'] as String,
                                        style: const TextStyle(color: AppConstants.textLight, fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Fare Bidding Dial (When destination is chosen)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppConstants.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppConstants.surfaceBg),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Your Proposed Fare',
                                  style: TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                if (estimate != null)
                                  Text(
                                    'Fuel Index: ₦${estimate['petrolPriceNgn'] ?? 1050}/L',
                                    style: const TextStyle(color: AppConstants.accentColor, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Offer Stepper Row
                            Row(
                              children: [
                                _buildStepperBtn('-₦500', () => _adjustOffer(-500)),
                                const SizedBox(width: 8),
                                _buildStepperBtn('-₦200', () => _adjustOffer(-200)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppConstants.darkBg,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppConstants.primaryLight.withOpacity(0.5)),
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text('₦', style: TextStyle(color: AppConstants.primaryLight, fontSize: 18, fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 2),
                                        IntrinsicWidth(
                                          child: TextField(
                                            controller: _offerCtrl,
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: AppConstants.textLight,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                            ),
                                            decoration: const InputDecoration(
                                              hintText: '2,500',
                                              hintStyle: TextStyle(color: AppConstants.textMuted),
                                              border: InputBorder.none,
                                              isDense: true,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildStepperBtn('+₦200', () => _adjustOffer(200)),
                                const SizedBox(width: 8),
                                _buildStepperBtn('+₦500', () => _adjustOffer(500)),
                              ],
                            ),

                            if (estimate != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Recommended: ${currencyFormat.format(estimate['recommendedFareNgn'] ?? 2500)} • Minimum Bid: ${currencyFormat.format(estimate['minimumBidFloorNgn'] ?? 1200)}',
                                style: const TextStyle(color: AppConstants.textMuted, fontSize: 11),
                              ),
                            ],

                            const SizedBox(height: 16),

                            // CTA: Request Drivers
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: provider.isLoading ? null : _findDrivers,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppConstants.primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 4,
                                  shadowColor: AppConstants.primaryColor.withOpacity(0.4),
                                ),
                                child: provider.isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            _selectedCategory == 'CITY'
                                                ? 'Find Nearby Drivers'
                                                : _selectedCategory == 'AIRPORT'
                                                    ? 'Schedule Airport VIP Transfer'
                                                    : 'Book Advance Interstate Ride',
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.arrow_forward_rounded, size: 16),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
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
          padding: const EdgeInsets.symmetric(vertical: 10),
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
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepperBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppConstants.surfaceBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppConstants.textLight,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

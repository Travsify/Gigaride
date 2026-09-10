import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/driver_provider.dart';
import 'active_trip_screen.dart';
import 'kyc_screen.dart';
import 'subscription_screen.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../widgets/driver_interactive_map.dart';

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

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> with SingleTickerProviderStateMixin {
  LatLng _driverLocation = LocationService.defaultLagosLocation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initDriverLocation();
    // Keep screen awake while driver is on radar
    WakelockPlus.enable();
  }


  StreamSubscription<Position>? _driverLocationSub;

  void _initDriverLocation() async {
    // 1. Instant check for cached last known position (0ms)
    final cached = await LocationService.getLastKnownLocation();
    if (cached != null && mounted) {
      setState(() => _driverLocation = cached);
    }

    // 2. Fetch fresh high accuracy location
    final pos = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() => _driverLocation = pos);
      context.read<DriverProvider>().updateLocation(pos.latitude, pos.longitude);
    }

    // 3. Keep driver location live as vehicle moves
    _driverLocationSub?.cancel();
    _driverLocationSub = LocationService.getPositionStream().listen((Position newPos) {
      if (!mounted) return;
      setState(() => _driverLocation = LatLng(newPos.latitude, newPos.longitude));
      context.read<DriverProvider>().updateLocation(newPos.latitude, newPos.longitude);
    });
  }

  @override
  void dispose() {
    _driverLocationSub?.cancel();
    _pulseController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _showCustomBidDialog(Map<String, dynamic> req) {
    final originalFare = _extractFare(req);
    final fareCtrl = TextEditingController(text: '$originalFare');
    final etaCtrl = TextEditingController(text: '7');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Place Custom Counter-Offer', style: TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Passenger offered ₦${_formatFare(originalFare)}. You keep 100% of your counter-offer.', style: const TextStyle(color: AppConstants.textMuted, fontSize: 12)),
            const SizedBox(height: 20),
            TextField(
              controller: fareCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppConstants.accentColor, fontSize: 22, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                labelText: 'Your Proposed Fare (₦)',
                labelStyle: const TextStyle(color: AppConstants.textMuted),
                prefixText: '₦ ',
                prefixStyle: const TextStyle(color: AppConstants.accentColor, fontSize: 22, fontWeight: FontWeight.w900),
                filled: true,
                fillColor: AppConstants.surfaceBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: etaCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppConstants.textLight, fontSize: 16, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Estimated Pickup Time (Minutes)',
                labelStyle: const TextStyle(color: AppConstants.textMuted),
                suffixText: 'mins',
                filled: true,
                fillColor: AppConstants.surfaceBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () {
                  final fare = int.tryParse(fareCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 3000;
                  final eta = int.tryParse(etaCtrl.text) ?? 5;
                  final targetRideId = (req['rideId'] ?? req['ride_id'] ?? req['id'] ?? '').toString();
                  context.read<DriverProvider>().submitCounterOffer(targetRideId, fare, eta);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✓ Counter-offer of ₦${_formatFare(fare)} submitted to rider!'), backgroundColor: AppConstants.successColor),
                  );
                },
                child: const Text('Submit Counter-Offer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleToggleOnline(DriverProvider provider) {
    final kyc = provider.driverProfile?['kyc_status'];
    if (kyc != 'APPROVED') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppConstants.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: AppConstants.accentColor, size: 24),
              SizedBox(width: 10),
              Expanded(child: Text('Identity Verification Required', style: TextStyle(color: AppConstants.textLight, fontSize: 16, fontWeight: FontWeight.bold))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'In compliance with Federal Ministry of Transport regulations, drivers must be thoroughly verified and approved (Government NIN & FRSC Driver License) before going live on the radar cockpit.',
                style: TextStyle(color: AppConstants.textMuted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppConstants.surfaceBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Text('Current Status: ', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                    Text(
                      kyc ?? 'PENDING',
                      style: const TextStyle(color: AppConstants.accentColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: AppConstants.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const KycScreen()),
                );
              },
              child: const Text('Verify Identity Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      );
      return;
    }

    final remaining = provider.remainingRides;
    final hasActiveSub = provider.hasActiveSubscription;
    if (!provider.isOnline && remaining <= 0 && !hasActiveSub) {
      _showOffRadarExhaustedModal();
      return;
    }

    provider.toggleOnline();
  }

  void _showOffRadarExhaustedModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppConstants.dangerColor, width: 1.5),
        ),
        title: const Column(
          children: [
            Icon(Icons.radar_outlined, color: AppConstants.dangerColor, size: 48),
            SizedBox(height: 12),
            Text(
              "You're Off the Radar",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppConstants.textLight, fontSize: 19, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Your trip allowance and 2 grace trips are completed. You are currently invisible on the passenger radar. Activate any subscription plan of your choice to go live immediately and keep 100% of your earnings.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppConstants.textMuted, fontSize: 13, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
              label: const Text('Tap to Pay & Go Live', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
              },
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Remind Me Later', style: TextStyle(color: AppConstants.textMuted)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriverProvider>();
    final isOnline = provider.isOnline;
    final remaining = provider.remainingRides;
    final requests = provider.incomingRequests;
    final activeTrip = provider.activeTrip;

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Cockpit Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Online / Offline Switch
                      GestureDetector(
                        onTap: () => _handleToggleOnline(provider),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isOnline ? AppConstants.successColor.withOpacity(0.15) : AppConstants.cardBg,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isOnline ? AppConstants.successColor : Colors.white24,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: isOnline ? AppConstants.successColor : AppConstants.textMuted,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isOnline ? 'ONLINE' : 'OFFLINE',
                                style: TextStyle(
                                  color: isOnline ? AppConstants.successColor : AppConstants.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Giga Driver Logo Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryLight.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppConstants.primaryLight.withOpacity(0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.asset('assets/images/logo.png', width: 16, height: 16),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'GIGA DRIVER',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Subscription Rides Pill (Responsive, never spills out)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: remaining > 2
                                ? AppConstants.primaryColor.withOpacity(0.2)
                                : (remaining > 0 ? Colors.amber.withOpacity(0.2) : AppConstants.dangerColor.withOpacity(0.2)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: remaining > 2
                                  ? AppConstants.primaryLight
                                  : (remaining > 0 ? Colors.amberAccent : AppConstants.dangerColor),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt_rounded, size: 15, color: remaining > 2 ? AppConstants.primaryLight : (remaining > 0 ? Colors.amberAccent : AppConstants.dangerColor)),
                              const SizedBox(width: 4),
                              Text(
                                remaining > 0 ? '$remaining Left' : 'Renew Plan',
                                style: TextStyle(
                                  color: remaining > 2 ? AppConstants.textLight : (remaining > 0 ? Colors.amberAccent : AppConstants.dangerColor),
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

                  const SizedBox(height: 10),

                  // Benchmark Fuel Ticker (National / Nigeria-wide, auto-contained)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppConstants.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_gas_station_rounded, color: Colors.cyanAccent, size: 14),
                            SizedBox(width: 6),
                            Text('Petrol Benchmark:', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                          ],
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '₦1,050/L • 0% Commission Shield',
                            style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Grace Period Warning Banner (2 Extra Trips Allowed)
                  if (remaining <= 2 && remaining > 0 && isOnline) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amberAccent, width: 1.2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '⚠️ Grace Period: $remaining extra trip${remaining == 1 ? '' : 's'} left before going invisible on radar. Tap to renew.',
                                style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Colors.amberAccent, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Off Radar Notice when 0 trips remain
                  if (remaining <= 0 && isOnline) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppConstants.dangerColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppConstants.dangerColor, width: 1.2),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.radar_outlined, color: AppConstants.dangerColor, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '📡 You are OFF the Radar: Trip allowance exhausted. Tap to choose a plan and go back live.',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Interactive Live Driver GPS Radar Map
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: DriverInteractiveMap(
                driverLocation: _driverLocation,
                isOnline: isOnline,
                incomingRequests: requests,
                activeTrip: activeTrip,
                height: 240,
                onRequestSelected: (req) => _showCustomBidDialog(req),
                onRecenter: () async {
                  final pos = await LocationService.getCurrentLocation();
                  if (mounted) setState(() => _driverLocation = pos);
                },
              ),
            ),

            // Active Trip Floating Banner (if currently on trip)
            if (activeTrip != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF047857)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: AppConstants.primaryColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.navigation_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Active Trip in Progress', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(activeTrip['pickupAddress'] ?? 'En Route', style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppConstants.primaryColor, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ActiveTripScreen(trip: activeTrip)));
                      },
                      child: const Text('Open HUD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),

            // Radar Map Waves Area / Empty State
            if (requests.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: isOnline ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: isOnline ? AppConstants.primaryColor.withOpacity(0.12) : Colors.white.withOpacity(0.04),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isOnline ? AppConstants.primaryLight.withOpacity(0.3) : Colors.white12,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            isOnline ? Icons.radar_rounded : Icons.radar_outlined,
                            size: 56,
                            color: isOnline ? AppConstants.primaryLight : AppConstants.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        isOnline ? 'Scanning 7km Radius for Rides...' : 'You are currently Offline',
                        style: const TextStyle(color: AppConstants.textLight, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isOnline
                            ? 'Passenger trip requests in your area will appear here instantly.'
                            : 'Switch to Online at the top to start receiving live passenger offers.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Incoming Requests Live List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: requests.length,
                  itemBuilder: (ctx, idx) {
                    final req = requests[idx];
                    final rideId = (req['rideId'] ?? req['ride_id'] ?? req['id'] ?? '').toString();
                    final fare = _extractFare(req);
                    final pickup = req['pickupAddress'] ?? 'Pickup Address';
                    final dropoff = req['dropoffAddress'] ?? 'Destination Address';
                    final distance = req['driverPickupDistanceKm'] ?? 1.8;
                    final isFriend = req['riderType'] == 'FRIEND' || req['rider_type'] == 'FRIEND';
                    final riderName = req['riderName'] ?? req['rider_name'];
                    final riderRating = (req['riderRating'] ?? req['rider_rating'] ?? req['passengerRating'] ?? req['rating'] ?? 4.9).toString();
                    final notes = req['notes'] ?? req['tripInstructions'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppConstants.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isFriend ? Colors.amber.withOpacity(0.5) : AppConstants.primaryLight.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Pickup distance & proposed fare
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppConstants.primaryColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('${distance.toStringAsFixed(1)} km to pickup', style: const TextStyle(color: AppConstants.primaryLight, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_rounded, color: Colors.amberAccent, size: 13),
                                        const SizedBox(width: 2),
                                        Text(
                                          riderRating,
                                          style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isFriend && riderName != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.amber.withOpacity(0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.people_alt_rounded, color: Colors.amberAccent, size: 12),
                                          const SizedBox(width: 4),
                                          Text(
                                            'For: $riderName',
                                            style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Passenger Offer', style: TextStyle(color: AppConstants.textMuted, fontSize: 10)),
                                  Text('₦${_formatFare(fare)}', style: const TextStyle(color: AppConstants.accentColor, fontSize: 22, fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Route
                          Row(
                            children: [
                              const Icon(Icons.circle, color: AppConstants.primaryLight, size: 10),
                              const SizedBox(width: 10),
                              Expanded(child: Text(pickup, style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 4, top: 2, bottom: 2),
                            child: SizedBox(height: 12, child: VerticalDivider(color: Colors.white24, thickness: 1)),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.location_on_rounded, color: AppConstants.accentColor, size: 12),
                              const SizedBox(width: 10),
                              Expanded(child: Text(dropoff, style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                          if (notes != null && notes.toString().trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppConstants.surfaceBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.speaker_notes_outlined, color: AppConstants.accentColor, size: 14),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      notes.toString(),
                                      style: const TextStyle(color: AppConstants.textLight, fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Primary 1-Tap Accept Button (Full Width)
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppConstants.successColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 3,
                              ),
                              onPressed: () {
                                provider.submitCounterOffer(rideId, fare, 5);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('✓ Accepted ₦${_formatFare(fare)}! Waiting for passenger confirmation.'),
                                    backgroundColor: AppConstants.successColor,
                                  ),
                                );
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'ACCEPT ₦${_formatFare(fare)} (KEEP 100%)',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Quick Counter-Offer Chips & Actions
                          Row(
                            children: [
                              // +₦500
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.white24),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  onPressed: () {
                                    provider.submitCounterOffer(rideId, fare + 500, 7);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Sent counter-offer: ₦${_formatFare(fare + 500)}'), backgroundColor: AppConstants.primaryColor),
                                    );
                                  },
                                  child: Text('+₦500\n(₦${_formatFare(fare + 500)})', textAlign: TextAlign.center, style: const TextStyle(color: AppConstants.textLight, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // +₦1,000
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.white24),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  onPressed: () {
                                    provider.submitCounterOffer(rideId, fare + 1000, 8);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Sent counter-offer: ₦${_formatFare(fare + 1000)}'), backgroundColor: AppConstants.primaryColor),
                                    );
                                  },
                                  child: Text('+₦1,000\n(₦${_formatFare(fare + 1000)})', textAlign: TextAlign.center, style: const TextStyle(color: AppConstants.textLight, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Custom Offer Dialog
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: AppConstants.surfaceBg,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.tune_rounded, color: AppConstants.primaryLight, size: 20),
                                tooltip: 'Custom Offer',
                                onPressed: () => _showCustomBidDialog(req),
                              ),
                              const SizedBox(width: 6),

                              // Decline Button
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: AppConstants.dangerColor.withOpacity(0.15),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.close_rounded, color: AppConstants.dangerColor, size: 20),
                                tooltip: 'Decline',
                                onPressed: () {
                                  setState(() {
                                    provider.incomingRequests.removeWhere((r) => (r['rideId'] ?? r['id'] ?? r['ride_id']) == rideId);
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

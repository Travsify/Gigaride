import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/driver_provider.dart';
import 'active_trip_screen.dart';
import 'subscription_screen.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> with SingleTickerProviderStateMixin {
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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _showCustomBidDialog(Map<String, dynamic> req) {
    final fareCtrl = TextEditingController(text: '${req['riderOfferNgn'] ?? 3000}');
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
            Text('Passenger offered ₦${req['riderOfferNgn']}. You keep 100% of your counter-offer.', style: const TextStyle(color: AppConstants.textMuted, fontSize: 12)),
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
                  context.read<DriverProvider>().submitCounterOffer(req['rideId'], fare, eta);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✓ Counter-offer of ₦$fare submitted to rider!'), backgroundColor: AppConstants.successColor),
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
                        onTap: () => provider.toggleOnline(),
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

                      // Subscription Rides Pill
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: remaining > 2 ? AppConstants.primaryColor.withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: remaining > 2 ? AppConstants.primaryLight : Colors.amberAccent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.bolt_rounded, size: 16, color: remaining > 2 ? AppConstants.primaryLight : Colors.amberAccent),
                              const SizedBox(width: 4),
                              Text(
                                '$remaining Rides Left',
                                style: TextStyle(
                                  color: remaining > 2 ? AppConstants.textLight : Colors.amberAccent,
                                  fontSize: 12,
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

                  // Benchmark Fuel Ticker
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppConstants.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.local_gas_station_rounded, color: Colors.cyanAccent, size: 15),
                            SizedBox(width: 6),
                            Text('Lagos Petrol Benchmark:', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                          ],
                        ),
                        Text('₦1,050/L • 0% Commission Shield', style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
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
                    final fare = req['riderOfferNgn'] ?? 3000;
                    final pickup = req['pickupAddress'] ?? 'Pickup Address';
                    final dropoff = req['dropoffAddress'] ?? 'Destination Address';
                    final distance = req['driverPickupDistanceKm'] ?? 1.8;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppConstants.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppConstants.primaryLight.withOpacity(0.3), width: 1.5),
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppConstants.primaryColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('${distance.toStringAsFixed(1)} km to pickup', style: const TextStyle(color: AppConstants.primaryLight, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Rider Offer', style: TextStyle(color: AppConstants.textMuted, fontSize: 10)),
                                  Text('₦${fare.toLocaleString()}', style: const TextStyle(color: AppConstants.accentColor, fontSize: 20, fontWeight: FontWeight.w900)),
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

                          const SizedBox(height: 16),

                          // Quick Bidding Chips
                          Row(
                            children: [
                              // Accept Rider's Exact Offer
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppConstants.successColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  onPressed: () {
                                    provider.submitCounterOffer(req['rideId'], fare, 5);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('✓ Accepted ₦$fare offer! Waiting for passenger confirmation.'), backgroundColor: AppConstants.successColor),
                                    );
                                  },
                                  child: const Text('Accept 100%', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Quick Raise +₦300
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.white24),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  onPressed: () {
                                    provider.submitCounterOffer(req['rideId'], fare + 300, 6);
                                  },
                                  child: const Text('+₦300', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Quick Raise +₦500
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.white24),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  onPressed: () {
                                    provider.submitCounterOffer(req['rideId'], fare + 500, 7);
                                  },
                                  child: const Text('+₦500', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Custom Offer Dialog
                              IconButton(
                                style: IconButton.styleFrom(backgroundColor: AppConstants.surfaceBg),
                                icon: const Icon(Icons.tune_rounded, color: AppConstants.primaryLight, size: 18),
                                onPressed: () => _showCustomBidDialog(req),
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

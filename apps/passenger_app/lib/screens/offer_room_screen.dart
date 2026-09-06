import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../providers/passenger_provider.dart';
import 'tracking_screen.dart';

class OfferRoomScreen extends StatefulWidget {
  const OfferRoomScreen({super.key});

  @override
  State<OfferRoomScreen> createState() => _OfferRoomScreenState();
}

class _OfferRoomScreenState extends State<OfferRoomScreen> {
  int _searchSeconds = 0;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _searchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _searchSeconds++);
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  void _raiseCurrentOffer(int delta) {
    final provider = context.read<PassengerProvider>();
    final ride = provider.currentRide;
    if (ride == null) return;
    final current = ride['riderOfferNgn'] ?? ride['rider_offer_ngn'] ?? 2500;
    final updated = (current + delta).clamp(1000, 200000);
    provider.currentRide?['riderOfferNgn'] = updated;
    provider.currentRide?['rider_offer_ngn'] = updated;
    provider.socket.broadcastRide(ride['id']);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Offer increased by ₦$delta! Broadcasted to nearby drivers.'),
        backgroundColor: AppConstants.primaryColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PassengerProvider>();
    final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
    final ride = provider.currentRide;
    final bids = provider.incomingBids;
    final offerNgn = ride?['riderOfferNgn'] ?? ride?['rider_offer_ngn'] ?? 2500;

    // Transition to tracking screen if accepted
    if (provider.tripStatus == 'ACCEPTED' || provider.tripStatus == 'ARRIVED' || provider.tripStatus == 'IN_TRANSIT') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RideTrackingScreen()),
        );
      });
    }

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      appBar: AppBar(
        backgroundColor: AppConstants.cardBg,
        elevation: 0,
        title: const Text('Driver Offer Room', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppConstants.textLight),
          onPressed: () {
            provider.resetTrip();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Your Ride Request Summary Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: AppConstants.cardBg,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your Broadcasted Offer', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(
                        currencyFormat.format(offerNgn),
                        style: const TextStyle(color: AppConstants.accentColor, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: bids.isNotEmpty ? AppConstants.successColor.withOpacity(0.2) : AppConstants.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      bids.isNotEmpty ? '${bids.length} Live Bids' : '${_searchSeconds}s searching...',
                      style: TextStyle(
                        color: bids.isNotEmpty ? AppConstants.successColor : AppConstants.textLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: bids.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 80,
                              height: 80,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primaryColor),
                              ),
                            ),
                            const SizedBox(height: 28),
                            const Text(
                              'Broadcasting offer to nearby drivers...',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppConstants.textLight, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Drivers in your area are evaluating your route. Increase your offer to attract drivers faster.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppConstants.textMuted, fontSize: 13, height: 1.3),
                            ),
                            const SizedBox(height: 24),
                            // Quick Raise Offer Steppers
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppConstants.accentColor),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.arrow_upward_rounded, size: 14, color: AppConstants.accentColor),
                                  label: const Text('+₦200', style: TextStyle(color: AppConstants.accentColor, fontWeight: FontWeight.bold)),
                                  onPressed: () => _raiseCurrentOffer(200),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppConstants.accentColor),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.arrow_upward_rounded, size: 14, color: AppConstants.accentColor),
                                  label: const Text('+₦500', style: TextStyle(color: AppConstants.accentColor, fontWeight: FontWeight.bold)),
                                  onPressed: () => _raiseCurrentOffer(500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: bids.length,
                      itemBuilder: (ctx, index) {
                        final bid = bids[index];
                        final counterFare = bid['counterFareNgn'] ?? offerNgn;
                        final driverName = bid['driverName'] ?? 'Driver';
                        final rating = bid['rating']?.toString() ?? '4.9';
                        final trips = bid['tripsCount']?.toString() ?? '1,200+';
                        final vehicle = '${bid['vehicleColor'] ?? ''} ${bid['vehicleMake'] ?? ''} ${bid['vehicleModel'] ?? ''}'.trim();
                        final plate = bid['licensePlate'] ?? '';
                        final eta = bid['etaMinutes'] ?? 4;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppConstants.cardBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppConstants.primaryLight.withOpacity(0.35), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: AppConstants.primaryColor.withOpacity(0.3),
                                    child: Text(
                                      driverName.isNotEmpty ? driverName[0].toUpperCase() : 'D',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              driverName,
                                              style: const TextStyle(color: AppConstants.textLight, fontSize: 16, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(width: 6),
                                            const Icon(Icons.verified, color: Color(0xFF10B981), size: 15),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(Icons.star_rounded, size: 15, color: AppConstants.accentColor),
                                            const SizedBox(width: 4),
                                            Text(rating, style: const TextStyle(color: AppConstants.textLight, fontSize: 12, fontWeight: FontWeight.bold)),
                                            const SizedBox(width: 6),
                                            Text('($trips trips)', style: const TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                                            const SizedBox(width: 8),
                                            Text('• ${eta}m away', style: const TextStyle(color: AppConstants.accentColor, fontSize: 12, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    currencyFormat.format(counterFare),
                                    style: const TextStyle(color: AppConstants.accentColor, fontSize: 22, fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppConstants.surfaceBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.directions_car, size: 16, color: AppConstants.textMuted),
                                    const SizedBox(width: 8),
                                    Text(
                                      vehicle.isEmpty ? 'Inspected Sedan' : vehicle,
                                      style: const TextStyle(color: AppConstants.textLight, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6)),
                                      child: Text(plate, style: const TextStyle(color: AppConstants.textLight, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppConstants.successColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () => provider.acceptDriverBid(bid),
                                  child: Text(
                                    'Accept Driver for ${currencyFormat.format(counterFare)}',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../providers/passenger_provider.dart';
import 'tracking_screen.dart';

class OfferRoomScreen extends StatelessWidget {
  const OfferRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PassengerProvider>();
    final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
    final ride = provider.currentRide;
    final bids = provider.incomingBids;

    // If ride was accepted, transition to tracking
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
          icon: const Icon(Icons.arrow_back, color: AppConstants.textLight),
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
              padding: const EdgeInsets.all(16),
              color: AppConstants.cardBg,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your Proposed Fare', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                      Text(
                        currencyFormat.format(ride?['rider_offer_ngn'] ?? 0),
                        style: const TextStyle(color: AppConstants.accentColor, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${bids.length} Offers Received',
                      style: const TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 13),
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
                              'Broadcasting your offer to nearby drivers...',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppConstants.textLight, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Drivers with active subscriptions in your area are reviewing your trip now.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppConstants.textMuted, fontSize: 13),
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
                        final counterFare = bid['counterFareNgn'] ?? 0;
                        final driverName = bid['driverName'] ?? 'Driver';
                        final vehicle = '${bid['vehicleColor'] ?? ''} ${bid['vehicleMake'] ?? ''} ${bid['vehicleModel'] ?? ''}'.trim();
                        final plate = bid['licensePlate'] ?? '';
                        final eta = bid['etaMinutes'] ?? 5;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppConstants.cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppConstants.primaryColor.withOpacity(0.4), width: 1.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: AppConstants.primaryColor.withOpacity(0.3),
                                    child: const Icon(Icons.person, color: AppConstants.textLight),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          driverName,
                                          style: const TextStyle(color: AppConstants.textLight, fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                        Row(
                                          children: [
                                            const Icon(Icons.star, size: 14, color: AppConstants.accentColor),
                                            const SizedBox(width: 4),
                                            const Text('4.9', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                                            const SizedBox(width: 8),
                                            Text('• $eta mins away', style: const TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    currencyFormat.format(counterFare),
                                    style: const TextStyle(color: AppConstants.accentColor, fontSize: 22, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.directions_car, size: 18, color: AppConstants.textMuted),
                                    const SizedBox(width: 8),
                                    Text(
                                      vehicle.isEmpty ? 'Verified Vehicle' : vehicle,
                                      style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.w600),
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
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

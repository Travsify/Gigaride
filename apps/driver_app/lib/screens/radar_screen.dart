import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../providers/driver_provider.dart';
import 'subscription_screen.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriverProvider>();
    final activeTrip = provider.activeTrip;

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      appBar: AppBar(
        backgroundColor: AppConstants.cardBg,
        elevation: 1,
        title: Row(
          children: [
            const Icon(Icons.radar, color: AppConstants.accentColor),
            const SizedBox(width: 8),
            Text(
              provider.isOnline ? 'Radar Active' : 'Offline',
              style: const TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          // Remaining rides pill
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: provider.hasActiveSubscription
                    ? AppConstants.primaryColor.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: provider.hasActiveSubscription ? AppConstants.primaryColor : Colors.red,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.bolt,
                    size: 16,
                    color: provider.hasActiveSubscription ? AppConstants.accentColor : Colors.redAccent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    provider.remainingRides > 9999 ? '∞ Rides' : '${provider.remainingRides} Rides',
                    style: TextStyle(
                      color: provider.hasActiveSubscription ? AppConstants.textLight : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.add_circle, size: 14, color: AppConstants.accentColor),
                ],
              ),
            ),
          ),
          Switch(
            value: provider.isOnline,
            activeColor: AppConstants.primaryColor,
            onChanged: (_) => provider.toggleOnline(),
          ),
        ],
      ),
      body: activeTrip != null
          ? _buildActiveTripView(context, provider, activeTrip)
          : _buildRadarView(context, provider),
    );
  }

  Widget _buildRadarView(BuildContext context, DriverProvider provider) {
    if (!provider.isOnline) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pause_circle_outline, size: 72, color: AppConstants.textMuted),
            const SizedBox(height: 16),
            const Text('You are currently Offline', style: TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Switch toggle in the top bar to start receiving rides', style: TextStyle(color: AppConstants.textMuted, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
              onPressed: () => provider.toggleOnline(),
              child: const Text('Go Online', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (!provider.hasActiveSubscription) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_clock, size: 72, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text('Ride Subscription Exhausted', style: TextStyle(color: AppConstants.textLight, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'You have completed all rides in your current package. You will not be visible on the map until you subscribe for more rides.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppConstants.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.flash_on, color: Colors.black),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.accentColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
                },
                label: const Text('Recharge Subscription Now', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.incomingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 90,
              height: 90,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primaryColor),
              ),
            ),
            const SizedBox(height: 28),
            const Text('Scanning for Nearby Passengers...', style: TextStyle(color: AppConstants.textLight, fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Showing requests within 7km. 0% platform commission.',
              style: TextStyle(color: AppConstants.textMuted.withOpacity(0.8), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.incomingRequests.length,
      itemBuilder: (ctx, index) {
        final req = provider.incomingRequests[index];
        final riderOffer = req['riderOfferNgn'] ?? 0;
        final pickupDist = req['driverPickupDistanceKm'] ?? 1.2;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppConstants.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppConstants.accentColor.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
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
                      const Icon(Icons.near_me, size: 16, color: AppConstants.accentColor),
                      const SizedBox(width: 4),
                      Text(
                        '${pickupDist} km away to pickup',
                        style: const TextStyle(color: AppConstants.accentColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Passenger Offer: ${currencyFormat.format(riderOffer)}',
                      style: const TextStyle(color: AppConstants.successColor, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white10, height: 20),
              // Pickup & Dropoff
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Column(
                    children: [
                      Icon(Icons.circle, size: 12, color: Colors.green),
                      SizedBox(height: 18),
                      Icon(Icons.location_on, size: 14, color: Colors.red),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          req['pickupAddress'] ?? 'Pickup location',
                          style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          req['dropoffAddress'] ?? 'Dropoff location',
                          style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Quick Counter-Offer:', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
              const SizedBox(height: 8),
              // One-tap negotiation counter buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.successColor,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => provider.submitCounterOffer(req['rideId'], riderOffer, 4),
                      child: Text('Accept ${currencyFormat.format(riderOffer)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppConstants.accentColor),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => provider.submitCounterOffer(req['rideId'], riderOffer + 500, 4),
                      child: Text('+₦500', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppConstants.accentColor)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppConstants.accentColor),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => provider.submitCounterOffer(req['rideId'], riderOffer + 1000, 4),
                      child: Text('+₦1,000', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppConstants.accentColor)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveTripView(BuildContext context, DriverProvider provider, Map<String, dynamic> trip) {
    final agreedFare = trip['agreedFareNgn'] ?? 0;
    final step = provider.tripStep ?? 'ACCEPTED';

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppConstants.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppConstants.primaryColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Trip in Progress', style: TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(currencyFormat.format(agreedFare), style: const TextStyle(color: AppConstants.accentColor, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(color: Colors.white12, height: 24),
                Text('Pickup: ${trip['pickupAddress']}', style: const TextStyle(color: AppConstants.textLight, fontSize: 13)),
                const SizedBox(height: 8),
                Text('Dropoff: ${trip['dropoffAddress']}', style: const TextStyle(color: AppConstants.textMuted, fontSize: 13)),
              ],
            ),
          ),
          const Spacer(),
          // Trip progression actions
          if (step == 'ACCEPTED')
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check, color: Colors.white),
                style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
                onPressed: () => provider.updateTripStatus('ARRIVED'),
                label: const Text('I Have Arrived at Pickup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            )
          else if (step == 'ARRIVED')
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.directions_car, color: Colors.black),
                style: ElevatedButton.styleFrom(backgroundColor: AppConstants.accentColor),
                onPressed: () => provider.updateTripStatus('IN_TRANSIT'),
                label: const Text('Start Trip (Passenger in Car)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
              ),
            )
          else if (step == 'IN_TRANSIT')
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.done_all, color: Colors.white),
                style: ElevatedButton.styleFrom(backgroundColor: AppConstants.successColor),
                onPressed: () => provider.updateTripStatus('COMPLETED'),
                label: const Text('End Trip & Collect Cash (1 Ride Deducted)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../providers/passenger_provider.dart';
import 'home_screen.dart';

class RideTrackingScreen extends StatelessWidget {
  const RideTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PassengerProvider>();
    final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
    final driver = provider.selectedDriverBid;
    final status = provider.tripStatus ?? 'ACCEPTED';

    if (status == 'COMPLETED') {
      return Scaffold(
        backgroundColor: AppConstants.darkBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 84, color: AppConstants.successColor),
                const SizedBox(height: 20),
                const Text('You Have Arrived!', style: TextStyle(color: AppConstants.textLight, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Hope you enjoyed your ride.', style: TextStyle(color: AppConstants.textMuted, fontSize: 14)),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppConstants.cardBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text('Total Agreed Fare', style: TextStyle(color: AppConstants.textMuted, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(provider.finalFarePaid ?? driver?['counterFareNgn'] ?? 0),
                        style: const TextStyle(color: AppConstants.accentColor, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                      const Divider(color: Colors.white12, height: 24),
                      const Text(
                        'Pay driver via Cash or Instant Bank Transfer. (Zero commission platform - driver keeps 100%).',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppConstants.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
                    onPressed: () {
                      provider.resetTrip();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (r) => false,
                      );
                    },
                    child: const Text('Book Another Ride', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      appBar: AppBar(
        backgroundColor: AppConstants.cardBg,
        elevation: 0,
        title: const Text('Live Ride Tracking', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppConstants.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppConstants.primaryColor.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppConstants.primaryColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        status == 'ARRIVED' ? Icons.hail : Icons.directions_car,
                        color: AppConstants.accentColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            status == 'ACCEPTED'
                                ? 'Driver is on the way'
                                : status == 'ARRIVED'
                                    ? 'Driver has arrived outside!'
                                    : 'On trip to destination',
                            style: const TextStyle(color: AppConstants.textLight, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            status == 'ACCEPTED'
                                ? 'ETA ~${driver?['etaMinutes'] ?? 4} mins'
                                : status == 'ARRIVED'
                                    ? 'Look out for vehicle'
                                    : 'Heading to dropoff',
                            style: const TextStyle(color: AppConstants.textMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Driver & Vehicle Details Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppConstants.cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppConstants.primaryColor.withOpacity(0.3),
                          child: const Icon(Icons.person, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                driver?['driverName'] ?? 'Driver',
                                style: const TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${driver?['vehicleColor'] ?? ''} ${driver?['vehicleMake'] ?? ''} ${driver?['vehicleModel'] ?? ''}',
                                style: const TextStyle(color: AppConstants.textMuted, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            driver?['licensePlate'] ?? '',
                            style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Agreed Price:', style: TextStyle(color: AppConstants.textMuted, fontSize: 14)),
                        Text(
                          currencyFormat.format(driver?['counterFareNgn'] ?? 0),
                          style: const TextStyle(color: AppConstants.accentColor, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Safety SOS & Emergency
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.phone, color: AppConstants.textLight),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {},
                      label: const Text('Call Driver', style: TextStyle(color: AppConstants.textLight)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.shield_outlined, color: Colors.white),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.dangerColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('SOS Emergency Link Shared. Emergency contacts alerted.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      },
                      label: const Text('Emergency SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

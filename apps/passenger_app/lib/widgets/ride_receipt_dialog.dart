import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../services/receipt_pdf_service.dart';

class RideReceiptDialog extends StatelessWidget {
  final Map<String, dynamic> rideData;

  const RideReceiptDialog({super.key, required this.rideData});

  static void show(BuildContext context, Map<String, dynamic> rideData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RideReceiptDialog(rideData: rideData),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

    // Extract details safely
    final rideId = (rideData['id'] ?? rideData['rideId'] ?? 'GIGA-TRIP').toString();
    final shortId = rideId.length > 8 ? rideId.substring(0, 8).toUpperCase() : rideId.toUpperCase();
    final date = rideData['date'] ??
        rideData['created_at']?.toString().split('T')[0] ??
        DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    final pickup = (rideData['pickup_address'] ??
            rideData['pickupAddress'] ??
            rideData['pickup'] ??
            'Pickup Location')
        .toString();
    final dropoff = (rideData['dropoff_address'] ??
            rideData['dropoffAddress'] ??
            rideData['dropoff'] ??
            'Destination')
        .toString();

    final fareVal = (rideData['finalFarePaid'] ??
            rideData['agreedFareNgn'] ??
            rideData['agreed_fare_ngn'] ??
            rideData['counterFareNgn'] ??
            rideData['counter_fare_ngn'] ??
            rideData['fareNgn'] ??
            rideData['fare'] ??
            3000) as num;
    final fare = fareVal.toInt();

    final driverName = (rideData['driverName'] ??
            rideData['driver_name'] ??
            rideData['driver']?['fullName'] ??
            rideData['driver']?['full_name'] ??
            'Giga Partner Driver')
        .toString();
    final vehicle = (rideData['vehicleModel'] ??
            rideData['vehicle_model'] ??
            rideData['vehicle'] ??
            'Standard Ride')
        .toString();
    final plate = (rideData['licensePlate'] ??
            rideData['license_plate'] ??
            rideData['plate'] ??
            'LAG-000-XX')
        .toString();

    final paymentMethod = (rideData['paymentMethod'] ??
            rideData['payment_method'] ??
            'Giga Living Wallet (Instant Settlement)')
        .toString();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: AppConstants.darkBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Scrollable Receipt Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Receipt Card Container
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppConstants.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          // Header: Brand & Legal Entity
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'GIGA RIDE',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Giga is a Product of Pickpadi Global Ltd',
                                    style: TextStyle(
                                      color: AppConstants.accentColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppConstants.successColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppConstants.successColor.withOpacity(0.4)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, color: AppConstants.successColor, size: 13),
                                    SizedBox(width: 4),
                                    Text(
                                      'PAID',
                                      style: TextStyle(
                                        color: AppConstants.successColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          const Divider(color: Colors.white12, height: 1),
                          const SizedBox(height: 16),

                          // Receipt Meta (Ref & Date)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Receipt Ref', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text('#$shortId', style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Date & Time', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text(date, style: const TextStyle(color: AppConstants.textLight, fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          const Divider(color: Colors.white12, height: 1),
                          const SizedBox(height: 16),

                          // Route Section
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  const Icon(Icons.trip_origin_rounded, color: AppConstants.successColor, size: 16),
                                  Container(width: 2, height: 26, color: Colors.white12),
                                  const Icon(Icons.location_on_rounded, color: AppConstants.dangerColor, size: 16),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(pickup, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppConstants.textLight, fontSize: 13)),
                                    const SizedBox(height: 14),
                                    Text(dropoff, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          const Divider(color: Colors.white12, height: 1),
                          const SizedBox(height: 16),

                          // Driver & Vehicle Section
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppConstants.surfaceBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppConstants.primaryColor.withOpacity(0.25),
                                  child: const Icon(Icons.person, color: AppConstants.primaryLight, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(driverName, style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text('$vehicle • $plate', style: const TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),
                          const Divider(color: Colors.white12, height: 1),
                          const SizedBox(height: 16),

                          // Itemized Financial Breakdown
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Agreed Trip Fare', style: TextStyle(color: AppConstants.textMuted, fontSize: 13)),
                              Text(currency.format(fare), style: const TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('Lagos State MOT Levy & Tax', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                              Text('₦50 (Included)', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('Platform Commission (0%)', style: TextStyle(color: AppConstants.successColor, fontSize: 12, fontWeight: FontWeight.bold)),
                              Text('₦0 (0% Cut)', style: TextStyle(color: AppConstants.successColor, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Payment Channel', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                              Text(paymentMethod, style: const TextStyle(color: AppConstants.primaryLight, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),

                          const SizedBox(height: 14),
                          const Divider(color: Colors.white24, height: 1),
                          const SizedBox(height: 14),

                          // Total Settled
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'TOTAL PAID',
                                style: TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                              Text(
                                currency.format(fare),
                                style: const TextStyle(color: AppConstants.accentColor, fontSize: 24, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Legal Footnote
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        children: [
                          Text(
                            'Official Ride Receipt • Pickpadi Global Ltd (RC Registered)',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Support & Dispute Resolution: support@getgigaride.com',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white38, fontSize: 10),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),

            // Bottom Actions: Share/Download Receipt & Close
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
                      label: const Text(
                        'Download PDF Receipt',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        ReceiptPdfService.generateAndShare(
                          shortId: shortId,
                          date: date,
                          pickup: pickup,
                          dropoff: dropoff,
                          driverName: driverName,
                          vehicle: vehicle,
                          plate: plate,
                          fareFormatted: currency.format(fare),
                          paymentMethod: paymentMethod,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


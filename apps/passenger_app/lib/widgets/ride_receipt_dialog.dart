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
    final numberFormat = NumberFormat('#,##0', 'en_US');

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
    final formattedNaira = currency.format(fare);
    final formattedNgn = 'NGN ${numberFormat.format(fare)}';

    final waitFareVal = (rideData['wait_fare_ngn'] ?? rideData['waitFareNgn'] ?? 0) as num;
    final waitFare = waitFareVal.toInt();
    final waitMinutes = ((rideData['billable_wait_minutes'] ?? rideData['billableWaitMinutes'] ?? 0) as num).toInt();
    final baseFareVal = (rideData['baseFareNgn'] ?? (fare - waitFare)) as num;
    final baseFare = baseFareVal.toInt();
    final formattedBaseNaira = currency.format(baseFare);
    final formattedBaseNgn = 'NGN ${numberFormat.format(baseFare)}';
    final formattedWaitNaira = currency.format(waitFare);
    final formattedWaitNgn = 'NGN ${numberFormat.format(waitFare)}';

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
            'Giga Wallet (Instant Settlement)')
        .toString();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
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
            const SizedBox(height: 14),

            // Scrollable Receipt Ticket Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Physical-Style Digital Receipt Container
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF131D2E),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFF223249), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.45),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Top Receipt Header with Notch Accent
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                            decoration: const BoxDecoration(
                              color: Color(0xFF172338),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(21)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppConstants.primaryColor.withOpacity(0.3),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'GIGA RIDE',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 19,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.3,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Pickpadi Global Ltd (RC Registered)',
                                          style: TextStyle(
                                            color: AppConstants.accentColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'PAID',
                                        style: TextStyle(
                                          color: Color(0xFF10B981),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Perforated Ticket Divider with Notches
                          _buildPerforatedDivider(),

                          // Inner Content Area
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                // Receipt Meta (Ref & Date)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('RECEIPT NUMBER', style: TextStyle(color: AppConstants.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                        const SizedBox(height: 3),
                                        Text('GIGA-$shortId', style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text('ISSUED DATE', style: TextStyle(color: AppConstants.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                        const SizedBox(height: 3),
                                        Text(date, style: const TextStyle(color: AppConstants.textLight, fontSize: 12, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),
                                const Divider(color: Colors.white10, height: 1),
                                const SizedBox(height: 16),

                                // Route Section
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      children: [
                                        const Icon(Icons.trip_origin_rounded, color: Color(0xFF10B981), size: 16),
                                        Container(width: 2, height: 28, color: Colors.white12),
                                        const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 16),
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
                                const Divider(color: Colors.white10, height: 1),
                                const SizedBox(height: 16),

                                // Driver & Vehicle Section
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white10),
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
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppConstants.accentColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text('100% Pay', style: TextStyle(color: AppConstants.accentColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),
                                const Divider(color: Colors.white10, height: 1),
                                const SizedBox(height: 16),

                                // Itemized Financial Breakdown (With NGN & Naira display)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Base Transportation Fare', style: TextStyle(color: AppConstants.textMuted, fontSize: 13)),
                                    Text('$formattedBaseNaira ($formattedBaseNgn)', style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                if (waitFare > 0) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Stopover Wait Time ($waitMinutes mins)', style: const TextStyle(color: AppConstants.accentColor, fontSize: 12, fontWeight: FontWeight.bold)),
                                      Text('$formattedWaitNaira ($formattedWaitNgn)', style: const TextStyle(color: AppConstants.accentColor, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: const [
                                    Text('Lagos State MOT Road Safety Levy', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                                    Text('₦50 (NGN 50.00 Included)', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: const [
                                    Text('Giga Platform Commission (0%)', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
                                    Text('₦0 (0% Cut)', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Payment Settlement', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                                    Text(paymentMethod, style: const TextStyle(color: AppConstants.primaryLight, fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),

                                const SizedBox(height: 14),
                                const Divider(color: Colors.white24, height: 1),
                                const SizedBox(height: 14),

                                // Total Settled Banner
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text('TOTAL PAID', style: TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                        Text('Zero Extra Deductions', style: TextStyle(color: AppConstants.textMuted, fontSize: 10)),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(formattedNaira, style: const TextStyle(color: AppConstants.accentColor, fontSize: 24, fontWeight: FontWeight.w900)),
                                        Text(formattedNgn, style: const TextStyle(color: AppConstants.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Authenticity Security Footer Strip
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0D1522),
                              borderRadius: BorderRadius.vertical(bottom: Radius.circular(21)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_outline_rounded, color: Color(0xFF10B981), size: 13),
                                SizedBox(width: 6),
                                Text(
                                  'AUTHENTIC ELECTRONIC INVOICE • CBN COMPLIANT AUDIT TRAIL',
                                  style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Legal Help Footnote
                    const Center(
                      child: Text(
                        'Support: support@getgigaride.com • Lagos, Nigeria',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
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
                          fareFormatted: formattedNgn,
                          paymentMethod: paymentMethod,
                          waitFareNgn: waitFare,
                          waitMinutes: waitMinutes,
                          baseFareNgn: baseFare,
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

  Widget _buildPerforatedDivider() {
    return Row(
      children: [
        // Left semicircular cutout
        Container(
          width: 14,
          height: 24,
          decoration: const BoxDecoration(
            color: AppConstants.darkBg,
            borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
          ),
        ),
        // Dashed horizontal line
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const dashWidth = 5.0;
              const dashSpace = 4.0;
              final dashCount = (constraints.constrainWidth() / (dashWidth + dashSpace)).floor();
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(dashCount, (_) {
                  return Container(
                    width: dashWidth,
                    height: 1.5,
                    color: Colors.white24,
                  );
                }),
              );
            },
          ),
        ),
        // Right semicircular cutout
        Container(
          width: 14,
          height: 24,
          decoration: const BoxDecoration(
            color: AppConstants.darkBg,
            borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
          ),
        ),
      ],
    );
  }
}

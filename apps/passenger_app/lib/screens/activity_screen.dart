import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/passenger_provider.dart';
import 'tracking_screen.dart';
import 'offer_room_screen.dart';
import '../widgets/ride_receipt_dialog.dart';

class ActivityScreen extends StatefulWidget {
  final VoidCallback onBookRidePressed;
  const ActivityScreen({super.key, required this.onBookRidePressed});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PassengerProvider>().loadRiderHistory();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showReceiptModal(BuildContext context, dynamic ride) {
    HapticFeedback.lightImpact();
    RideReceiptDialog.show(context, Map<String, dynamic>.from(ride));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PassengerProvider>();

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Your Activity',
          style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppConstants.textMuted),
            onPressed: () => provider.loadRiderHistory(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppConstants.primaryLight,
          indicatorWeight: 3,
          labelColor: AppConstants.primaryLight,
          unselectedLabelColor: AppConstants.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Past Rides'),
            Tab(text: 'Scheduled Trips'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPastRidesTab(provider),
          _buildScheduledTripsTab(provider),
        ],
      ),
    );
  }

  Widget _buildPastRidesTab(PassengerProvider provider) {
    if (provider.isLoadingHistory) {
      return const Center(child: CircularProgressIndicator(color: AppConstants.primaryLight));
    }

    final rides = provider.pastRides;
    final activeRide = provider.currentRide;

    if (rides.isEmpty && activeRide == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppConstants.cardBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white10),
                ),
                child: const Icon(Icons.history_rounded, size: 48, color: AppConstants.textMuted),
              ),
              const SizedBox(height: 18),
              const Text(
                'No Completed Rides Yet',
                style: TextStyle(color: AppConstants.textLight, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your zero-commission completed trips and downloadable receipts will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppConstants.textMuted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.directions_car_rounded, color: Colors.white, size: 18),
                label: const Text('Book a Ride', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: widget.onBookRidePressed,
              ),
            ],
          ),
        ),
      );
    }

    final hasActive = activeRide != null && !['COMPLETED', 'CANCELLED'].contains(activeRide['status']);
    final totalCount = rides.length + (hasActive ? 1 : 0);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: totalCount,
      itemBuilder: (ctx, index) {
        if (hasActive && index == 0) {
          return _buildActiveRideCard(ctx, activeRide, provider);
        }
        final r = rides[hasActive ? index - 1 : index];
        final fare = r['agreed_fare_ngn'] ?? r['suggested_fare_ngn'] ?? r['rider_offer_ngn'] ?? 0;
        final pickup = r['pickup_address'] ?? 'Lagos';
        final dropoff = r['dropoff_address'] ?? 'Lagos';
        final date = r['created_at']?.toString().split('T')[0] ?? 'Recent';

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppConstants.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppConstants.successColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('COMPLETED • 0% COMMISSION', style: TextStyle(color: AppConstants.successColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  Text(date, style: const TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.my_location_rounded, color: AppConstants.accentColor, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(pickup, style: const TextStyle(color: AppConstants.textLight, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: AppConstants.dangerColor, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(dropoff, style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const Divider(color: Colors.white10, height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Fare Settled:', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                      Text(currencyFormat.format(fare), style: const TextStyle(color: AppConstants.accentColor, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.receipt_rounded, size: 14, color: AppConstants.textLight),
                        label: const Text('Receipt', style: TextStyle(color: AppConstants.textLight, fontSize: 11)),
                        onPressed: () => _showReceiptModal(context, r),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.replay_rounded, size: 14, color: Colors.white),
                        label: const Text('Re-book', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: widget.onBookRidePressed,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScheduledTripsTab(PassengerProvider provider) {
    if (provider.isLoadingHistory) {
      return const Center(child: CircularProgressIndicator(color: AppConstants.primaryLight));
    }

    final scheduled = provider.scheduledTrips;

    if (scheduled.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppConstants.cardBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white10),
                ),
                child: const Icon(Icons.flight_takeoff_rounded, size: 48, color: AppConstants.primaryLight),
              ),
              const SizedBox(height: 18),
              const Text(
                'No Scheduled Advance Trips',
                style: TextStyle(color: AppConstants.textLight, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Schedule your Airport VIP transfers and interstate travels hours or days in advance with guaranteed zero surge pricing.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppConstants.textMuted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 18),
                label: const Text('Schedule Airport VIP Ride', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: widget.onBookRidePressed,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: scheduled.length,
      itemBuilder: (ctx, index) {
        final s = scheduled[index];
        final isAirport = s['is_airport'] == true;
        final targetFare = s['rider_offer_ngn'] ?? 8000;
        final scheduledTime = s['scheduled_for'] != null ? s['scheduled_for'].toString().replaceFirst('T', ' • ').substring(0, 18) : 'Scheduled';
        final pickup = s['pickup_address'] ?? 'Pickup';
        final dropoff = s['dropoff_address'] ?? 'Airport';

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppConstants.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppConstants.primaryLight.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryLight.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isAirport ? '✈️ AIRPORT VIP TRANSFER' : '🛣️ INTERSTATE ADVANCE',
                      style: const TextStyle(color: AppConstants.primaryLight, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(scheduledTime, style: const TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 12),
              Text(pickup, style: const TextStyle(color: AppConstants.textLight, fontSize: 13)),
              const Icon(Icons.arrow_downward, color: Colors.white24, size: 14),
              Text(dropoff, style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.bold)),
              if (s['flight_number'] != null) ...[
                const SizedBox(height: 6),
                Text('Flight: ${s['flight_number']}', style: const TextStyle(color: AppConstants.accentColor, fontSize: 12)),
              ],
              const Divider(color: Colors.white10, height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(currencyFormat.format(targetFare), style: const TextStyle(color: AppConstants.accentColor, fontSize: 16, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                    child: const Text('Queued in Dispatch', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveRideCard(BuildContext context, dynamic ride, PassengerProvider provider) {
    final status = provider.tripStatus ?? ride['status'] ?? 'REQUESTED';
    final isAssigned = (status == 'ACCEPTED' || status == 'ARRIVED' || status == 'IN_TRANSIT');
    final driver = provider.selectedDriverBid;
    final driverName = driver?['driverName'] ?? 'Driver';
    final vehicle = driver?['vehicleModel'] ?? 'Verified Vehicle';
    final fare = provider.finalFarePaid ?? driver?['counterFareNgn'] ?? ride['riderOfferNgn'] ?? ride['rider_offer_ngn'] ?? 0;
    final pickup = ride['pickupAddress'] ?? ride['pickup_address'] ?? 'Pickup Point';
    final dropoff = ride['dropoffAddress'] ?? ride['dropoff_address'] ?? 'Dropoff Point';

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isAssigned
              ? [const Color(0xFF064E3B), const Color(0xFF0D9488)]
              : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isAssigned ? AppConstants.primaryLight : AppConstants.accentColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isAssigned ? AppConstants.primaryLight : AppConstants.accentColor).withOpacity(0.25),
            blurRadius: 16,
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
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isAssigned ? AppConstants.successColor : AppConstants.accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isAssigned ? 'ACTIVE TRIP IN PROGRESS' : 'BROADCASTING OFFER',
                    style: TextStyle(
                      color: isAssigned ? AppConstants.successColor : AppConstants.accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isAssigned ? AppConstants.successColor : AppConstants.accentColor).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: isAssigned ? AppConstants.successColor : AppConstants.accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Route
          Row(
            children: [
              const Icon(Icons.trip_origin_rounded, color: AppConstants.successColor, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pickup,
                  style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: AppConstants.accentColor, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dropoff,
                  style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAssigned ? '$driverName • $vehicle' : 'Fare Offered',
                    style: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currencyFormat.format(fare),
                    style: const TextStyle(color: AppConstants.accentColor, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAssigned ? AppConstants.primaryColor : AppConstants.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: Icon(isAssigned ? Icons.navigation_rounded : Icons.wifi_tethering_rounded, size: 16),
                label: Text(
                  isAssigned ? 'Track Live Ride' : 'View Offer Room',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                onPressed: () {
                  if (isAssigned) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RideTrackingScreen()));
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const OfferRoomScreen()));
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

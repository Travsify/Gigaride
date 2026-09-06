import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/passenger_provider.dart';

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
    final fare = ride['agreed_fare_ngn'] ?? ride['suggested_fare_ngn'] ?? ride['rider_offer_ngn'] ?? 2500;
    final pickup = ride['pickup_address'] ?? 'Pickup Point';
    final dropoff = ride['dropoff_address'] ?? 'Dropoff Point';
    final date = ride['created_at']?.toString().split('T')[0] ?? 'Today';
    final id = (ride['id'] ?? 'GIGA-TRIP').toString().substring(0, 8).toUpperCase();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.receipt_long_rounded, color: AppConstants.primaryLight, size: 24),
                      SizedBox(width: 10),
                      Text('Official Ride Receipt', style: TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close, color: AppConstants.textMuted), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppConstants.surfaceBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Receipt Ref', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                        Text('#$id', style: const TextStyle(color: AppConstants.textLight, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Date & Time', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                        Text(date, style: const TextStyle(color: AppConstants.textLight, fontSize: 12)),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.trip_origin_rounded, color: AppConstants.successColor, size: 14),
                        const SizedBox(width: 8),
                        Expanded(child: Text(pickup, style: const TextStyle(color: AppConstants.textLight, fontSize: 12))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_rounded, color: AppConstants.dangerColor, size: 14),
                        const SizedBox(width: 8),
                        Expanded(child: Text(dropoff, style: const TextStyle(color: AppConstants.textLight, fontSize: 12, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Driver Net Payout (100%)', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                        Text(currencyFormat.format(fare), style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Lagos State MOT Road Tax', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                        Text('₦50 (Included)', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Platform Commission Taken', style: TextStyle(color: AppConstants.successColor, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('₦0 (0% Cut)', style: TextStyle(color: AppConstants.successColor, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Settled Fare', style: TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold)),
                        Text(currencyFormat.format(fare), style: const TextStyle(color: AppConstants.accentColor, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
                  icon: const Icon(Icons.check, color: Colors.white, size: 18),
                  label: const Text('Close Receipt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rides.length,
      itemBuilder: (ctx, index) {
        final r = rides[index];
        final fare = r['agreed_fare_ngn'] ?? r['suggested_fare_ngn'] ?? 2500;
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
}

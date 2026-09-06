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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          // Tab 1: Past Rides
          _buildPastRidesTab(provider),
          // Tab 2: Scheduled Trips
          _buildScheduledTripsTab(provider),
        ],
      ),
    );
  }

  Widget _buildPastRidesTab(PassengerProvider provider) {
    // If active ride or past ride exists
    final activeRide = provider.currentRide;
    final tripStatus = provider.tripStatus;

    if (activeRide == null && tripStatus == null) {
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
                'No Recent Trips Yet',
                style: TextStyle(color: AppConstants.textLight, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'When you complete a ride, your zero-commission receipts and trip routes will appear here.',
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
                label: const Text('Book Your First Ride', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: widget.onBookRidePressed,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppConstants.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppConstants.primaryColor.withOpacity(0.3)),
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
                    child: Text(
                      tripStatus == 'COMPLETED' ? 'COMPLETED' : 'IN TRANSIT',
                      style: const TextStyle(color: AppConstants.successColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    DateFormat('MMM d, y • h:mm a').format(DateTime.now()),
                    style: const TextStyle(color: AppConstants.textMuted, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.my_location_rounded, color: AppConstants.accentColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      activeRide?['pickupAddress'] ?? 'Current Location',
                      style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(left: 7),
                child: SizedBox(
                  height: 14,
                  child: VerticalDivider(color: Colors.white24, width: 2),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: AppConstants.dangerColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      activeRide?['dropoffAddress'] ?? 'Destination',
                      style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white10, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Driver Received 100%:', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                  Text(
                    currencyFormat.format(activeRide?['riderOfferNgn'] ?? 2500),
                    style: const TextStyle(color: AppConstants.accentColor, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScheduledTripsTab(PassengerProvider provider) {
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
              child: const Icon(Icons.calendar_month_rounded, size: 48, color: AppConstants.primaryLight),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Scheduled Trips',
              style: TextStyle(color: AppConstants.textLight, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Schedule your Airport VIP transfers and interstate travel in advance with zero cancellation penalties.',
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
              icon: const Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 18),
              label: const Text('Schedule Airport VIP Ride', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: widget.onBookRidePressed,
            ),
          ],
        ),
      ),
    );
  }
}

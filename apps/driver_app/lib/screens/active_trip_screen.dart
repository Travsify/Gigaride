import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/driver_provider.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import '../services/navigation_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/driver_interactive_map.dart';
import 'driver_chat_sheet.dart';

int _extractFare(dynamic req) {
  if (req is! Map) return 3000;
  final val = req['agreedFareNgn'] ??
              req['agreed_fare_ngn'] ??
              req['counterFareNgn'] ??
              req['counter_fare_ngn'] ??
              req['riderOfferNgn'] ??
              req['rider_offer_ngn'] ??
              req['suggestedFareNgn'] ??
              req['suggested_fare_ngn'] ??
              req['fareNgn'] ??
              req['fare'];
  if (val is num && val > 0) return val.toInt();
  if (val is String) {
    final parsed = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), ''));
    if (parsed != null && parsed > 0) return parsed;
  }
  return 3000;
}

String _formatFare(dynamic amount) {
  final val = (amount is num ? amount.toInt() : int.tryParse(amount?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0);
  final displayVal = val > 0 ? val : 3000;
  return displayVal.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
}

class ActiveTripScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  const ActiveTripScreen({super.key, required this.trip});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  LatLng _driverLocation = LocationService.defaultLagosLocation;
  List<LatLng> _routePoints = [];
  double _distanceKm = 0.0;
  int _durationMins = 0;
  // Step state: 'ACCEPTED' -> 'ARRIVED' -> 'IN_TRANSIT' -> 'COMPLETED'
  String _currentStep = 'ACCEPTED';
  int _passengerRating = 5;

  @override
  void initState() {
    super.initState();
    final provider = context.read<DriverProvider>();
    _currentStep = provider.tripStep ?? 'ACCEPTED';
    _fetchDriverLocationAndRoute();
  }


  void _fetchDriverLocationAndRoute() async {
    final pos = await LocationService.getCurrentLocation();
    if (!mounted) return;
    setState(() => _driverLocation = pos);

    final pLat = (widget.trip['pickupLat'] as num?)?.toDouble() ?? 6.5244;
    final pLng = (widget.trip['pickupLng'] as num?)?.toDouble() ?? 3.3792;
    final dLat = (widget.trip['dropoffLat'] as num?)?.toDouble() ?? 6.4281;
    final dLng = (widget.trip['dropoffLng'] as num?)?.toDouble() ?? 3.4219;

    final targetStart = (_currentStep == 'ACCEPTED' || _currentStep == 'ARRIVED') ? pos : LatLng(pLat, pLng);
    final targetEnd = (_currentStep == 'ACCEPTED' || _currentStep == 'ARRIVED') ? LatLng(pLat, pLng) : LatLng(dLat, dLng);

    final route = await RoutingService.getDrivingRoute(targetStart, targetEnd);
    if (route != null && mounted) {
      setState(() {
        _routePoints = route.polyline;
        _distanceKm = route.distanceKm;
        _durationMins = route.durationMinutes;
      });
    }
  }

  void _progressStep() {
    final provider = context.read<DriverProvider>();
    if (_currentStep == 'ACCEPTED') {
      provider.updateTripStatus('ARRIVED');
      setState(() => _currentStep = 'ARRIVED');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status updated: You arrived at pickup point.'), backgroundColor: AppConstants.primaryColor),
      );
    } else if (_currentStep == 'ARRIVED') {
      provider.updateTripStatus('IN_TRANSIT');
      setState(() => _currentStep = 'IN_TRANSIT');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip started! Safe driving.'), backgroundColor: AppConstants.primaryColor),
      );
    } else if (_currentStep == 'IN_TRANSIT') {
      provider.updateTripStatus('COMPLETED');
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    final fare = _extractFare(widget.trip);
    final rideId = (widget.trip['rideId'] ?? widget.trip['id'] ?? widget.trip['ride_id'] ?? '').toString();
    int tenderedCash = fare;
    bool changeRolledOver = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final changeAmount = tenderedCash > fare ? tenderedCash - fare : 0;

          return AlertDialog(
            backgroundColor: AppConstants.cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppConstants.successColor, size: 28),
                SizedBox(width: 10),
                Text('Trip Completed!', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppConstants.darkBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppConstants.successColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Trip Fare', style: TextStyle(color: AppConstants.textMuted, fontSize: 13)),
                            Text('₦${_formatFare(fare)}', style: const TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Giga Commission (0%)', style: TextStyle(color: AppConstants.successColor, fontSize: 13, fontWeight: FontWeight.bold)),
                            Text('₦0.00', style: TextStyle(color: AppConstants.successColor, fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        const Divider(color: Colors.white10, height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('You Keep (100%)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                            Text('₦${_formatFare(fare)}', style: const TextStyle(color: AppConstants.accentColor, fontWeight: FontWeight.w900, fontSize: 18)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Cash Change Rollover to Living Wallet ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppConstants.surfaceBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: changeAmount > 0 ? Colors.amber.withOpacity(0.4) : Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.account_balance_wallet_rounded, color: AppConstants.primaryLight, size: 18),
                            SizedBox(width: 8),
                            Text('Cash Tendered & Change', style: TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ChoiceChip(
                              label: const Text('Exact', style: TextStyle(fontSize: 11)),
                              selected: tenderedCash == fare,
                              selectedColor: AppConstants.primaryColor,
                              backgroundColor: AppConstants.darkBg,
                              onSelected: (_) {
                                setDialogState(() => tenderedCash = fare);
                              },
                            ),
                            if (fare < 5000)
                              ChoiceChip(
                                label: const Text('₦5,000 Note', style: TextStyle(fontSize: 11)),
                                selected: tenderedCash == 5000,
                                selectedColor: AppConstants.primaryColor,
                                backgroundColor: AppConstants.darkBg,
                                onSelected: (_) {
                                  setDialogState(() => tenderedCash = 5000);
                                },
                              ),
                            if (fare < 10000)
                              ChoiceChip(
                                label: const Text('₦10,000 Note', style: TextStyle(fontSize: 11)),
                                selected: tenderedCash == 10000,
                                selectedColor: AppConstants.primaryColor,
                                backgroundColor: AppConstants.darkBg,
                                onSelected: (_) {
                                  setDialogState(() => tenderedCash = 10000);
                                },
                              ),
                          ],
                        ),
                        if (changeAmount > 0) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.amber.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Change Due:', style: TextStyle(color: AppConstants.textMuted, fontSize: 10)),
                                    Text('₦${_formatFare(changeAmount)}', style: const TextStyle(color: Colors.amberAccent, fontSize: 15, fontWeight: FontWeight.w900)),
                                  ],
                                ),
                                if (!changeRolledOver)
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppConstants.primaryColor,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.send_to_mobile_rounded, size: 13, color: Colors.white),
                                    label: const Text('Roll to Wallet', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: () {
                                      final provider = context.read<DriverProvider>();
                                      provider.socket.socket?.emit('ride:settle_change_to_wallet', {
                                        'rideId': rideId,
                                        'tenderedNgn': tenderedCash,
                                        'agreedFareNgn': fare,
                                      });
                                      setDialogState(() => changeRolledOver = true);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('✓ ₦${_formatFare(changeAmount)} rolled over to passenger wallet! Keep cash.'),
                                          backgroundColor: AppConstants.successColor,
                                        ),
                                      );
                                    },
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: AppConstants.successColor.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle_rounded, color: AppConstants.successColor, size: 14),
                                        SizedBox(width: 4),
                                        Text('Rolled Over', style: TextStyle(color: AppConstants.successColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text('Rate Passenger:', style: TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (idx) {
                      return IconButton(
                        icon: Icon(
                          idx < _passengerRating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: AppConstants.accentColor,
                          size: 32,
                        ),
                        onPressed: () {
                          setDialogState(() => _passengerRating = idx + 1);
                          setState(() => _passengerRating = idx + 1);
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: const Text('Return to Radar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _triggerSos() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppConstants.dangerColor, size: 28),
            SizedBox(width: 8),
            Text('Trigger Emergency SOS?', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'This streams your vehicle license plate, live GPS coordinates, and trip ID to Lagos State Emergency Dispatch Operations and Police.',
          style: TextStyle(color: AppConstants.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppConstants.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.dangerColor),
            onPressed: () {
              Navigator.pop(ctx);
              final provider = context.read<DriverProvider>();
              final rideId = (widget.trip['rideId'] ?? widget.trip['id'] ?? widget.trip['ride_id'] ?? '').toString();
              provider.socket.socket?.emit('ride:sos_trigger', {
                'rideId': rideId,
                'latitude': _driverLocation.latitude,
                'longitude': _driverLocation.longitude,
                'notes': 'Driver emergency button tapped',
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🚨 SOS Alert broadcast to Lagos Security Dispatch!'), backgroundColor: AppConstants.dangerColor),
              );
            },
            child: const Text('Confirm SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fare = _extractFare(widget.trip);
    final pickup = widget.trip['pickupAddress'] ?? 'Pickup Location';
    final dropoff = widget.trip['dropoffAddress'] ?? 'Destination Location';
    final gateCode = widget.trip['gateCode'] ?? widget.trip['estateGateCode'];
    final riderType = widget.trip['riderType'] ?? widget.trip['rider_type'] ?? 'SELF';
    final isFriend = riderType == 'FRIEND';
    final riderName = (widget.trip['riderName'] ?? widget.trip['rider_name'] ?? widget.trip['passengerName'] ?? widget.trip['passenger_name'] ?? 'Passenger').toString();
    final riderPhone = widget.trip['riderPhone'] ?? widget.trip['rider_phone'] ?? widget.trip['passengerPhone'] ?? widget.trip['passenger_phone'];
    final bookerName = widget.trip['bookerName'] ?? widget.trip['booker_name'];
    final notes = widget.trip['notes'] ?? widget.trip['tripInstructions'];

    String actionTitle = 'I Have Arrived at Pickup';
    Color actionColor = AppConstants.primaryColor;
    if (_currentStep == 'ARRIVED') {
      actionTitle = 'Start Trip (Passenger Onboard)';
      actionColor = Colors.cyan.shade700;
    } else if (_currentStep == 'IN_TRANSIT') {
      actionTitle = 'Complete Trip';
      actionColor = AppConstants.successColor;
    }

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: actionColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: actionColor.withOpacity(0.4)),
              ),
              child: Text(
                _currentStep == 'ACCEPTED' ? 'HEADING TO PICKUP' : (_currentStep == 'ARRIVED' ? 'AT PICKUP' : 'IN TRANSIT'),
                style: TextStyle(color: actionColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppConstants.accentColor, size: 24),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => DriverChatSheet(
                  rideId: (widget.trip['rideId'] ?? widget.trip['id'] ?? '').toString(),
                  passengerId: (widget.trip['riderId'] ?? widget.trip['passengerId'] ?? widget.trip['rider_id'] ?? '').toString(),
                  passengerName: riderName,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.sos_rounded, color: AppConstants.dangerColor, size: 28),
            onPressed: _triggerSos,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Fare Banner
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppConstants.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Agreed Trip Fare', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                            Text('0% Commission Dedicated', style: TextStyle(color: AppConstants.successColor, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Text(
                          '₦${_formatFare(fare)}',
                          style: const TextStyle(color: AppConstants.accentColor, fontSize: 24, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Real-Time Road Navigation Map
                  DriverInteractiveMap(
                    driverLocation: _driverLocation,
                    isOnline: true,
                    activeTrip: widget.trip,
                    routePoints: _routePoints,
                    height: 230,
                  ),

                  const SizedBox(height: 12),

                  // 1-Tap Google Maps Turn-by-Turn Navigation Launcher
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.navigation_rounded, color: Colors.blueAccent, size: 22),
                      label: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentStep == 'ACCEPTED' || _currentStep == 'ARRIVED'
                                ? 'Navigate to Pickup Point'
                                : 'Navigate to Destination',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          if (_distanceKm > 0)
                            Text(
                              ' (${_distanceKm.toStringAsFixed(1)} km • ~$_durationMins mins)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueAccent),
                            ),
                        ],
                      ),
                      onPressed: () {
                        final pLat = (widget.trip['pickupLat'] as num?)?.toDouble() ?? 6.5244;
                        final pLng = (widget.trip['pickupLng'] as num?)?.toDouble() ?? 3.3792;
                        final dLat = (widget.trip['dropoffLat'] as num?)?.toDouble() ?? 6.4281;
                        final dLng = (widget.trip['dropoffLng'] as num?)?.toDouble() ?? 3.4219;

                        final target = (_currentStep == 'ACCEPTED' || _currentStep == 'ARRIVED')
                            ? LatLng(pLat, pLng)
                            : LatLng(dLat, dLng);

                        final label = (_currentStep == 'ACCEPTED' || _currentStep == 'ARRIVED')
                            ? (widget.trip['pickupAddress'] ?? 'Pickup')
                            : (widget.trip['dropoffAddress'] ?? 'Destination');

                        NavigationHelper.launchExternalNavigation(
                          destination: target,
                          destinationLabel: label,
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Route Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppConstants.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.circle, color: AppConstants.primaryLight, size: 14),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Pickup Location', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text(pickup, style: const TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 6, top: 4, bottom: 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(height: 18, child: VerticalDivider(color: Colors.white24, thickness: 1.5)),
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_rounded, color: AppConstants.accentColor, size: 16),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Destination', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text(dropoff, style: const TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Estate Gate Code Banner (If present)
                  if (gateCode != null && gateCode.toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.door_front_door_rounded, color: Colors.amberAccent, size: 24),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Estate Gate Pass Code', style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(gateCode.toString(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Passenger Details Card (Shows Friend info if booked for someone else)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppConstants.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isFriend ? Colors.amber.withOpacity(0.4) : Colors.white10,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: isFriend ? Colors.amber.withOpacity(0.2) : AppConstants.surfaceBg,
                              child: Icon(
                                isFriend ? Icons.people_alt_rounded : Icons.person_rounded,
                                color: isFriend ? Colors.amberAccent : AppConstants.primaryLight,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          riderName,
                                          style: const TextStyle(
                                            color: AppConstants.textLight,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isFriend)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.amber.withOpacity(0.4)),
                                          ),
                                          child: const Text(
                                            'FRIEND RIDER',
                                            style: TextStyle(
                                              color: Colors.amberAccent,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isFriend && bookerName != null
                                        ? 'Booked by $bookerName${riderPhone != null ? ' • $riderPhone' : ''}'
                                        : (riderPhone != null ? 'Phone: $riderPhone' : 'Giga Verified Passenger'),
                                    style: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (notes != null && notes.toString().trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          // Comfort Requirement Badges
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (notes.toString().contains('AC: Must Be ON') || notes.toString().contains('Comfort AC'))
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.cyan.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.4)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.ac_unit_rounded, color: Colors.cyanAccent, size: 13),
                                      SizedBox(width: 4),
                                      Text('AC ON Required', style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              if (notes.toString().contains('Quiet Ride'))
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.purpleAccent.withOpacity(0.4)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.volume_off_rounded, color: Colors.purpleAccent, size: 13),
                                      SizedBox(width: 4),
                                      Text('Quiet Ride Requested', style: TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              if (notes.toString().contains('Luggage Assistance'))
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.amberAccent.withOpacity(0.4)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.luggage_rounded, color: Colors.amberAccent, size: 13),
                                      SizedBox(width: 4),
                                      Text('Luggage Assistance', style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppConstants.surfaceBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.speaker_notes_outlined, color: AppConstants.accentColor, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Note: ${notes.toString()}',
                                    style: const TextStyle(color: AppConstants.textLight, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Communication Options Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppConstants.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildAction(Icons.phone_in_talk_rounded, isFriend ? 'Call Friend' : 'Call Rider', () async {
                          if (riderPhone != null && riderPhone.toString().isNotEmpty) {
                            final uri = Uri.parse('tel:${riderPhone.toString().replaceAll(RegExp(r'[^0-9+]'), '')}');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Cannot launch phone dialer for $riderPhone')),
                                );
                              }
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No passenger phone number provided.')),
                            );
                          }
                        }),
                        _buildAction(Icons.navigation_rounded, 'Google Maps', () {
                          final pLat = (widget.trip['pickupLat'] as num?)?.toDouble() ?? 6.5244;
                          final pLng = (widget.trip['pickupLng'] as num?)?.toDouble() ?? 3.3792;
                          final dLat = (widget.trip['dropoffLat'] as num?)?.toDouble() ?? 6.4281;
                          final dLng = (widget.trip['dropoffLng'] as num?)?.toDouble() ?? 3.4219;
                          final target = (_currentStep == 'ACCEPTED' || _currentStep == 'ARRIVED')
                              ? LatLng(pLat, pLng)
                              : LatLng(dLat, dLng);
                          final label = (_currentStep == 'ACCEPTED' || _currentStep == 'ARRIVED')
                              ? (widget.trip['pickupAddress'] ?? 'Pickup')
                              : (widget.trip['dropoffAddress'] ?? 'Destination');
                          NavigationHelper.launchExternalNavigation(
                            destination: target,
                            destinationLabel: label,
                          );
                        }),
                        _buildAction(Icons.chat_bubble_outline_rounded, 'In-App Chat', () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => DriverChatSheet(
                              rideId: (widget.trip['rideId'] ?? widget.trip['id'] ?? '').toString(),
                              passengerId: (widget.trip['riderId'] ?? widget.trip['passengerId'] ?? widget.trip['rider_id'] ?? '').toString(),
                              passengerName: riderName,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Progress Action Button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: actionColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: _progressStep,
                  child: Text(actionTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppConstants.surfaceBg, shape: BoxShape.circle),
              child: Icon(icon, color: AppConstants.primaryLight, size: 20),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: AppConstants.textLight, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

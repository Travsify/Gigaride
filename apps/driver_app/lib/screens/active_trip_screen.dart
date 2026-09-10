import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/driver_provider.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import '../services/navigation_helper.dart';
import '../widgets/driver_interactive_map.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'driver_chat_sheet.dart';
import 'in_app_call_screen.dart';

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
  int _unreadChatMessages = 0;
  bool _isChatSheetOpen = false;

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    final provider = context.read<DriverProvider>();
    _currentStep = provider.tripStep ?? 'ACCEPTED';
    _fetchDriverLocationAndRoute();

    // 📞 Listen for incoming in-app call from rider
    provider.socket.onIncomingCall = (callData) {
      if (mounted) {
        _showIncomingCallSheet(callData);
      }
    };

    // 🚨 Listen for passenger cancelling ride
    provider.socket.onRideCancelled = (cancelData) {
      if (mounted) {
        _showRideCancelledModal(cancelData);
      }
    };

    // 💬 Listen for incoming messages from passenger
    provider.socket.onChatMessage = (msgData) {
      if (mounted) {
        _handleIncomingChatMessage(msgData);
      }
    };

    // 💡 Keep driver navigation screen awake throughout trip
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  void _showRideCancelledModal(Map<String, dynamic> cancelData) {
    HapticFeedback.heavyImpact();
    final reason = cancelData['reason']?.toString() ?? 'Passenger cancelled this ride.';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppConstants.dangerColor, width: 1.5)),
        title: Row(
          children: const [
            Icon(Icons.cancel_rounded, color: AppConstants.dangerColor, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ride Cancelled',
                style: TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The passenger has cancelled this trip request.',
              style: TextStyle(color: AppConstants.textLight, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppConstants.surfaceBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Stated Reason:', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(
                    reason,
                    style: const TextStyle(color: AppConstants.accentColor, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Your terminal has returned to active radar mode with 0% platform commission.',
              style: TextStyle(color: AppConstants.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                final provider = context.read<DriverProvider>();
                provider.clearActiveTrip();
                Navigator.of(context).pop();
              },
              child: const Text('Return to Radar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  void _handleIncomingChatMessage(Map<String, dynamic> msgData) {
    if (!_isChatSheetOpen) {
      HapticFeedback.mediumImpact();
      setState(() {
        _unreadChatMessages++;
      });
      final text = msgData['text']?.toString() ?? 'New message';
      final riderName = widget.trip['passengerName'] ?? widget.trip['riderName'] ?? widget.trip['rider_name'] ?? 'Passenger';
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF13202E),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          content: Row(
            children: [
              const Icon(Icons.chat_bubble_rounded, color: AppConstants.accentColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$riderName:', style: const TextStyle(color: AppConstants.accentColor, fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'REPLY',
            textColor: AppConstants.primaryLight,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              _openDriverChatSheet();
            },
          ),
        ),
      );
    }
  }

  void _openDriverChatSheet() {
    setState(() {
      _unreadChatMessages = 0;
      _isChatSheetOpen = true;
    });
    final riderName = (widget.trip['passengerName'] ?? widget.trip['riderName'] ?? widget.trip['rider_name'] ?? 'Passenger').toString();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DriverChatSheet(
        rideId: (widget.trip['rideId'] ?? widget.trip['id'] ?? '').toString(),
        passengerId: (widget.trip['riderId'] ?? widget.trip['passengerId'] ?? widget.trip['rider_id'] ?? '').toString(),
        passengerName: riderName,
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _isChatSheetOpen = false;
        });
      }
    });
  }

  void _showCallRiderSheet() {
    final riderName = (widget.trip['passengerName'] ?? widget.trip['riderName'] ?? widget.trip['rider_name'] ?? 'Passenger').toString();
    final rId = (widget.trip['passengerId'] ??
            widget.trip['userId'] ??
            widget.trip['riderId'] ??
            widget.trip['passenger']?['id'] ??
            '')
        .toString();
    final rRideId = (widget.trip['id'] ?? widget.trip['rideId'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.phone_in_talk_rounded, color: AppConstants.accentColor, size: 24),
                      const SizedBox(width: 10),
                      Text('Call $riderName', style: const TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close, color: AppConstants.textMuted), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 8),
              // Privacy notice
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppConstants.primaryLight.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_rounded, color: AppConstants.primaryLight, size: 14),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'NDPR Shield Active — Passenger number is 100% private',
                        style: TextStyle(color: AppConstants.textMuted, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // In-App Secure Call
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.headset_mic_rounded, color: Colors.white),
                  label: const Text('In-App Secure Call', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InAppCallScreen(
                          rideId: rRideId,
                          riderId: rId,
                          riderName: riderName,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              // Chat fallback
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppConstants.textMuted, size: 18),
                  label: const Text('Send In-App Message Instead', style: TextStyle(color: AppConstants.textMuted, fontSize: 13)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openDriverChatSheet();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showIncomingCallSheet(Map<String, dynamic> callData) {
    final callerName = callData['callerName']?.toString() ?? 'Passenger';
    final callerId = callData['callerId']?.toString() ?? '';
    final rideId = callData['rideId']?.toString() ?? (widget.trip['id'] ?? widget.trip['rideId'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFF071210),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.ring_volume_rounded, color: AppConstants.accentColor, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Incoming Call from $callerName',
                  style: const TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  '256-Bit Encrypted In-App Audio • Zero Phone Leak',
                  style: TextStyle(color: AppConstants.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.dangerColor,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.call_end_rounded, color: Colors.white),
                      label: const Text('Decline', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        context.read<DriverProvider>().socket.endCall(
                          rideId: rideId,
                          targetId: callerId,
                          reason: 'Declined',
                        );
                        Navigator.pop(ctx);
                      },
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.successColor,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.call_rounded, color: Colors.white),
                      label: const Text('Answer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InAppCallScreen(
                              rideId: rideId,
                              riderId: callerId,
                              riderName: callerName,
                              isIncoming: true,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
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
    final rideId = (widget.trip['rideId'] ?? widget.trip['id'] ?? widget.trip['ride_id'] ?? '').toString();
    if (_currentStep == 'ACCEPTED') {
      provider.updateTripStatus('ARRIVED', overrideRideId: rideId);
      setState(() => _currentStep = 'ARRIVED');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status updated: You arrived at pickup point.'), backgroundColor: AppConstants.primaryColor),
      );
    } else if (_currentStep == 'ARRIVED') {
      provider.updateTripStatus('IN_TRANSIT', overrideRideId: rideId);
      setState(() => _currentStep = 'IN_TRANSIT');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip started! Safe driving.'), backgroundColor: AppConstants.primaryColor),
      );
    } else if (_currentStep == 'IN_TRANSIT') {
      final waitEarnings = provider.accruedDriverWaitEarnings;
      final waitElapsedSecs = provider.waitElapsedSeconds;
      final billableMins = (waitElapsedSecs / 60).ceil() - provider.waitGraceMins > 0 ? (waitElapsedSecs / 60).ceil() - provider.waitGraceMins : 0;
      provider.updateTripStatus('COMPLETED', overrideRideId: rideId);
      _showCompletionDialog(accruedWaitEarnings: waitEarnings, billableWaitMinutes: billableMins);
    }
  }

  void _showCompletionDialog({int accruedWaitEarnings = 0, int billableWaitMinutes = 0}) {
    final baseFare = _extractFare(widget.trip);
    final fare = baseFare + accruedWaitEarnings;
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
                            const Text('Base Ride Fare', style: TextStyle(color: AppConstants.textMuted, fontSize: 13)),
                            Text('₦${_formatFare(baseFare)}', style: const TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        if (accruedWaitEarnings > 0) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Stopover Wait ($billableWaitMinutes mins net)', style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 13, fontWeight: FontWeight.bold)),
                              Text('+₦${_formatFare(accruedWaitEarnings)}', style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        ],
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

                  // ── Cash Change Rollover to Wallet ──
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
          'This streams your vehicle license plate, live GPS coordinates, and trip ID to Nigeria Emergency Response (112) and State Police Command.',
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
                const SnackBar(content: Text('🚨 SOS Alert broadcast to Nigeria Emergency Response (112)!'), backgroundColor: AppConstants.dangerColor),
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
    final provider = context.watch<DriverProvider>();
    final fare = _extractFare(widget.trip);
    final pickup = widget.trip['pickupAddress'] ?? 'Pickup Location';
    final dropoff = widget.trip['dropoffAddress'] ?? 'Destination Location';
    final rawNotes = (widget.trip['notes'] ?? widget.trip['tripInstructions'] ?? widget.trip['trip_instructions'] ?? widget.trip['instructions'] ?? '').toString();

    // Comprehensive Gate Pass Extraction (explicit field or embedded tag)
    final rawGateCode = widget.trip['gateCode'] ?? widget.trip['estateGateCode'] ?? widget.trip['gate_code'] ?? widget.trip['passCode'] ?? widget.trip['estate_gate_code'];
    String? gateCode = rawGateCode?.toString();
    if ((gateCode == null || gateCode.isEmpty) && rawNotes.isNotEmpty) {
      final m = RegExp(r'\[Estate Gate Pass:\s*([^\]]+)\]', caseSensitive: false).firstMatch(rawNotes);
      if (m != null) gateCode = m.group(1)?.trim();
    }

    // Comprehensive Intermediate Stop Extraction (explicit field or embedded tag)
    final rawStop = widget.trip['stop'] ?? widget.trip['stops'] ?? widget.trip['intermediateStop'] ?? widget.trip['intermediate_stop'] ?? widget.trip['waypoint'];
    String? intermediateStop = rawStop?.toString();
    if ((intermediateStop == null || intermediateStop.isEmpty) && rawNotes.isNotEmpty) {
      final m = RegExp(r'\[Intermediate Stop:\s*([^\]]+)\]', caseSensitive: false).firstMatch(rawNotes);
      if (m != null) intermediateStop = m.group(1)?.trim();
    }

    final riderType = widget.trip['riderType'] ?? widget.trip['rider_type'] ?? 'SELF';
    final isFriend = riderType == 'FRIEND';
    final riderName = (widget.trip['riderName'] ?? widget.trip['rider_name'] ?? widget.trip['passengerName'] ?? widget.trip['passenger_name'] ?? 'Passenger').toString();
    final bookerName = widget.trip['bookerName'] ?? widget.trip['booker_name'];
    final notes = rawNotes;

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
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppConstants.accentColor, size: 24),
                onPressed: _openDriverChatSheet,
              ),
              if (_unreadChatMessages > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppConstants.dangerColor,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$_unreadChatMessages',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
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
                        if (intermediateStop != null && intermediateStop.isNotEmpty) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.add_location_alt_rounded, color: Colors.orangeAccent, size: 16),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Intermediate Stop', style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text(intermediateStop, style: const TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.bold)),
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
                        ],
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
                                        ? 'Booked by $bookerName'
                                        : 'Giga Verified Passenger',
                                    style: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (notes.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          // Comfort Requirement Badges
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (widget.trip['hasWaitTime'] == true || widget.trip['has_wait_time'] == true || (((widget.trip['requestedWaitMinutes'] ?? widget.trip['requested_wait_minutes'] ?? 0) as num) > 0))
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.timer_outlined, color: Color(0xFFFBBF24), size: 13),
                                      const SizedBox(width: 4),
                                      Text(
                                        '⏱️ Includes ${widget.trip['requestedWaitMinutes'] ?? widget.trip['requested_wait_minutes'] ?? 30}m Stopover Wait',
                                        style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
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
                        _buildAction(
                          Icons.phone_in_talk_rounded,
                          isFriend ? 'Call Friend' : 'Call Rider',
                          _showCallRiderSheet,
                        ),
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
                        _buildAction(
                          Icons.chat_bubble_outline_rounded,
                          'In-App Chat',
                          _openDriverChatSheet,
                          badgeCount: _unreadChatMessages,
                        ),
                      ],
                    ),
                  ),

                  // ⏱️ Stopover Wait Time Controls (When IN_TRANSIT)
                  if (_currentStep == 'IN_TRANSIT') ...[
                    if (provider.isWaitingAtStop) ...[
                      // Wait Timer Active Card
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFF59E0B).withOpacity(0.2),
                              const Color(0xFFD97706).withOpacity(0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withOpacity(0.25),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.timer_outlined, color: Color(0xFFF59E0B), size: 22),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Stopover Wait Timer Running',
                                        style: TextStyle(color: Color(0xFFFBBF24), fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Passenger notified. Wait earnings are tracking in real-time.',
                                        style: TextStyle(color: AppConstants.textLight, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('WAIT DURATION', style: TextStyle(color: AppConstants.textMuted, fontSize: 10, letterSpacing: 0.8, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatDuration(provider.waitElapsedSeconds),
                                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('YOUR 85% EARNINGS', style: TextStyle(color: AppConstants.textMuted, fontSize: 10, letterSpacing: 0.8, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      if (provider.waitElapsedSeconds <= (provider.waitGraceMins * 60)) ...[
                                        Text(
                                          'Grace (${_formatDuration((provider.waitGraceMins * 60) - provider.waitElapsedSeconds)})',
                                          style: const TextStyle(color: AppConstants.successColor, fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                      ] else ...[
                                        Text(
                                          '+₦${_formatFare(provider.accruedDriverWaitEarnings)}',
                                          style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 20, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppConstants.successColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                                label: const Text(
                                  'Passenger Re-boarded • Resume Driving',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                onPressed: () {
                                  HapticFeedback.heavyImpact();
                                  final rideId = (widget.trip['rideId'] ?? widget.trip['id'] ?? widget.trip['ride_id'] ?? '').toString();
                                  provider.resumeTripFromWait(rideId);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Wait timer stopped. Trip resumed!'), backgroundColor: AppConstants.primaryColor),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Start Wait Timer Button
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                            backgroundColor: const Color(0xFFF59E0B).withOpacity(0.08),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.pause_circle_outline_rounded, color: Color(0xFFFBBF24), size: 20),
                          label: const Text(
                            'Arrived at Stopover? Start Wait Timer',
                            style: TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            final rideId = (widget.trip['rideId'] ?? widget.trip['id'] ?? widget.trip['ride_id'] ?? '').toString();
                            provider.startWaitTime(rideId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Wait timer started! Passenger notified.'), backgroundColor: Color(0xFFD97706)),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
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

  Widget _buildAction(IconData icon, String label, VoidCallback onTap, {int? badgeCount}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppConstants.surfaceBg, shape: BoxShape.circle),
                  child: Icon(icon, color: AppConstants.primaryLight, size: 20),
                ),
                if (badgeCount != null && badgeCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppConstants.dangerColor,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: AppConstants.textLight, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

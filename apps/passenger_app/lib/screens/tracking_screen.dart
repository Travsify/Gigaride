import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../providers/passenger_provider.dart';
import 'home_screen.dart';
import 'in_app_call_screen.dart';
import 'ride_chat_sheet.dart';

class RideTrackingScreen extends StatefulWidget {
  const RideTrackingScreen({super.key});

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  bool _walletPaymentSuccess = false;
  bool _isSettlingWallet = false;
  bool _sosDispatched = false;
  int _driverRating = 5;
  int? _selectedTip;

  void _callDriverSheet(BuildContext context, Map<String, dynamic>? driver, String rideId) {
    final phone = driver?['driverPhone'] ?? driver?['phone'] ?? '+234 800 000 0000';
    final name = driver?['driverName'] ?? 'Driver';
    final driverId = driver?['driverId'] ?? 'driver';
    final vehicle = '${driver?['vehicleModel'] ?? 'Toyota Corolla'} • ${driver?['licensePlate'] ?? ''}';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone_in_talk_rounded, color: AppConstants.accentColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(vehicle, style: const TextStyle(color: AppConstants.textMuted, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // NDPR Privacy Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'NDPR Shield: Your personal phone number is never shared with the driver.',
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Option 1: In-App VoIP Call (Zero phone number leakage)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.headset_mic_rounded, color: Colors.white),
                  label: const Text(
                    'Free In-App Audio Call (VoIP)',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InAppCallScreen(
                          rideId: rideId,
                          driverId: driverId,
                          driverName: name,
                          vehicleInfo: vehicle,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              // Option 2: Direct Cellular GSM Dial
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppConstants.surfaceBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone_android_rounded, color: AppConstants.textMuted, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Driver Verified Line', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                          Text(
                            phone,
                            style: const TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: AppConstants.accentColor, size: 20),
                      tooltip: 'Copy Number',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: phone));
                        HapticFeedback.lightImpact();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied $phone to clipboard.'),
                            backgroundColor: AppConstants.primaryColor,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openChatSheet(BuildContext context, Map<String, dynamic>? driver, String rideId) {
    final name = driver?['driverName'] ?? 'Driver';
    final driverId = driver?['driverId'] ?? 'driver';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RideChatSheet(
        rideId: rideId,
        driverId: driverId,
        driverName: name,
      ),
    );
  }

  void _shareLiveTrackingLink(BuildContext context, String rideId, Map<String, dynamic>? driver) {
    final driverName = driver?['driverName'] ?? 'Driver';
    final vehicle = '${driver?['vehicleModel'] ?? 'Vehicle'} (${driver?['licensePlate'] ?? ''})';
    final link = 'https://gigaride.ng/track/$rideId';
    final shareMsg = "I'm riding with Giga Ride! Track my trip live: $link\nDriver: $driverName ($vehicle)\n256-bit encrypted & NDPR protected.";

    Clipboard.setData(ClipboardData(text: shareMsg));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Live Tracking link copied to clipboard! Share with family on WhatsApp/SMS.'),
        backgroundColor: AppConstants.primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _triggerEmergencySosDialog(BuildContext context, PassengerProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppConstants.dangerColor, size: 28),
            SizedBox(width: 10),
            Text('Activate SOS Dispatch?', style: TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'This will immediately transmit your real-time GPS coordinates, vehicle license plate, and driver identity to Giga Security Operations and Lagos Emergency Response.\n\nOnly use this in real emergency situations.',
          style: TextStyle(color: AppConstants.textMuted, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppConstants.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.dangerColor),
            onPressed: () {
              Navigator.pop(ctx);
              provider.triggerEmergencySos();
              setState(() {
                _sosDispatched = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🚨 DISPATCH NOTIFIED: Giga Security Ops and local emergency units alerted!'),
                  backgroundColor: AppConstants.dangerColor,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 6),
                ),
              );
            },
            child: const Text('ACTIVATE SOS NOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleWalletPayment(PassengerProvider provider) async {
    setState(() => _isSettlingWallet = true);
    try {
      await provider.payWithLivingWallet();
      setState(() {
        _walletPaymentSuccess = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Fare successfully settled from your Living Wallet! Driver received 100%.'),
            backgroundColor: AppConstants.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppConstants.dangerColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSettlingWallet = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PassengerProvider>();
    final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
    final driver = provider.selectedDriverBid;
    final status = provider.tripStatus ?? 'ACCEPTED';
    final rideId = provider.currentRide?['id'] ?? driver?['rideId'] ?? 'active-ride';

    if (status == 'COMPLETED') {
      return Scaffold(
        backgroundColor: AppConstants.darkBg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 80, color: AppConstants.successColor),
                const SizedBox(height: 16),
                const Text('You Have Arrived!', style: TextStyle(color: AppConstants.textLight, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Hope you enjoyed your ride.', style: TextStyle(color: AppConstants.textMuted, fontSize: 14)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppConstants.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _walletPaymentSuccess ? AppConstants.successColor : Colors.white12),
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
                      if (_walletPaymentSuccess) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.check_circle, color: AppConstants.successColor, size: 16),
                            SizedBox(width: 8),
                            Text('Paid via Giga Living Wallet', style: TextStyle(color: AppConstants.successColor, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text('Driver received 100% directly into their payout wallet.', textAlign: TextAlign.center, style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                      ] else ...[
                        const Text(
                          'Settle with driver directly via cash/transfer or pay instantly with your Living Wallet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppConstants.textMuted, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),

                // Rating & Zero-Commission Driver Tip Card
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppConstants.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      const Text('Rate your Trip Experience', style: TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final star = index + 1;
                          return IconButton(
                            icon: Icon(
                              star <= _driverRating ? Icons.star_rounded : Icons.star_border_rounded,
                              color: star <= _driverRating ? Colors.amberAccent : AppConstants.textMuted,
                              size: 28,
                            ),
                            onPressed: () => setState(() => _driverRating = star),
                          );
                        }),
                      ),
                      const Divider(color: Colors.white10, height: 16),
                      const Text('Add 100% Zero-Commission Driver Tip', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [200, 500, 1000].map((tipAmt) {
                          final isSelected = _selectedTip == tipAmt;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ActionChip(
                              backgroundColor: isSelected ? AppConstants.primaryColor : AppConstants.surfaceBg,
                              label: Text('+₦$tipAmt', style: TextStyle(color: isSelected ? Colors.white : AppConstants.textLight, fontSize: 11, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                setState(() => _selectedTip = isSelected ? null : tipAmt);
                                if (!isSelected) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Added ₦$tipAmt tip! 100% will go directly to your driver.'),
                                      backgroundColor: AppConstants.successColor,
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Pay With Living Wallet Button (if not already settled)
                if (!_walletPaymentSuccess) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.accentColor,
                        foregroundColor: Colors.black,
                      ),
                      icon: _isSettlingWallet
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.account_balance_wallet_rounded, size: 20),
                      label: Text(
                        _isSettlingWallet ? 'Processing Wallet Transfer...' : 'Pay with Living Wallet',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      onPressed: _isSettlingWallet ? null : () => _handleWalletPayment(provider),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _walletPaymentSuccess ? AppConstants.primaryColor : AppConstants.surfaceBg,
                    ),
                    onPressed: () {
                      provider.resetTrip();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (r) => false,
                      );
                    },
                    child: Text(
                      _walletPaymentSuccess ? 'Book Another Ride' : 'Paid Driver Cash / Transfer Done',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
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
              // SOS Alert Banner if activated
              if (_sosDispatched) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppConstants.dangerColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppConstants.dangerColor),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.shield_rounded, color: AppConstants.dangerColor, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'EMERGENCY SOS ACTIVE: Security dispatch monitoring this vehicle in real-time.',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

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
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppConstants.primaryLight.withOpacity(0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.share_location_rounded, color: AppConstants.primaryLight, size: 16),
                        label: const Text(
                          'Share Live Trip Link (Family WhatsApp)',
                          style: TextStyle(color: AppConstants.primaryLight, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        onPressed: () => _shareLiveTrackingLink(context, rideId, driver),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Safety SOS, Chat & VoIP Call Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppConstants.accentColor, size: 18),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppConstants.accentColor.withOpacity(0.6)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _openChatSheet(context, driver, rideId),
                      label: const Text('Chat', style: TextStyle(color: AppConstants.accentColor, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.phone_in_talk_rounded, color: AppConstants.textLight, size: 18),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _callDriverSheet(context, driver, rideId),
                      label: const Text('Call', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.dangerColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _triggerEmergencySosDialog(context, provider),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.shield_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text('SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
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

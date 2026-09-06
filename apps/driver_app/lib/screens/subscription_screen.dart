import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../core/constants.dart';
import '../providers/driver_provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _autoTopup = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverProvider>().refreshSubscription();
    });
  }

  final ApiService _api = ApiService();

  void _purchase(String planId, String planName, int priceNgn) async {
    final provider = context.read<DriverProvider>();
    List<dynamic> savedCards = [];
    try {
      savedCards = await _api.getSavedCards();
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Purchase $planName', style: const TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close, color: AppConstants.textMuted), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ₦${NumberFormat('#,##0', 'en_US').format(priceNgn)} • 100% Commission Kept',
              style: const TextStyle(color: AppConstants.accentColor, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Choose Payment Method:', style: TextStyle(color: AppConstants.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // Option 1: Saved Cards (1-Click Instant)
            if (savedCards.isNotEmpty) ...[
              ...savedCards.map((c) {
                final brand = (c['card_brand'] ?? 'card').toString().toUpperCase();
                final last4 = c['card_last4'] ?? '••••';
                final bank = c['card_bank'] ?? 'Bank';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppConstants.darkBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.credit_card_rounded, color: Colors.cyanAccent, size: 20),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$brand •••• $last4', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(bank, style: const TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0)),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final res = await _api.chargeSavedCard(cardId: c['id'], amountNgn: priceNgn, planId: planId);
                            await provider.refreshSubscription();
                            messenger.showSnackBar(
                              SnackBar(content: Text('✓ ${res['message'] ?? "$planName activated!"}'), backgroundColor: AppConstants.successColor),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppConstants.dangerColor),
                            );
                          }
                        },
                        child: const Text('1-Click Pay', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 6),
            ],

            // Option 2: Pay with Wallet Balance
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppConstants.darkBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, color: Colors.greenAccent, size: 20),
                      SizedBox(width: 10),
                      Text('Living Wallet Balance', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppConstants.successColor, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0)),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await provider.purchasePlan(planId);
                        messenger.showSnackBar(
                          SnackBar(content: Text('✓ $planName activated successfully!'), backgroundColor: AppConstants.successColor),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppConstants.dangerColor),
                        );
                      }
                    },
                    child: const Text('Pay Wallet', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            // Option 3: Pay with New Card (Paystack Checkout)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_card_rounded, color: Colors.white, size: 16),
                label: const Text('Pay with New Card (Paystack Checkout)', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    final res = await _api.initializeCardPayment(planId);
                    final authUrl = res['authorizationUrl'] as String?;
                    final ref = res['reference'] as String?;
                    if (authUrl != null && await canLaunchUrl(Uri.parse(authUrl))) {
                      await launchUrl(Uri.parse(authUrl), mode: LaunchMode.externalApplication);
                    }
                    if (ref != null) {
                      await _api.verifyCardTransaction(ref);
                    }
                    await provider.refreshSubscription();
                    messenger.showSnackBar(
                      SnackBar(content: Text('✓ $planName card transaction processed!'), backgroundColor: AppConstants.successColor),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Payment error: $e'), backgroundColor: AppConstants.dangerColor),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriverProvider>();
    final plans = provider.subscriptionPlans;
    final remaining = provider.remainingRides;
    final hasActive = provider.hasActiveSubscription;
    final currentPlan = provider.planName ?? 'Standard Starter';

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Subscription Store', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Current Status Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF115E59)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: AppConstants.primaryColor.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(currentPlan, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          hasActive ? 'ACTIVE' : 'EXHAUSTED',
                          style: TextStyle(color: hasActive ? Colors.greenAccent : Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Remaining Dispatch Rides', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    '$remaining Rides',
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: Colors.white70, size: 14),
                      SizedBox(width: 6),
                      Text('2-Grace Rides Lockout Protection Active', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Auto-Topup Policy Switch
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppConstants.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppConstants.accentColor.withOpacity(0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.autorenew_rounded, color: AppConstants.accentColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Auto-Topup When ≤ 2 Rides', style: TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('Automatically re-up pack using wallet balance to prevent radar downtime.', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _autoTopup,
                    activeColor: AppConstants.accentColor,
                    onChanged: (val) {
                      setState(() => _autoTopup = val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(val ? 'Auto-Topup Enabled' : 'Auto-Topup Disabled')),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text('Available Subscription Packs', style: TextStyle(color: AppConstants.textLight, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Subscription Packs
            if (plans.isEmpty) ...[
              _buildPlanCard('plan_starter_10', '10-Ride Daily Starter', 'Great for part-time runs and testing. Zero commission.', 10, 1500),
              const SizedBox(height: 12),
              _buildPlanCard('plan_standard_50', '50-Ride Commuter Pack', 'Most popular for full-time Lagos drivers. ₦120/ride.', 50, 6000, isPopular: true),
              const SizedBox(height: 12),
              _buildPlanCard('plan_pro_100', '100-Ride Pro Fleet', 'Lowest cost per trip at just ₦100 per completed ride.', 100, 10000),
              const SizedBox(height: 12),
              _buildPlanCard('plan_unlimited_30d', 'Unlimited Monthly Pass', 'Unlimited rides across Nigeria for 30 consecutive days.', 999, 25000),
            ] else
              ...plans.map((p) {
                final price = (p['price_kobo'] ?? 150000) ~/ 100;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildPlanCard(
                    p['id'],
                    p['name'] ?? 'Pack',
                    p['description'] ?? 'Zero commission mobility pack',
                    p['total_rides'] ?? 10,
                    price,
                    isPopular: p['id'] == 'plan_standard_50',
                  ),
                );
              }),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(String id, String name, String desc, int rides, int priceNgn, {bool isPopular = false}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppConstants.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPopular ? AppConstants.primaryLight : Colors.white10,
          width: isPopular ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(rides >= 999 ? 'Unlimited Rides' : '$rides Trips Included', style: const TextStyle(color: AppConstants.primaryLight, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              Text(
                '₦${NumberFormat('#,##0', 'en_US').format(priceNgn)}',
                style: const TextStyle(color: AppConstants.accentColor, fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(desc, style: const TextStyle(color: AppConstants.textMuted, fontSize: 12, height: 1.3)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isPopular ? AppConstants.primaryColor : AppConstants.surfaceBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _purchase(id, name, priceNgn),
              child: const Text('Buy With Wallet / Card', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

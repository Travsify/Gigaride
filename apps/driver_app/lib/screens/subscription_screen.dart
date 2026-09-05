import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../providers/driver_provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  List<dynamic> plans = [];
  bool isLoadingPlans = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  void _loadPlans() async {
    final provider = context.read<DriverProvider>();
    try {
      final fetched = await provider.api.getSubscriptionPlans();
      if (mounted) {
        setState(() {
          plans = fetched;
          isLoadingPlans = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoadingPlans = false);
    }
  }

  void _buyPlan(String planId, String planName) async {
    final provider = context.read<DriverProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.cardBg,
        title: Text('Subscribe to $planName', style: const TextStyle(color: AppConstants.textLight)),
        content: const Text(
          'Select your preferred Nigerian payment method to activate rides instantly:',
          style: TextStyle(color: AppConstants.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppConstants.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await provider.purchasePlan(planId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Subscribed successfully to $planName!'),
                      backgroundColor: AppConstants.successColor,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: AppConstants.dangerColor,
                    ),
                  );
                }
              }
            },
            child: const Text('Pay with Card / Bank Transfer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriverProvider>();
    final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Driver Subscriptions', style: TextStyle(color: AppConstants.textLight)),
        iconTheme: const IconThemeData(color: AppConstants.textLight),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await provider.refreshSubscription();
            _loadPlans();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current Status Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: provider.hasActiveSubscription
                          ? [AppConstants.primaryColor, const Color(0xFF065F46)]
                          : [const Color(0xFF991B1B), const Color(0xFF7F1D1D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (provider.hasActiveSubscription ? AppConstants.primaryColor : Colors.red)
                            .withOpacity(0.3),
                        blurRadius: 10,
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
                          Text(
                            provider.planName ?? (provider.hasActiveSubscription ? 'Active Subscription' : 'No Active Plan'),
                            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              provider.hasActiveSubscription ? 'ACTIVE' : 'EXHAUSTED',
                              style: TextStyle(
                                color: provider.hasActiveSubscription ? Colors.greenAccent : Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            provider.remainingRides > 9999 ? '∞' : '${provider.remainingRides}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Text(
                              'rides remaining',
                              style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      if (provider.isGracePeriod)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(6)),
                            child: const Text(
                              '⚠️ Emergency Grace Ride Active. Recharge before next shift.',
                              style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      if (!provider.hasActiveSubscription)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            '⚠️ You are currently invisible to passengers. Buy rides below to re-enter dispatch radar.',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Choose a Ride Pack (0% Commission)',
                  style: TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Every kobo you bargain with passengers belongs to you.',
                  style: TextStyle(color: AppConstants.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (isLoadingPlans)
                  const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
                else
                  ...plans.map((p) {
                    final price = (p['price_kobo'] ?? 0) / 100;
                    final totalRides = p['total_rides'];
                    final isUnlimited = p['plan_type'] == 'UNLIMITED';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppConstants.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isUnlimited ? AppConstants.accentColor : Colors.white10,
                          width: isUnlimited ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                p['name'],
                                style: const TextStyle(color: AppConstants.textLight, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                currencyFormat.format(price),
                                style: const TextStyle(color: AppConstants.accentColor, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            p['description'] ?? '',
                            style: const TextStyle(color: AppConstants.textMuted, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(isUnlimited ? Icons.all_inclusive : Icons.check_circle_outline,
                                  size: 16, color: AppConstants.successColor),
                              const SizedBox(width: 6),
                              Text(
                                isUnlimited ? 'Unlimited trips for ${p['duration_days']} days' : '$totalRides rides included',
                                style: const TextStyle(color: AppConstants.textLight, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              ElevatedButton(
                                onPressed: () => _buyPlan(p['id'], p['name']),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isUnlimited ? AppConstants.accentColor : AppConstants.primaryColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                child: Text(
                                  'Subscribe',
                                  style: TextStyle(
                                    color: isUnlimited ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

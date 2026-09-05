import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../providers/passenger_provider.dart';
import 'offer_room_screen.dart';
import 'wallet_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final currencyFormat = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

  final _pickupCtrl = TextEditingController(text: 'Commercial Avenue, Yaba, Lagos');
  final _dropoffCtrl = TextEditingController(text: 'Adetokunbo Ademola, Victoria Island, Lagos');
  final _offerCtrl = TextEditingController(text: '4500');

  // Realistic sample coordinates in Lagos (Yaba to Victoria Island)
  final double _pickupLat = 6.518;
  final double _pickupLng = 3.379;
  final double _dropoffLat = 6.428;
  final double _dropoffLng = 3.421;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getEstimate();
    });
  }

  void _getEstimate() {
    context.read<PassengerProvider>().calculateEstimate(
      pickupLat: _pickupLat,
      pickupLng: _pickupLng,
      dropoffLat: _dropoffLat,
      dropoffLng: _dropoffLng,
    );
  }

  void _findDrivers() async {
    final offer = int.tryParse(_offerCtrl.text.replaceAll(',', '').trim()) ?? 0;
    final provider = context.read<PassengerProvider>();
    final estimate = provider.currentEstimate;

    if (estimate != null && offer < estimate['minimumBidFloorNgn']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Minimum bid floor is ${currencyFormat.format(estimate['minimumBidFloorNgn'])}. Drivers will ignore lower offers.'),
          backgroundColor: AppConstants.dangerColor,
        ),
      );
      return;
    }

    try {
      await provider.submitRideRequest(
        pickupLat: _pickupLat,
        pickupLng: _pickupLng,
        pickupAddress: _pickupCtrl.text.trim(),
        dropoffLat: _dropoffLat,
        dropoffLng: _dropoffLng,
        dropoffAddress: _dropoffCtrl.text.trim(),
        riderOfferNgn: offer,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OfferRoomScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppConstants.dangerColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PassengerProvider>();
    final estimate = provider.currentEstimate;

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      appBar: AppBar(
        backgroundColor: AppConstants.cardBg,
        elevation: 0,
        title: const Text('Book a Ride', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet, color: AppConstants.accentColor),
            tooltip: 'Living Wallet',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalletScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppConstants.textMuted),
            onPressed: () => provider.logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Address Selection Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppConstants.cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.circle, color: Colors.greenAccent, size: 14),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _pickupCtrl,
                            style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'Pickup Location',
                              hintStyle: TextStyle(color: AppConstants.textMuted),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white10, height: 16),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _dropoffCtrl,
                            style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'Where to?',
                              hintStyle: TextStyle(color: AppConstants.textMuted),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Fare Recommendation Card
              if (estimate != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppConstants.primaryColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Suggested Fare', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                              Text(
                                currencyFormat.format(estimate['suggestedFareNgn']),
                                style: const TextStyle(color: AppConstants.textLight, fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${estimate['distanceKm']} km • ~${estimate['estimatedMinutes']} mins',
                                  style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.bold)),
                              Text(
                                'Fuel Est: ${currencyFormat.format(estimate['fuelCostEstimateNgn'])}',
                                style: const TextStyle(color: AppConstants.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Minimum fair offer to attract drivers: ${currencyFormat.format(estimate['minimumBidFloorNgn'])}',
                        style: const TextStyle(color: AppConstants.accentColor, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),
              const Text('Your Proposed Fare (NGN)', style: TextStyle(color: AppConstants.textLight, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Drivers will see this and can accept or submit counter-offers.', style: TextStyle(color: AppConstants.textMuted, fontSize: 13)),
              const SizedBox(height: 12),

              TextField(
                controller: _offerCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppConstants.textLight, fontSize: 22, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  prefixText: '₦ ',
                  prefixStyle: const TextStyle(color: AppConstants.accentColor, fontSize: 22, fontWeight: FontWeight.bold),
                  filled: true,
                  fillColor: AppConstants.cardBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),

              // Quick Offer Adjustment Chips
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildQuickOfferChip('₦3,500', 3500),
                  _buildQuickOfferChip('₦4,000', 4000),
                  _buildQuickOfferChip('₦4,500', 4500),
                  _buildQuickOfferChip('₦5,000', 5000),
                ],
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.search, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: provider.isLoading ? null : _findDrivers,
                  label: provider.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Find Drivers & Enter Offer Room', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickOfferChip(String label, int amount) {
    return ActionChip(
      backgroundColor: AppConstants.cardBg,
      label: Text(label, style: const TextStyle(color: AppConstants.textLight, fontSize: 12)),
      onPressed: () => setState(() => _offerCtrl.text = amount.toString()),
    );
  }
}

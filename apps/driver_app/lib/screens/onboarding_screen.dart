import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import 'phone_auth_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _currentIndex = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'icon': Icons.savings_rounded,
      'color': AppConstants.successColor,
      'title': 'Keep 100% of Every Fare',
      'highlight': '0% PLATFORM COMMISSION',
      'desc':
          'Stop surrendering 20% to 25% of your sweat to international apps. With Giga, you pay a small flat subscription and pocket every single naira your passengers pay.',
    },
    {
      'icon': Icons.gavel_rounded,
      'color': AppConstants.accentColor,
      'title': 'Live Auction Bidding',
      'highlight': 'YOU SET YOUR OWN FARE',
      'desc':
          'No rigid algorithms. If fuel is scarce or Third Mainland Bridge is gridlocked, raise your counter-offer to what the trip is truly worth. Passenger accepts, you drive.',
    },
    {
      'icon': Icons.local_gas_station_rounded,
      'color': Colors.cyanAccent,
      'title': 'Petrol Floor Price Shield',
      'highlight': 'NEVER RUN AT A LOSS',
      'desc':
          'Our dispatch engine monitors Lagos & Abuja petrol pump benchmarks (₦1,050+/L) and enforces a minimum suggested fare so you never accept loss-making trips.',
    },
    {
      'icon': Icons.account_balance_rounded,
      'color': Colors.purpleAccent,
      'title': 'Permanent NUBAN Account',
      'highlight': 'INSTANT BANK TRANSFER DVA',
      'desc':
          'Get a dedicated Wema Bank or Providus Bank account upon KYC approval. Passengers transfer funds directly to your wallet with zero reconciliation disputes.',
    },
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('driver_seen_onboarding', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Brand & Skip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.local_taxi, color: AppConstants.primaryLight, size: 20),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'GIGA PARTNER',
                        style: TextStyle(
                          color: AppConstants.textLight,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  if (_currentIndex < _slides.length - 1)
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: const Text(
                        'Skip',
                        style: TextStyle(color: AppConstants.textMuted, fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),

            // Page View
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (ctx, i) {
                  final slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: (slide['color'] as Color).withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (slide['color'] as Color).withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            slide['icon'] as IconData,
                            size: 56,
                            color: slide['color'] as Color,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: (slide['color'] as Color).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            slide['highlight'],
                            style: TextStyle(
                              color: slide['color'] as Color,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          slide['title'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppConstants.textLight,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          slide['desc'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppConstants.textMuted,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Dots Indicator & CTA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (idx) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentIndex == idx ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentIndex == idx
                              ? AppConstants.primaryLight
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                      onPressed: () {
                        if (_currentIndex < _slides.length - 1) {
                          _pageCtrl.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _completeOnboarding();
                        }
                      },
                      child: Text(
                        _currentIndex == _slides.length - 1
                            ? 'Start Driving With Giga'
                            : 'Continue',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
}

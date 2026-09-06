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
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _items = const [
    OnboardingItem(
      badge: 'FAIR BIDDING',
      title: 'Name Your Own Fare.\nZero Crazy Surges.',
      description:
          'Tired of 3x price hikes during Lagos rain or peak hours? On Giga Ride, you propose what you want to pay and choose directly from nearby verified drivers.',
      icon: Icons.price_check_rounded,
      accentColor: AppConstants.primaryLight,
    ),
    OnboardingItem(
      badge: 'FINANCIAL FREEDOM',
      title: 'Living Wallet &\nSafeLock Vault.',
      description:
          'Fund instantly with your personal dedicated Wema/Giga NUBAN. Lock your monthly transport budget into SafeLock so you never run stranded.',
      icon: Icons.account_balance_wallet_rounded,
      accentColor: AppConstants.accentColor,
    ),
    OnboardingItem(
      badge: 'PRE-SCHEDULED VIP',
      title: 'Guaranteed Airport &\nInterstate Travel.',
      description:
          'Catch your flight at MMA2 or Nnamdi Azikiwe with peace of mind. Pre-book vetted VIP drivers with flight tracking and guaranteed arrival.',
      icon: Icons.flight_takeoff_rounded,
      accentColor: Color(0xFF38BDF8), // Sky Blue
    ),
    OnboardingItem(
      badge: 'NDPR DATA SHIELD',
      title: 'Your Phone Number Is\nNever Shared With Drivers.',
      description:
          'Complete peace of mind under NDPR compliance. All in-app VoIP audio calls and estate gate chat are encrypted with zero personal phone leaks.',
      icon: Icons.verified_user_rounded,
      accentColor: Color(0xFF10B981), // Emerald
    ),
  ];

  void _onFinish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyHasSeenOnboarding, true);
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
            // Top Bar: Brand + Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppConstants.primaryLight.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.local_taxi_rounded,
                          color: AppConstants.primaryLight,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'GIGA RIDE',
                        style: TextStyle(
                          color: AppConstants.textLight,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _onFinish,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: AppConstants.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // PageView Carousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _items.length,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero Icon Badge
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: item.accentColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: item.accentColor.withOpacity(0.35),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: item.accentColor.withOpacity(0.2),
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            item.icon,
                            size: 42,
                            color: item.accentColor,
                          ),
                        ),

                        const SizedBox(height: 36),

                        // Pill Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: item.accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: item.accentColor.withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            item.badge,
                            style: TextStyle(
                              color: item.accentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Headline
                        Text(
                          item.title,
                          style: const TextStyle(
                            color: AppConstants.textLight,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                            letterSpacing: -0.5,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Subtitle
                        Text(
                          item.description,
                          style: const TextStyle(
                            color: AppConstants.textMuted,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Bar: Dots & Action CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
              child: Column(
                children: [
                  // Dot Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_items.length, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppConstants.primaryLight
                              : AppConstants.surfaceBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 28),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage < _items.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _onFinish();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 6,
                        shadowColor: AppConstants.primaryColor.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _currentPage == _items.length - 1
                            ? 'Get Started'
                            : 'Continue',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Sign in link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(color: AppConstants.textMuted, fontSize: 13),
                      ),
                      GestureDetector(
                        onTap: _onFinish,
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            color: AppConstants.primaryLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
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

class OnboardingItem {
  final String badge;
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;

  const OnboardingItem({
    required this.badge,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
  });
}

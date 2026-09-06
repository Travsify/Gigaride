import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../providers/passenger_provider.dart';
import 'onboarding_screen.dart';
import 'phone_auth_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  String _statusText = 'Initializing secure connection...';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _bootstrapApp();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bootstrapApp() async {
    await Future.delayed(const Duration(milliseconds: 600));

    // 1. Check VPS Health in background
    try {
      if (mounted) setState(() => _statusText = 'Verifying VPS platform health...');
      final healthUri = Uri.parse('${AppConstants.defaultApiUrl}/health');
      await http.get(healthUri).timeout(const Duration(seconds: 4));
    } catch (_) {
      // Offline or network lag — continue to allow offline state inspection
    }

    // 2. Check Onboarding Flag
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool(AppConstants.keyHasSeenOnboarding) ?? false;

    if (!mounted) return;

    if (!hasSeenOnboarding) {
      _navigateTo(const OnboardingScreen());
      return;
    }

    // 3. Check Authentication
    if (mounted) setState(() => _statusText = 'Restoring session...');
    final provider = context.read<PassengerProvider>();
    final isAuthenticated = await provider.checkAuth();

    if (!mounted) return;

    if (isAuthenticated) {
      _navigateTo(const HomeScreen());
    } else {
      _navigateTo(const PhoneAuthScreen());
    }
  }

  void _navigateTo(Widget target) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, anim, secAnim) => target,
        transitionsBuilder: (context, animation, secAnim, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 450),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.2,
            colors: [
              Color(0xFF0F2B26), // Subtle emerald center glow
              AppConstants.darkBg,
              Color(0xFF060911),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Animated Logo
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: AppConstants.primaryLight.withOpacity(0.35),
                        blurRadius: 36,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        decoration: BoxDecoration(
                          color: AppConstants.cardBg,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: AppConstants.primaryColor.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.local_taxi_rounded,
                          size: 64,
                          color: AppConstants.primaryLight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Brand Title
              const Text(
                'GIGA RIDE',
                style: TextStyle(
                  color: AppConstants.textLight,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),

              const SizedBox(height: 8),

              // Tagline
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppConstants.primaryLight,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ZERO COMMISSION • YOUR FARE',
                    style: TextStyle(
                      color: AppConstants.primaryLight,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 2),

              // Subtle status indicator
              Text(
                _statusText,
                style: const TextStyle(
                  color: AppConstants.textMuted,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 16),

              // Security & Gateway Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.shield_outlined, color: AppConstants.primaryLight, size: 12),
                  SizedBox(width: 6),
                  Text(
                    '256-Bit TLS • NDPR Compliant • Lagos Gateway',
                    style: TextStyle(
                      color: AppConstants.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

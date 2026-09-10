import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../providers/driver_provider.dart';
import 'onboarding_screen.dart';
import 'phone_auth_screen.dart';
import 'kyc_screen.dart';
import 'driver_shell.dart';
import '../widgets/location_permission_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _bootstrapApp();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapApp() async {
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      final provider = context.read<DriverProvider>();
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw Exception('Prefs timeout'),
      );

      final hasSeenOnboarding = prefs.getBool('driver_seen_onboarding') ?? false;

      // Resilient Auth check: 8 seconds maximum wait with fast-path
      bool authed = false;
      try {
        authed = await provider.checkAuth().timeout(
          const Duration(seconds: 8),
          onTimeout: () => false,
        );
      } catch (_) {
        authed = false;
      }

      if (!mounted) return;

      if (!hasSeenOnboarding) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      } else if (!authed) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
        );
      } else {
        // Authenticated: check KYC status
        final kycStatus = provider.driverProfile?['kyc_status'];
        final target = (kycStatus != 'APPROVED') ? const KycScreen() : const DriverShell();

        // Check if location permission is already active — if so, skip the gate and open DriverShell directly!
        bool hasLocationAccess = false;
        try {
          final serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (serviceEnabled) {
            final permission = await Geolocator.checkPermission();
            if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
              hasLocationAccess = true;
            }
          }
        } catch (_) {}

        if (!mounted) return;

        if (hasLocationAccess) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => target),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => LocationPermissionGate(nextScreen: target)),
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Center(
              child: ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppConstants.primaryLight, AppConstants.primaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppConstants.primaryColor.withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'GIGA DRIVER',
              style: TextStyle(
                color: AppConstants.textLight,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppConstants.accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppConstants.accentColor.withOpacity(0.3)),
              ),
              child: const Text(
                '0% TRIP COMMISSION PARTNER',
                style: TextStyle(
                  color: AppConstants.accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const Spacer(),
            // Security & Compliance Badge
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppConstants.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_user_rounded, color: AppConstants.successColor, size: 14),
                  SizedBox(width: 8),
                  Text(
                    '256-Bit TLS • FRSC & LASRRA Regulated',
                    style: TextStyle(
                      color: AppConstants.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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

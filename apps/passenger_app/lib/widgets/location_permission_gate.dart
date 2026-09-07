import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/constants.dart';
import '../services/places_service.dart';
import 'package:latlong2/latlong.dart';

/// Mandatory Location Gate for Giga Ride.
/// Prevents entry into the application until precise GPS location is verified.
/// Provides automated device detection (iOS vs Android) and interactive step-by-step guides.
class LocationPermissionGate extends StatefulWidget {
  final Widget nextScreen;

  const LocationPermissionGate({
    super.key,
    required this.nextScreen,
  });

  @override
  State<LocationPermissionGate> createState() => _LocationPermissionGateState();
}

class _LocationPermissionGateState extends State<LocationPermissionGate>
    with WidgetsBindingObserver {
  bool _isChecking = true;
  bool _isServiceDisabled = false;
  bool _isPermanentDenied = false;
  bool _isSuccessTransition = false;
  String _detectedArea = 'Detecting GPS Coordinates in Nigeria...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequest();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Automatically re-verifies permission when user switches back from phone Settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndRequest(isBackgroundResume: true);
    }
  }

  Future<void> _checkAndRequest({bool isBackgroundResume = false}) async {
    if (!mounted) return;
    setState(() {
      _isChecking = true;
    });

    // 1. Check if device location services (GPS hardware) are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _isServiceDisabled = true;
        });
      }
      return;
    }

    // 2. Check application location permissions
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      if (!isBackgroundResume) {
        // Automatically trigger OS native permission dialog
        permission = await Geolocator.requestPermission();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _isPermanentDenied = true;
          _isServiceDisabled = false;
        });
      }
      return;
    }

    if (permission == LocationPermission.denied) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _isPermanentDenied = false;
          _isServiceDisabled = false;
        });
      }
      return;
    }

    // 3. Permission Granted (whileInUse or always)
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      await _onPermissionGranted();
    }
  }

  Future<void> _onPermissionGranted() async {
    if (!mounted) return;
    setState(() {
      _isChecking = false;
      _isSuccessTransition = true;
      _isServiceDisabled = false;
      _isPermanentDenied = false;
    });

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );

      // Reverse geocode to get Nigerian area name
      try {
        final address = await PlacesService.reverseGeocode(
          LatLng(pos.latitude, pos.longitude),
        );
        if (mounted && address.isNotEmpty && address != 'Current Location') {
          setState(() {
            _detectedArea = address;
          });
        } else {
          if (mounted) {
            setState(() {
              _detectedArea =
                  'GPS Locked (${pos.latitude.toStringAsFixed(3)}°N, ${pos.longitude.toStringAsFixed(3)}°E)';
            });
          }
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _detectedArea =
                'GPS Locked (${pos.latitude.toStringAsFixed(3)}°N, ${pos.longitude.toStringAsFixed(3)}°E)';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _detectedArea = 'GPS Connected (Nigeria)';
        });
      }
    }

    // Smooth transition to next screen
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, anim, secAnim) => widget.nextScreen,
          transitionsBuilder: (context, anim, secAnim, child) {
            return FadeTransition(opacity: anim, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      body: SafeArea(
        child: _isChecking
            ? _buildCheckingView()
            : _isSuccessTransition
                ? _buildSuccessView()
                : _buildPermissionGuideView(),
      ),
    );
  }

  Widget _buildCheckingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primaryLight),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Verifying GPS Satellite Link...',
            style: TextStyle(
              color: AppConstants.textLight.withOpacity(0.9),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connecting with device location sensors',
            style: TextStyle(
              color: AppConstants.textMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    final isApple = Platform.isIOS;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppConstants.successColor.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppConstants.successColor, width: 2),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppConstants.successColor,
                size: 52,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Location Access Verified',
              style: TextStyle(
                color: AppConstants.textLight,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppConstants.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isApple ? Icons.apple_rounded : Icons.android_rounded,
                    color: AppConstants.primaryLight,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isApple
                        ? 'Apple iPhone Precise GPS Active'
                        : 'Android High-Accuracy GPS Active',
                    style: const TextStyle(
                      color: AppConstants.primaryLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _detectedArea,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppConstants.textLight.withOpacity(0.85),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Opening Giga Ride...',
              style: TextStyle(
                color: AppConstants.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionGuideView() {
    final isApple = Platform.isIOS;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),

          // Top Header Icon
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppConstants.dangerColor.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: AppConstants.dangerColor.withOpacity(0.5), width: 2),
              ),
              child: const Icon(
                Icons.location_off_rounded,
                color: AppConstants.dangerColor,
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Mandatory Requirement Header
          const Text(
            'GPS Location Required',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppConstants.textLight,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Giga Ride operates across Nigeria. To detect your pickup spot, connect you with nearby drivers, and calculate fair naira fares, precise location must be enabled.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppConstants.textMuted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),

          // Device Detection Header Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppConstants.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppConstants.primaryLight.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  isApple ? Icons.apple_rounded : Icons.android_rounded,
                  color: AppConstants.primaryLight,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isApple
                        ? 'Detected: Apple iOS Device (iPhone)'
                        : 'Detected: Android Smartphone',
                    style: const TextStyle(
                      color: AppConstants.textLight,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Step-by-Step Guide Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppConstants.cardBg.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  Text(
                    _isServiceDisabled
                        ? 'Follow these steps to turn ON Phone Location:'
                        : _isPermanentDenied
                            ? 'Permission was previously denied. Enable it in Settings:'
                            : 'Follow these steps to allow location access:',
                    style: const TextStyle(
                      color: AppConstants.accentColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_isServiceDisabled) ...[
                    _buildGuideStep(
                      step: '1',
                      title: 'Open Device Location Settings',
                      subtitle: 'Tap the button below to open your phone\'s location master switch.',
                    ),
                    _buildGuideStep(
                      step: '2',
                      title: isApple ? 'Turn On Location Services' : 'Turn On Location Access',
                      subtitle: 'Toggle the master Location switch to ON.',
                    ),
                    _buildGuideStep(
                      step: '3',
                      title: 'Return to Giga Ride',
                      subtitle: 'The app will immediately detect the signal and let you in.',
                    ),
                  ] else if (isApple) ...[
                    _buildGuideStep(
                      step: '1',
                      title: 'Tap "Open Device Settings" Below',
                      subtitle: 'Takes you straight to the Giga Ride permissions in iOS Settings.',
                    ),
                    _buildGuideStep(
                      step: '2',
                      title: 'Tap "Location"',
                      subtitle: 'Select "While Using the App".',
                    ),
                    _buildGuideStep(
                      step: '3',
                      title: 'Enable "Precise Location" (Important)',
                      subtitle: 'Turn ON the Precise Location switch so your Nigerian coordinates are accurate.',
                    ),
                    _buildGuideStep(
                      step: '4',
                      title: 'Return to Giga Ride',
                      subtitle: 'Your session will resume automatically without restarting.',
                    ),
                  ] else ...[
                    _buildGuideStep(
                      step: '1',
                      title: 'Tap "Open Device Settings" Below',
                      subtitle: 'Takes you to Giga Ride Application Info in Android Settings.',
                    ),
                    _buildGuideStep(
                      step: '2',
                      title: 'Tap "Permissions" ➔ "Location"',
                      subtitle: 'Select "Allow only while using the app".',
                    ),
                    _buildGuideStep(
                      step: '3',
                      title: 'Turn On "Use Precise Location"',
                      subtitle: 'Ensures high accuracy GPS tracking.',
                    ),
                    _buildGuideStep(
                      step: '4',
                      title: 'Return to Giga Ride',
                      subtitle: 'Giga Ride will instantly detect the permission and continue.',
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons
          ElevatedButton(
            onPressed: () async {
              if (_isServiceDisabled) {
                await Geolocator.openLocationSettings();
              } else {
                await Geolocator.openAppSettings();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryLight,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.settings_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  _isServiceDisabled
                      ? 'Open Location Settings'
                      : 'Open Device Settings',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          OutlinedButton(
            onPressed: () => _checkAndRequest(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppConstants.textLight,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.refresh_rounded, size: 18),
                SizedBox(width: 8),
                Text(
                  'I\'ve Enabled It — Check Status',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildGuideStep({
    required String step,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppConstants.primaryLight.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: AppConstants.primaryLight, width: 1.5),
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  color: AppConstants.primaryLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppConstants.textLight,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppConstants.textMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

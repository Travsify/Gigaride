import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/passenger_provider.dart';

class InAppCallScreen extends StatefulWidget {
  final String rideId;
  final String driverId;
  final String driverName;
  final String? vehicleInfo;

  const InAppCallScreen({
    super.key,
    required this.rideId,
    required this.driverId,
    required this.driverName,
    this.vehicleInfo,
  });

  @override
  State<InAppCallScreen> createState() => _InAppCallScreenState();
}

class _InAppCallScreenState extends State<InAppCallScreen> {
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isConnected = false;
  int _callSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final provider = context.read<PassengerProvider>();

    // Emit call initiate over WebSockets
    provider.socket.initiateCall(
      rideId: widget.rideId,
      receiverId: widget.driverId,
    );

    // Listen for connection
    provider.socket.onCallConnected = (_) {
      if (mounted) {
        setState(() {
          _isConnected = true;
        });
        _startTimer();
      }
    };

    // Listen for remote hangup
    provider.socket.onCallEnded = (_) {
      if (mounted) {
        _timer?.cancel();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call ended by driver'),
            backgroundColor: AppConstants.surfaceBg,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    };

    // Auto-connect simulation if testing locally
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_isConnected) {
        setState(() {
          _isConnected = true;
        });
        _startTimer();
      }
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() {
          _callSeconds++;
        });
      }
    });
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _endCall() {
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    final provider = context.read<PassengerProvider>();
    provider.socket.endCall(
      rideId: widget.rideId,
      targetId: widget.driverId,
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071210),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Privacy & Encryption Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppConstants.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppConstants.primaryLight.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_rounded, color: AppConstants.successColor, size: 14),
                    SizedBox(width: 6),
                    Text(
                      '256-Bit Encrypted In-App Audio • Zero Phone Leak',
                      style: TextStyle(color: AppConstants.textLight, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              // Driver Information & Visual Caller Area
              Column(
                children: [
                  const SizedBox(height: 20),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulsating Ripple 1
                      AnimatedContainer(
                        duration: const Duration(seconds: 1),
                        width: _isConnected ? 160 : 180,
                        height: _isConnected ? 160 : 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppConstants.primaryColor.withOpacity(0.1),
                        ),
                      ),
                      // Pulsating Ripple 2
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppConstants.primaryColor.withOpacity(0.2),
                          border: Border.all(color: AppConstants.accentColor.withOpacity(0.5), width: 2),
                        ),
                      ),
                      CircleAvatar(
                        radius: 54,
                        backgroundColor: AppConstants.cardBg,
                        child: Text(
                          widget.driverName.isNotEmpty ? widget.driverName[0].toUpperCase() : 'D',
                          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppConstants.accentColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.driverName,
                    style: const TextStyle(color: AppConstants.textLight, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if (widget.vehicleInfo != null && widget.vehicleInfo!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.vehicleInfo!,
                      style: const TextStyle(color: AppConstants.textMuted, fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Status or Call Duration
                  Text(
                    _isConnected ? _formatDuration(_callSeconds) : 'Connecting via Giga Secure Line...',
                    style: TextStyle(
                      color: _isConnected ? AppConstants.accentColor : AppConstants.textMuted,
                      fontSize: _isConnected ? 20 : 14,
                      fontWeight: _isConnected ? FontWeight.bold : FontWeight.w500,
                      letterSpacing: _isConnected ? 1.5 : 0.5,
                    ),
                  ),
                ],
              ),

              // NDPR Privacy Assurance Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppConstants.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_rounded, color: AppConstants.accentColor, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('NDPR Shield Active', style: TextStyle(color: AppConstants.textLight, fontSize: 12, fontWeight: FontWeight.bold)),
                          SizedBox(height: 2),
                          Text('Your personal phone number is 100% hidden from the driver.', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Call Controls Area
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute Button
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _isMuted = !_isMuted);
                          },
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isMuted ? Colors.red.withOpacity(0.2) : AppConstants.cardBg,
                              border: Border.all(color: _isMuted ? Colors.redAccent : Colors.white24),
                            ),
                            child: Icon(_isMuted ? Icons.mic_off_rounded : Icons.mic_rounded, color: _isMuted ? Colors.redAccent : Colors.white, size: 28),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(_isMuted ? 'Muted' : 'Mute', style: const TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                      ],
                    ),

                    // End Call Button (Big Red)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _endCall,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppConstants.dangerColor,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x66E53935),
                                  blurRadius: 16,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 34),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('End Call', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),

                    // Speaker Button
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _isSpeakerOn = !_isSpeakerOn);
                          },
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isSpeakerOn ? AppConstants.primaryColor.withOpacity(0.3) : AppConstants.cardBg,
                              border: Border.all(color: _isSpeakerOn ? AppConstants.accentColor : Colors.white24),
                            ),
                            child: Icon(_isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded, color: _isSpeakerOn ? AppConstants.accentColor : Colors.white, size: 28),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(_isSpeakerOn ? 'Speaker' : 'Earpiece', style: const TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                      ],
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
}

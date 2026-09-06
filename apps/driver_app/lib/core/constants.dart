import 'package:flutter/material.dart';

class AppConstants {
  // Production Hostinger VPS Server & Custom Domain
  static const String defaultApiUrl = 'https://engine.getgigaride.com';
  static const String defaultSocketUrl = 'https://engine.getgigaride.com';

  // Live Production API Credentials
  static const String paystackPublicKey = 'pk_live_7ff0154fc1e7081a7281f6f0cec0ec48eaa89c41';
  static const String oneSignalAppId = '41b932e7-a242-4e35-89c4-f743b0ff005a';

  // Nigerian Market Benchmarks
  static const double petrolPricePerLitreNgn = 1050.0;
  static const double lagosMotLevyNgn = 50.0;

  // Driver Cockpit Palette: High contrast, obsidian, kinetic emerald & gold
  static const Color primaryColor = Color(0xFF0F766E); // Teal / Emerald 700
  static const Color primaryLight = Color(0xFF14B8A6); // Teal 500
  static const Color accentColor = Color(0xFFF59E0B);  // Gold / Amber
  static const Color darkBg = Color(0xFF0A0F1D);       // Deep Obsidian
  static const Color cardBg = Color(0xFF131C31);       // Midnight Slate
  static const Color surfaceBg = Color(0xFF1E293B);    // Slate 800
  static const Color textLight = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color dangerColor = Color(0xFFEF4444);  // Red / Rose
  static const Color successColor = Color(0xFF10B981); // Emerald
}

import 'package:flutter/material.dart';

class AppConstants {
  // Production Hostinger VPS Server
  static const String defaultApiUrl = 'http://69.62.127.50';
  static const String defaultSocketUrl = 'http://69.62.127.50';

  // Brand Palette: Kinetic Emerald, Cyan & Obsidian
  static const Color primaryColor = Color(0xFF0D9488); // Teal 600
  static const Color primaryLight = Color(0xFF14B8A6); // Teal 500
  static const Color accentColor = Color(0xFFF59E0B);  // Gold / Amber
  static const Color darkBg = Color(0xFF0A0F1D);       // Deep Obsidian
  static const Color cardBg = Color(0xFF131C31);       // Midnight Slate
  static const Color surfaceBg = Color(0xFF1E293B);    // Slate 800
  static const Color textLight = Color(0xFFF8FAFC);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color successColor = Color(0xFF10B981); // Emerald
  static const Color dangerColor = Color(0xFFEF4444);  // Rose / Red

  // SharedPreferences Keys
  static const String keyHasSeenOnboarding = 'has_seen_onboarding';
  static const String keyAuthToken = 'auth_token';
  static const String keySavedUser = 'saved_user';
}

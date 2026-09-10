import 'package:flutter/material.dart';
import 'constants.dart';

/// Global SnackBar — always floating, white text, never blocks the screen.
/// Use this everywhere instead of raw ScaffoldMessenger.showSnackBar calls.
class AppSnackBar {
  static void show(
    BuildContext context,
    String message, {
    Color backgroundColor = AppConstants.primaryColor,
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: duration,
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void success(BuildContext context, String message) =>
      show(context, message, backgroundColor: AppConstants.successColor, icon: Icons.check_circle_rounded);

  static void error(BuildContext context, String message) =>
      show(context, message, backgroundColor: AppConstants.dangerColor, icon: Icons.error_rounded);

  static void info(BuildContext context, String message) =>
      show(context, message, backgroundColor: AppConstants.cardBg, icon: Icons.info_rounded);
}

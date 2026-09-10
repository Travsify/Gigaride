import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';

class InAppAlertService {
  static void playNotificationChime() {
    try {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  static void showChatNotification(
    BuildContext context, {
    required String senderName,
    required String message,
    required VoidCallback onReply,
  }) {
    playNotificationChime();

    try {
      final overlay = Overlay.of(context);
      OverlayEntry? entry;

      entry = OverlayEntry(
        builder: (ctx) => _TopNotificationBanner(
          title: senderName,
          subtitle: message,
          icon: Icons.chat_bubble_rounded,
          accentColor: AppConstants.accentColor,
          actionLabel: 'REPLY',
          onAction: () {
            entry?.remove();
            onReply();
          },
          onDismiss: () {
            entry?.remove();
          },
        ),
      );

      overlay.insert(entry);

      Future.delayed(const Duration(milliseconds: 4500), () {
        if (entry?.mounted == true) {
          entry?.remove();
        }
      });
    } catch (e) {
      debugPrint('[InAppAlert] Overlay fallback: $e');
    }
  }

  static void showEventNotification(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.notifications_active_rounded,
    Color accentColor = AppConstants.primaryLight,
  }) {
    playNotificationChime();

    try {
      final overlay = Overlay.of(context);
      OverlayEntry? entry;

      entry = OverlayEntry(
        builder: (ctx) => _TopNotificationBanner(
          title: title,
          subtitle: message,
          icon: icon,
          accentColor: accentColor,
          onDismiss: () => entry?.remove(),
        ),
      );

      overlay.insert(entry);

      Future.delayed(const Duration(milliseconds: 4000), () {
        if (entry?.mounted == true) {
          entry?.remove();
        }
      });
    } catch (_) {}
  }
}

class _TopNotificationBanner extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  const _TopNotificationBanner({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
  });

  @override
  State<_TopNotificationBanner> createState() => _TopNotificationBannerState();
}

class _TopNotificationBannerState extends State<_TopNotificationBanner> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<Offset> _offsetAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _offsetAnim = Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 10,
      left: 14,
      right: 14,
      child: SlideTransition(
        position: _offsetAnim,
        child: GestureDetector(
          onVerticalDragUpdate: (details) {
            if (details.primaryDelta != null && details.primaryDelta! < -5) {
              widget.onDismiss();
            }
          },
          child: Material(
            elevation: 12,
            shadowColor: Colors.black54,
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFF0F1B26),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: widget.accentColor.withOpacity(0.4), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: widget.accentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            color: widget.accentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.actionLabel != null && widget.onAction != null) ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accentColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: widget.onAction,
                      child: Text(
                        widget.actionLabel!,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

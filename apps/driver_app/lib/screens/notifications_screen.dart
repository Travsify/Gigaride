import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/driver_provider.dart';

class DriverNotificationsScreen extends StatefulWidget {
  const DriverNotificationsScreen({super.key});

  @override
  State<DriverNotificationsScreen> createState() => _DriverNotificationsScreenState();
}

class _DriverNotificationsScreenState extends State<DriverNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverProvider>().loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriverProvider>();
    final notifs = provider.notifications;
    final unread = provider.unreadNotificationsCount;

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Text('Notifications', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 18)),
            if (unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppConstants.dangerColor, borderRadius: BorderRadius.circular(10)),
                child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        actions: [
          if (notifs.isNotEmpty)
            TextButton(
              onPressed: () => provider.markAllNotificationsRead(),
              child: const Text('Mark All Read', style: TextStyle(color: AppConstants.primaryLight, fontSize: 12)),
            ),
        ],
      ),
      body: SafeArea(
        child: notifs.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppConstants.cardBg, shape: BoxShape.circle),
                      child: const Icon(Icons.notifications_none_rounded, color: AppConstants.textMuted, size: 40),
                    ),
                    const SizedBox(height: 16),
                    const Text('No Notifications Yet', style: TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('Ride bid acceptances, payouts, and fleet alerts will appear here.', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                itemCount: notifs.length,
                itemBuilder: (ctx, idx) {
                  final n = notifs[idx];
                  final isRead = n['is_read'] == true;
                  final type = n['type'] ?? 'SYSTEM';

                  IconData icon = Icons.notifications_rounded;
                  Color iconColor = AppConstants.primaryLight;
                  if (type == 'BID') {
                    icon = Icons.gavel_rounded;
                    iconColor = AppConstants.accentColor;
                  } else if (type == 'WALLET') {
                    icon = Icons.account_balance_wallet_rounded;
                    iconColor = AppConstants.successColor;
                  } else if (type == 'SOS') {
                    icon = Icons.warning_amber_rounded;
                    iconColor = AppConstants.dangerColor;
                  }

                  return GestureDetector(
                    onTap: () {
                      if (!isRead) provider.markNotificationRead(n['id']);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isRead ? AppConstants.cardBg : AppConstants.surfaceBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isRead ? Colors.white10 : AppConstants.primaryLight.withOpacity(0.4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: iconColor.withOpacity(0.15), shape: BoxShape.circle),
                            child: Icon(icon, color: iconColor, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        n['title'] ?? 'Notification',
                                        style: TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: isRead ? FontWeight.w600 : FontWeight.bold),
                                      ),
                                    ),
                                    if (!isRead)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(color: AppConstants.primaryLight, shape: BoxShape.circle),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  n['message'] ?? '',
                                  style: const TextStyle(color: AppConstants.textMuted, fontSize: 12, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

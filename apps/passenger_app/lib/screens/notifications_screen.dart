import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/passenger_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PassengerProvider>().loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PassengerProvider>();
    final allNotifs = provider.notifications;
    final unread = provider.unreadNotificationsCount;

    final filteredNotifs = allNotifs.where((n) {
      if (_selectedFilter == 'ALL') return true;
      final type = (n['type'] ?? 'SYSTEM').toString().toUpperCase();
      if (_selectedFilter == 'RIDES') return type == 'BID' || type == 'RIDE';
      if (_selectedFilter == 'WALLET') return type == 'WALLET';
      if (_selectedFilter == 'SAFETY') return type == 'SOS' || type == 'SYSTEM' || type == 'KYC';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      appBar: AppBar(
        backgroundColor: AppConstants.cardBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text(
              'Activity & Alerts',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppConstants.dangerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unread',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (allNotifs.isNotEmpty)
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                provider.markAllNotificationsRead();
              },
              child: const Text(
                'Mark All Read',
                style: TextStyle(color: AppConstants.primaryLight, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Pills
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppConstants.cardBg,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('ALL', 'All Activities (${allNotifs.length})'),
                    const SizedBox(width: 8),
                    _buildFilterChip('RIDES', 'Rides & Bids'),
                    const SizedBox(width: 8),
                    _buildFilterChip('WALLET', 'Wallet & Payments'),
                    const SizedBox(width: 8),
                    _buildFilterChip('SAFETY', 'Safety & System'),
                  ],
                ),
              ),
            ),

            // Notification List
            Expanded(
              child: RefreshIndicator(
                color: AppConstants.primaryLight,
                backgroundColor: AppConstants.cardBg,
                onRefresh: () async => await provider.loadNotifications(),
                child: filteredNotifs.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(
                                    color: AppConstants.cardBg,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: const Icon(Icons.notifications_none_rounded, color: AppConstants.textMuted, size: 44),
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  'No Notifications',
                                  style: TextStyle(color: AppConstants.textLight, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Ride offers, driver arrivals, and payment credits will appear here in real time.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppConstants.textMuted, fontSize: 13, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        itemCount: filteredNotifs.length,
                        itemBuilder: (ctx, idx) {
                          final n = filteredNotifs[idx];
                          final isRead = n['is_read'] == true;
                          final type = (n['type'] ?? 'SYSTEM').toString().toUpperCase();
                          final createdAt = n['created_at'];

                          String formattedTime = '';
                          if (createdAt != null) {
                            try {
                              final dt = DateTime.parse(createdAt.toString()).toLocal();
                              final now = DateTime.now();
                              if (now.difference(dt).inDays == 0) {
                                formattedTime = DateFormat('h:mm a').format(dt);
                              } else {
                                formattedTime = DateFormat('MMM d, h:mm a').format(dt);
                              }
                            } catch (_) {}
                          }

                          IconData icon = Icons.notifications_rounded;
                          Color iconColor = AppConstants.primaryLight;
                          if (type == 'BID' || type == 'RIDE') {
                            icon = Icons.directions_car_rounded;
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
                              HapticFeedback.selectionClick();
                              if (!isRead) provider.markNotificationRead(n['id']);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isRead ? AppConstants.cardBg : AppConstants.surfaceBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isRead ? Colors.white10 : AppConstants.primaryLight.withOpacity(0.4),
                                  width: isRead ? 1 : 1.5,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: iconColor.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
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
                                                style: TextStyle(
                                                  color: AppConstants.textLight,
                                                  fontSize: 14,
                                                  fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            if (!isRead)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: AppConstants.primaryLight,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          n['message'] ?? '',
                                          style: const TextStyle(
                                            color: AppConstants.textMuted,
                                            fontSize: 12.5,
                                            height: 1.35,
                                          ),
                                        ),
                                        if (formattedTime.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            formattedTime,
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.35),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = filterKey);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.primaryLight : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppConstants.primaryLight : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

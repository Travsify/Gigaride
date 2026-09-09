import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';

class DriverSupportHelpScreen extends StatefulWidget {
  const DriverSupportHelpScreen({super.key});

  @override
  State<DriverSupportHelpScreen> createState() => _DriverSupportHelpScreenState();
}

class _DriverSupportHelpScreenState extends State<DriverSupportHelpScreen> {
  final List<Map<String, dynamic>> _driverTickets = [
    {
      'id': 'DRV-40192',
      'category': 'Subscription & Quota',
      'subject': 'Daily 100-Ride Pass activation inquiry',
      'status': 'RESOLVED',
      'date': 'Yesterday',
      'response': 'Your subscription was verified. 999 rides active on your terminal with 0% platform commission.',
    }
  ];

  void _showNewDriverComplaintModal(String category, {String? defaultSubject}) {
    final subjectCtrl = TextEditingController(text: defaultSubject ?? '');
    final detailsCtrl = TextEditingController();
    String urgency = 'MEDIUM';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.support_agent_rounded, color: AppConstants.accentColor, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Driver Dispatch Help: $category',
                        style: const TextStyle(color: AppConstants.textLight, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppConstants.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Our partner support desk operates 24/7 with a 15-minute resolution priority for active drivers.',
                style: TextStyle(color: AppConstants.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: subjectCtrl,
                style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Subject (e.g. Passenger refused fare payment)',
                  hintStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: AppConstants.surfaceBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsCtrl,
                maxLines: 4,
                style: const TextStyle(color: AppConstants.textLight, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Explain the incident clearly. Include trip details, pickup/dropoff points...',
                  hintStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
                  filled: true,
                  fillColor: AppConstants.surfaceBg,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('Priority:', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: const Text('Normal', style: TextStyle(fontSize: 11)),
                    selected: urgency == 'NORMAL',
                    selectedColor: AppConstants.primaryColor,
                    onSelected: (_) => setModalState(() => urgency = 'NORMAL'),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Urgent', style: TextStyle(fontSize: 11)),
                    selected: urgency == 'URGENT',
                    selectedColor: Colors.amber.shade800,
                    onSelected: (_) => setModalState(() => urgency = 'URGENT'),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Safety / Incident', style: TextStyle(fontSize: 11)),
                    selected: urgency == 'SAFETY',
                    selectedColor: AppConstants.dangerColor,
                    onSelected: (_) => setModalState(() => urgency = 'SAFETY'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final subj = subjectCtrl.text.trim();
                    final desc = detailsCtrl.text.trim();
                    if (subj.isEmpty || desc.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please provide both subject and details.')),
                      );
                      return;
                    }
                    HapticFeedback.mediumImpact();
                    final newId = 'DRV-${(10000 + DateTime.now().millisecondsSinceEpoch % 90000)}';
                    setState(() {
                      _driverTickets.insert(0, {
                        'id': newId,
                        'category': category,
                        'subject': subj,
                        'status': 'ASSIGNED',
                        'date': 'Just now',
                        'response': 'Assigned to Senior Driver Relations & Dispatch Team.',
                      });
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✓ Ticket submitted! Reference ID: $newId'),
                        backgroundColor: AppConstants.successColor,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Submit Ticket to Dispatch Team', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppConstants.textLight, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Driver Support & Complaints Center',
          style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Top Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF131C31)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppConstants.primaryLight.withOpacity(0.3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified_user_rounded, color: Colors.white, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Driver Partner Protection Desk',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    '100% Zero platform commission. Guaranteed fare dispute mediation, subscription assistance, and emergency response.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Top Issue Categories
            const Text(
              'Select Driver Issue Category',
              style: TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _buildCategoryCard(
                  icon: Icons.money_off_rounded,
                  color: Colors.amberAccent,
                  title: 'Fare & Payment Dispute',
                  subtitle: 'Unpaid cash or transfer discrepancy',
                  onTap: () => _showNewDriverComplaintModal('Fare Dispute', defaultSubject: 'Rider did not pay full agreed fare'),
                ),
                _buildCategoryCard(
                  icon: Icons.warning_rounded,
                  color: AppConstants.dangerColor,
                  title: 'Passenger Conduct',
                  subtitle: 'Disrespect, aggression or damage',
                  onTap: () => _showNewDriverComplaintModal('Passenger Conduct', defaultSubject: 'Inappropriate rider conduct report'),
                ),
                _buildCategoryCard(
                  icon: Icons.card_membership_rounded,
                  color: Colors.cyanAccent,
                  title: 'Subscriptions & Quota',
                  subtitle: 'Plan activation, renewal, receipts',
                  onTap: () => _showNewDriverComplaintModal('Subscription', defaultSubject: 'Subscription activation assistance'),
                ),
                _buildCategoryCard(
                  icon: Icons.account_balance_rounded,
                  color: AppConstants.successColor,
                  title: 'Payouts & Living Wallet',
                  subtitle: 'Settlements & bank withdrawals',
                  onTap: () => _showNewDriverComplaintModal('Payout & Wallet', defaultSubject: 'Payout transfer inquiry'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Active / Recent Tickets Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Resolution Tickets',
                  style: TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_driverTickets.length} Active',
                    style: const TextStyle(color: AppConstants.primaryLight, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._driverTickets.map((t) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppConstants.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(t['id'], style: const TextStyle(color: AppConstants.accentColor, fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: t['status'] == 'RESOLVED' ? Colors.green.withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  t['status'],
                                  style: TextStyle(
                                    color: t['status'] == 'RESOLVED' ? Colors.greenAccent : Colors.amberAccent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(t['date'], style: const TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(t['subject'], style: const TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(t['response'], style: const TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                    ],
                  ),
                )),

            const SizedBox(height: 20),

            // FAQs Accordion
            const Text(
              'Driver Partner FAQs',
              style: TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppConstants.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  _buildFaqItem(
                    'Do you deduct commissions from my fares?',
                    'Never! Giga Ride is 100% commission-free. You keep 100% of the agreed fare paid by cash, bank transfer, or living wallet. You only subscribe to flat unlimited or ride-pass packages.',
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  _buildFaqItem(
                    'What if a passenger refuses to pay or transfers less?',
                    'Tap "Fare & Payment Dispute" above. Attach the trip details. We verify GPS telemetry and can debit the passenger\'s living wallet or flag their account.',
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  _buildFaqItem(
                    'How does the Fuel Card integration work?',
                    'You can top up your virtual Giga Fuel Card directly from your living wallet balance and tap on POS terminals at partner filling stations across Nigeria.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppConstants.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: AppConstants.textMuted, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return ExpansionTile(
      iconColor: AppConstants.accentColor,
      collapsedIconColor: AppConstants.textMuted,
      title: Text(question, style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.w600)),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
          child: Text(answer, style: const TextStyle(color: AppConstants.textMuted, fontSize: 12, height: 1.4)),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';

class SupportHelpScreen extends StatefulWidget {
  final bool isTab;
  const SupportHelpScreen({super.key, this.isTab = false});

  @override
  State<SupportHelpScreen> createState() => _SupportHelpScreenState();
}

class _SupportHelpScreenState extends State<SupportHelpScreen> {
  final List<Map<String, dynamic>> _myTickets = [
    {
      'id': 'TCK-94812',
      'category': 'Trip & Fare',
      'subject': 'Fare calculation clarification',
      'status': 'RESOLVED',
      'date': 'Yesterday',
      'response': 'Your Living Wallet was adjusted accordingly. Thank you for choosing Giga Ride.',
    }
  ];

  void _showNewComplaintModal(String category, {String? defaultSubject}) {
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
                      const Icon(Icons.report_problem_rounded, color: AppConstants.accentColor, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'File Complaint: $category',
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
                'Our safety and dispute resolution desk reviews complaints within 15 minutes.',
                style: TextStyle(color: AppConstants.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: subjectCtrl,
                style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Summary / Subject (e.g. Fare discrepancy)',
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
                  hintText: 'Explain what happened in detail. Include date, driver name or plate if known...',
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
                    label: const Text('Safety Issue', style: TextStyle(fontSize: 11)),
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
                    final newId = 'TCK-${(10000 + DateTime.now().millisecondsSinceEpoch % 90000)}';
                    setState(() {
                      _myTickets.insert(0, {
                        'id': newId,
                        'category': category,
                        'subject': subj,
                        'status': 'UNDER REVIEW',
                        'date': 'Just now',
                        'response': 'Assigned to Giga Safety & Dispatch Desk. A resolution agent is reviewing your incident.',
                      });
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✓ Complaint submitted! Reference Ticket: $newId'),
                        backgroundColor: AppConstants.successColor,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Submit Ticket to Dispatch Desk', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        automaticallyImplyLeading: false,
        leading: widget.isTab
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppConstants.textLight, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
        title: const Text(
          'Complaints & Support Hub',
          style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 18),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.support_agent_rounded, color: Colors.white, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'We\'re Here to Help You 24/7',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Direct in-app dispatch dispute resolution, safety mediation, and instant refund support.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Top Complaint Categories Grid
            const Text(
              'Select Issue Category',
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
                  icon: Icons.receipt_long_rounded,
                  color: Colors.cyanAccent,
                  title: 'Fare & Trip Issues',
                  subtitle: 'Overcharged or route dispute',
                  onTap: () => _showNewComplaintModal('Fare & Trip', defaultSubject: 'Fare discrepancy on recent ride'),
                ),
                _buildCategoryCard(
                  icon: Icons.shield_rounded,
                  color: AppConstants.dangerColor,
                  title: 'Safety & Conduct',
                  subtitle: 'Reckless driving or disrespect',
                  onTap: () => _showNewComplaintModal('Safety & Conduct', defaultSubject: 'Driver behavior or reckless driving report'),
                ),
                _buildCategoryCard(
                  icon: Icons.backpack_rounded,
                  color: Colors.amberAccent,
                  title: 'Lost & Found',
                  subtitle: 'Left item in vehicle',
                  onTap: () => _showNewComplaintModal('Lost & Found', defaultSubject: 'Inquiry regarding item left in car'),
                ),
                _buildCategoryCard(
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppConstants.accentColor,
                  title: 'Living Wallet',
                  subtitle: 'Deposit, transfer or refund',
                  onTap: () => _showNewComplaintModal('Living Wallet', defaultSubject: 'Wallet funding / transfer inquiry'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Active / Recent Support Tickets Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Support Tickets',
                  style: TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_myTickets.length} Ticket${_myTickets.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: AppConstants.primaryLight, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._myTickets.map((t) => Container(
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
              'Frequently Asked Questions',
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
                    'How does the Living Wallet refund work?',
                    'If a ride is cancelled after payment or if there is an agreed cash change discrepancy, funds are credited immediately to your Living Wallet. You can withdraw to your commercial bank anytime with zero fees.',
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  _buildFaqItem(
                    'What if I leave an item in a vehicle?',
                    'Tap "Lost & Found" above to submit a lost item report. Our team will verify the vehicle details and connect with the driver partner to secure your belongings immediately.',
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  _buildFaqItem(
                    'Is my phone number private from the driver?',
                    'Yes! Giga Ride implements strict asymmetric phone number masking. In-app VoIP audio calls and messaging route through our encrypted dispatch proxy without revealing your mobile number.',
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  _buildFaqItem(
                    'How do I dispute a fare difference?',
                    'Tap "Fare & Trip Issues" to file a dispute. Attach details and our audit team will cross-reference the GPS telemetry breadcrumbs to adjust or refund the fare difference.',
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

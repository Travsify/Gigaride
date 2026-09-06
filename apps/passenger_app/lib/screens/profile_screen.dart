import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/passenger_provider.dart';
import 'phone_auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onOfflineBookingPressed;
  const ProfileScreen({super.key, required this.onOfflineBookingPressed});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  void _showPrivacyPolicy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.privacy_tip_rounded, color: AppConstants.primaryLight, size: 24),
                      SizedBox(width: 10),
                      Text('Privacy & Data Protection', style: TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close, color: AppConstants.textMuted), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppConstants.primaryColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppConstants.primaryColor.withOpacity(0.3))),
                child: const Text(
                  'Regulated under the Nigeria Data Protection Act (NDPA 2023) and the Nigeria Data Protection Regulation (NDPR).',
                  style: TextStyle(color: AppConstants.primaryLight, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 18),
              _buildPolicySection(
                '1. Asymmetric Phone Number Masking',
                'Your personal mobile number is strictly hidden from drivers. All in-app calls and chats utilize VoIP proxy relays and cryptographic masking. Drivers never receive your real phone number.',
              ),
              _buildPolicySection(
                '2. Information We Collect & Legal Basis',
                'We collect your verified mobile number (via Twilio OTP), email address for digital receipts, and high-precision GPS telemetry strictly during ride requests and active trips to facilitate routing and emergency dispatch.',
              ),
              _buildPolicySection(
                '3. Bank-Grade Financial Security',
                'Dedicated NUBAN virtual bank accounts are powered exclusively by Korapay for direct bank transfers, while card funding and dynamic payment checkouts are powered directly by Paystack (PCI-DSS Level 1 certified). Giga Ride never stores or handles raw payment card PANs or security codes.',
              ),
              _buildPolicySection(
                '4. Location Telemetry & SOS Broadcasting',
                'Live GPS telemetry is recorded during trips for passenger safety. In case of an emergency, tapping the SOS button immediately broadcasts your encrypted tracking link to your registered emergency contacts and security operations.',
              ),
              _buildPolicySection(
                '5. User Rights & Complete Data Erasure',
                'Under Section 34 of the NDPA 2023, you retain the legal right to inspect your data, rectify inaccuracies, or permanently request the erasure of your personal data and travel history.',
              ),
              _buildPolicySection(
                '6. Data Protection Officer (DPO)',
                'For data privacy inquiries, contact our legal DPO at dpo@gigaride.ng or privacy@gigaride.ng. Head Office: Plot 12B Admiralty Way, Lekki Phase 1, Lagos, Nigeria.',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('I Understand & Agree', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTermsOfService(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Terms of Service & Rider Agreement', style: TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: AppConstants.textMuted), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 14),
              _buildPolicySection(
                '1. Fair Dynamic Bidding',
                'Fares on Giga Ride are haggled transparently between passenger and driver. Drivers retain 100% of the agreed trip fare with zero platform deductions.',
              ),
              _buildPolicySection(
                '2. Passenger Safety & Conduct',
                'Passengers agree to treat driver partners with dignity and adhere to traffic and luggage regulations. Zero tolerance policy for harassment or property damage.',
              ),
              _buildPolicySection(
                '3. Living Wallet & Instant Refunds',
                'Funds in your Giga Living Wallet can be used to pay for trips or withdrawn back to your commercial bank account at any time.',
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProfile(BuildContext context, PassengerProvider provider) {
    final nameCtrl = TextEditingController(text: provider.user?['fullName'] ?? provider.user?['full_name'] ?? '');
    final emailCtrl = TextEditingController(text: provider.user?['email'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Passenger Profile', style: TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, style: const TextStyle(color: AppConstants.textLight, fontSize: 14), decoration: _inputDeco('Full Name', Icons.person_outline)),
            const SizedBox(height: 12),
            TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: AppConstants.textLight, fontSize: 14), decoration: _inputDeco('Email Address', Icons.email_outlined)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✓ Profile updated successfully!'), backgroundColor: AppConstants.successColor));
                },
                child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, PassengerProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppConstants.dangerColor, size: 24),
            SizedBox(width: 10),
            Text('Delete Account?', style: TextStyle(color: AppConstants.textLight, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'In compliance with data protection laws, deleting your account will permanently scrub your profile, trip receipts, and living wallet. This action is irreversible.',
          style: TextStyle(color: AppConstants.textMuted, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppConstants.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.dangerColor),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const PhoneAuthScreen()), (r) => false);
              }
            },
            child: const Text('Permanently Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, PassengerProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out?', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out of your Giga Ride account?', style: TextStyle(color: AppConstants.textMuted, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppConstants.textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.dangerColor),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const PhoneAuthScreen()), (r) => false);
              }
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddContactModal(BuildContext context, PassengerProvider provider) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Trusted SOS Contact', style: TextStyle(color: AppConstants.textLight, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('This contact will receive SMS SOS notifications with your live tracking location in emergencies.', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, style: const TextStyle(color: AppConstants.textLight, fontSize: 14), decoration: _inputDeco('Full Name (e.g. Sister, Dad)', Icons.person_outline)),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, style: const TextStyle(color: AppConstants.textLight, fontSize: 14), decoration: _inputDeco('Phone Number (e.g. 08012345678)', Icons.phone_outlined)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () {
                  final n = nameCtrl.text.trim();
                  final p = phoneCtrl.text.trim();
                  if (n.isNotEmpty && p.isNotEmpty) {
                    provider.addEmergencyContact(n, p);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Save Contact', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicySection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(color: AppConstants.textMuted, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 13),
      prefixIcon: Icon(icon, color: AppConstants.textMuted, size: 20),
      filled: true,
      fillColor: AppConstants.surfaceBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PassengerProvider>();
    final user = provider.user;
    final name = user?['fullName'] ?? user?['full_name'] ?? 'Passenger';
    final phone = user?['phoneNumber'] ?? user?['phone_number'] ?? '+234 800 GIGA';
    final email = user?['email'] ?? 'passenger@gigaride.ng';
    final emergencyContacts = provider.emergencyContacts;

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Passenger Profile & Settings', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // User Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppConstants.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [AppConstants.primaryLight, AppConstants.primaryColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'P', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(color: AppConstants.textLight, fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(phone, style: const TextStyle(color: AppConstants.textMuted, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(email, style: const TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppConstants.primaryLight, size: 20),
                    onPressed: () => _showEditProfile(context, provider),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Ride Comfort Preferences
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppConstants.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ride Comfort Preferences', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.ac_unit_rounded, color: Colors.cyanAccent, size: 20),
                    title: const Text('Always AC On', style: TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.w600)),
                    value: provider.alwaysAcOn,
                    activeColor: Colors.cyanAccent,
                    onChanged: (val) => provider.setPreference('alwaysAcOn', val),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.volume_off_rounded, color: Colors.purpleAccent, size: 20),
                    title: const Text('Quiet Ride', style: TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.w600)),
                    value: provider.preferQuiet,
                    activeColor: Colors.purpleAccent,
                    onChanged: (val) => provider.setPreference('preferQuiet', val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Trusted SOS Emergency Contacts
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppConstants.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Trusted SOS Contacts', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.bold)),
                      if (emergencyContacts.length < 3)
                        TextButton.icon(
                          onPressed: () => _showAddContactModal(context, provider),
                          icon: const Icon(Icons.add_rounded, size: 16, color: AppConstants.primaryLight),
                          label: const Text('Add', style: TextStyle(color: AppConstants.primaryLight, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (emergencyContacts.isEmpty)
                    const Text('Add up to 3 family or friends who will receive live tracking alerts during emergencies.', style: TextStyle(color: AppConstants.textMuted, fontSize: 11))
                  else
                    ...emergencyContacts.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${e.value['name']} • ${e.value['phone']}', style: const TextStyle(color: AppConstants.textLight, fontSize: 12)),
                          IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: AppConstants.dangerColor), onPressed: () => provider.removeEmergencyContact(e.key)),
                        ],
                      ),
                    )),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Legal, Privacy, Safety & Settings List
            Container(
              decoration: BoxDecoration(color: AppConstants.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined, color: AppConstants.primaryLight),
                    title: const Text('Privacy Policy (NDPA & NDPR)', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Asymmetric number masking & data rights', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, color: AppConstants.textMuted),
                    onTap: () => _showPrivacyPolicy(context),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined, color: AppConstants.textMuted),
                    title: const Text('Terms of Service & Rider Agreement', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Zero commission bidding & safety charter', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, color: AppConstants.textMuted),
                    onTap: () => _showTermsOfService(context),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  ListTile(
                    leading: const Icon(Icons.chat_bubble_outline_rounded, color: AppConstants.successColor),
                    title: const Text('24/7 WhatsApp Concierge', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Instant support for booking & dispute resolution', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, color: AppConstants.textMuted),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connecting to 24/7 Giga Concierge...'), backgroundColor: AppConstants.successColor));
                    },
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete_forever_outlined, color: AppConstants.dangerColor),
                    title: const Text('Delete Account', style: TextStyle(color: AppConstants.dangerColor, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Request permanent erasure of your account', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, color: AppConstants.dangerColor),
                    onTap: () => _showDeleteAccountDialog(context, provider),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: AppConstants.dangerColor),
                    title: const Text('Sign Out', style: TextStyle(color: AppConstants.dangerColor, fontSize: 14, fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.chevron_right, color: AppConstants.dangerColor),
                    onTap: () => _showLogoutDialog(context, provider),
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
}

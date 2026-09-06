import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/driver_provider.dart';
import 'phone_auth_screen.dart';
import 'kyc_screen.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  bool _acAvailable = true;
  bool _biometricLock = false;

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
                'Your personal mobile number is never disclosed to passengers. All in-app voice calls and chat messages utilize end-to-end encrypted virtual proxy relays, ensuring full anonymity before, during, and after each trip.',
              ),
              _buildPolicySection(
                '2. Information We Collect & Legal Basis',
                'We collect government identity credentials (NIN and FRSC Driver\'s License verified in real time via Official Identity Portals), high-precision GPS telemetry for trip navigation and SOS dispatch, and vehicle technical specifications to ensure passenger safety and federal compliance.',
              ),
              _buildPolicySection(
                '3. Bank-Grade Financial Security',
                'Dedicated NUBAN virtual bank accounts are powered exclusively by Korapay for direct bank transfers, while card funding and dynamic payment checkouts are powered directly by Paystack (PCI-DSS Level 1 certified). Giga Ride never stores full card PANs or CVVs on platform servers.',
              ),
              _buildPolicySection(
                '4. Real-Time Telemetry & Safety Auditing',
                'Location telemetry is recorded only while the terminal is Online or during active trips. Telemetry logs are retained for safety dispute resolution, insurance claims, and emergency dispatch, in strict compliance with statutory transport guidelines.',
              ),
              _buildPolicySection(
                '5. Driver Rights & Data Erasure',
                'In accordance with Section 34 of the NDPA 2023, you have the right to request access to your data, rectify inaccuracies, or permanently request account deactivation and personal data erasure.',
              ),
              _buildPolicySection(
                '6. Data Protection Officer (DPO)',
                'For inquiries or to exercise your privacy rights, contact our Data Protection Officer at dpo@gigaride.ng or privacy@gigaride.ng. Head Office: Plot 12B Admiralty Way, Lekki Phase 1, Lagos, Nigeria.',
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
                  const Text('Driver Partner Agreement', style: TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: AppConstants.textMuted), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 14),
              _buildPolicySection(
                '1. 100% Zero Platform Commission',
                'Giga Ride charges 0% commission on all completed trips. Drivers retain 100% of the agreed fare paid by passengers. Platform access is governed exclusively through upfront ride packs or unlimited subscriptions.',
              ),
              _buildPolicySection(
                '2. Code of Conduct & Vehicle Standards',
                'Drivers agree to maintain safe, roadworthy commercial vehicles with valid FRSC licenses, working air conditioning, and polite passenger conduct. Non-compliance may result in temporary cockpit suspension.',
              ),
              _buildPolicySection(
                '3. Fair Live Bidding',
                'Fares are determined by mutual agreement between passenger and driver. Drivers have the freedom to accept proposed fares or submit custom counter-bids based on traffic and operating costs.',
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProfile(BuildContext context, DriverProvider provider) {
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
            const Text('Edit Driver Profile', style: TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.bold)),
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

  void _showDeleteAccountDialog(BuildContext context, DriverProvider provider) {
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
          'In compliance with data protection laws, deleting your account will permanently scrub your profile, subscription history, and KYC credentials. This action is irreversible.',
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

  void _showLogoutDialog(BuildContext context, DriverProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out?', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out of your Giga Driver terminal on this device?', style: TextStyle(color: AppConstants.textMuted, fontSize: 13)),
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
    final provider = context.watch<DriverProvider>();
    final user = provider.user;
    final profile = provider.driverProfile;

    final name = user?['fullName'] ?? user?['full_name'] ?? 'Giga Driver';
    final phone = user?['phoneNumber'] ?? user?['phone_number'] ?? '+234 800 GIGA';
    final email = user?['email'] ?? 'driver@gigaride.ng';
    final make = profile?['vehicle_make'] ?? 'Toyota';
    final model = profile?['vehicle_model'] ?? 'Corolla';
    final year = profile?['vehicle_year'] ?? 2018;
    final plate = profile?['license_plate'] ?? 'EKY-492-LG';
    final kyc = profile?['kyc_status'] ?? 'PENDING';

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Driver Terminal & Profile', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Driver Profile Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppConstants.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppConstants.primaryLight, AppConstants.primaryColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'D', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))),
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

            // Vehicle Specs & Government Status Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: AppConstants.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Commercial Vehicle Profile', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.bold)),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KycScreen())),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: kyc == 'APPROVED' ? AppConstants.successColor.withOpacity(0.15) : AppConstants.accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kyc == 'APPROVED' ? AppConstants.successColor : AppConstants.accentColor),
                          ),
                          child: Text(
                            kyc == 'APPROVED' ? '✓ Verified & Approved' : 'KYC $kyc',
                            style: TextStyle(color: kyc == 'APPROVED' ? AppConstants.successColor : AppConstants.accentColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _buildSpecChip('Vehicle', '$make $model')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildSpecChip('Year', '$year')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildSpecChip('Plate', plate)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Driver Comfort & Terminal Settings
            Container(
              decoration: BoxDecoration(color: AppConstants.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.ac_unit_rounded, color: Colors.cyanAccent),
                    title: const Text('Air Conditioning (AC) Available', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Indicates active cooling available in vehicle cabin', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    value: _acAvailable,
                    activeColor: Colors.cyanAccent,
                    onChanged: (val) => setState(() => _acAvailable = val),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint_rounded, color: AppConstants.primaryLight),
                    title: const Text('Biometric Terminal Security', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Require fingerprint/FaceID on terminal launch', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    value: _biometricLock,
                    activeColor: AppConstants.primaryLight,
                    onChanged: (val) => setState(() => _biometricLock = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Legal, Privacy, Safety & Support
            Container(
              decoration: BoxDecoration(color: AppConstants.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined, color: AppConstants.primaryLight),
                    title: const Text('Privacy Policy (NDPA & NDPR)', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Asymmetric number masking & data protection', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, color: AppConstants.textMuted),
                    onTap: () => _showPrivacyPolicy(context),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined, color: AppConstants.textMuted),
                    title: const Text('Driver Partner Agreement', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('0% commission terms and operating guidelines', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, color: AppConstants.textMuted),
                    onTap: () => _showTermsOfService(context),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  ListTile(
                    leading: const Icon(Icons.chat_bubble_outline_rounded, color: AppConstants.successColor),
                    title: const Text('24/7 Driver Support Concierge', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Direct WhatsApp and priority emergency dispatch', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, color: AppConstants.textMuted),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connecting to 24/7 Driver Concierge...'), backgroundColor: AppConstants.successColor));
                    },
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete_forever_outlined, color: AppConstants.dangerColor),
                    title: const Text('Delete Account', style: TextStyle(color: AppConstants.dangerColor, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Request permanent erasure of your data', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
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

  Widget _buildSpecChip(String label, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: AppConstants.surfaceBg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppConstants.textMuted, fontSize: 10)),
          const SizedBox(height: 2),
          Text(val, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppConstants.textLight, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

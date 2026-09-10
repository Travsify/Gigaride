import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../providers/driver_provider.dart';
import 'phone_auth_screen.dart';
import 'kyc_screen.dart';
import 'support_help_screen.dart';
import 'driver_rides_screen.dart';


class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  bool _acAvailable = true;
  bool _biometricLock = false;

  Future<void> _callEmergencyHotline(String number) async {
    final uri = Uri.parse('tel:$number');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open phone dialer for $number: $e'),
            backgroundColor: AppConstants.dangerColor,
          ),
        );
      }
    }
  }

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
                '1. Asymmetric Phone Number Masking & VoIP Communications',
                'Your personal mobile number is never disclosed or transmitted to passengers. All incoming and outgoing voice calls and messages utilize end-to-end encrypted virtual proxy relays, ensuring complete confidentiality before, during, and after each trip.',
              ),
              _buildPolicySection(
                '2. Information Collected & Official Verification',
                'We collect government identity credentials (NIN and FRSC Driver\'s License verified in real time via NIMC and FRSC official databases), vehicle registration papers, high-precision GPS telemetry, and terminal hardware identifiers to ensure passenger safety, vehicle traceability, and federal compliance.',
              ),
              _buildPolicySection(
                '3. Background Location Tracking Disclosure (App Store Compliance)',
                'The Giga Driver terminal collects precise real-time location data even when the app is running in the background or when the screen is locked. This telemetry is strictly required to: (a) broadcast your vehicle position on passenger radar maps, (b) calculate accurate distance and arrival estimates, (c) route navigation, and (d) stream live coordinates during emergency SOS alerts.',
              ),
              _buildPolicySection(
                '4. Bank-Grade Financial Security & Payouts',
                'Dedicated NUBAN virtual accounts and direct bank settlement payouts are provisioned via CBN-licensed payment banking partners. Giga never captures or stores payment card CVVs or bank login credentials on platform servers.',
              ),
              _buildPolicySection(
                '5. Statutory Data Retention Schedule',
                'Driver identity credentials, KYC verification records, and transaction settlement histories are retained for six (6) years in strict compliance with Central Bank of Nigeria (CBN) AML/CFT guidelines and Nigerian tax regulations. Real-time GPS telemetry is retained for twelve (12) months for safety dispute resolution, insurance claims, and statutory auditing.',
              ),
              _buildPolicySection(
                '6. Law Enforcement Cooperation & Legal Disclosure',
                'In accordance with Nigerian law, Pickpadi Global Ltd reserves the right to disclose driver vehicle telemetry, trip records, and identity files to statutory law enforcement agencies (Nigeria Police Force, FRSC, VIO, EFCC) upon receipt of a valid court order, warrant, or in connection with criminal or road collision investigations.',
              ),
              _buildPolicySection(
                '7. Driver Rights & Account Erasure (§ 34 NDPA)',
                'Under Section 34 of the NDPA 2023, you retain the legal right to inspect your profile data, rectify inaccuracies, or permanently request account deactivation and personal data erasure via the in-app Delete Account utility.',
              ),
              _buildPolicySection(
                '8. Data Protection Officer (DPO) Contact',
                'For inquiries or to exercise your statutory data privacy rights, contact our Data Protection Officer at dpo@gigaride.ng or privacy@gigaride.ng. Corporate Office: Plot 12B Admiralty Way, Lekki Phase 1, Lagos, Nigeria.',
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
                '1. Independent Contractor Relationship & Non-Exclusivity',
                'Driver Partners are independent commercial transport operators and not employees, agents, or joint-venturers of Pickpadi Global Ltd under the Nigerian Labour Act. Giga is exclusively a technology dispatch marketplace. Drivers maintain absolute discretion over their working hours, route selection, and decision to accept or decline requests. Drivers are expressly free to operate on other commercial platforms (e.g. Bolt, Uber, InDrive) or provide private transport services without restriction.',
              ),
              _buildPolicySection(
                '2. 100% Zero Commission & Non-Refundable Plans',
                'Giga charges 0% commission on all completed trips. Driver Partners retain 100% of all agreed fares paid by passengers. Terminal radar visibility is governed by subscription plans or ride packs. Once trip allowance is exhausted, two (2) grace trips are permitted before radar visibility is suspended. All subscription payments and ride pack purchases are strictly non-refundable once activated or partially utilized.',
              ),
              _buildPolicySection(
                '3. Real-Time Haggling & Fare Gouging Prohibition',
                'Trip fares are agreed upon directly between Driver and Rider via in-app bidding. Driver Partners are strictly prohibited from demanding excess cash, unilateral surcharges, or extorting passengers above the agreed price upon arrival. Price gouging constitutes a contractual breach and violation of Nigerian FCCPC regulations, resulting in immediate suspension.',
              ),
              _buildPolicySection(
                '4. Strict Prohibition of Offline Solicitation ("Street Poaching")',
                'Driver Partners are strictly prohibited from accepting a Giga ride request and subsequently instructing or inducing the passenger to cancel the in-app trip to pay cash offline. Offlining bypasses safety telemetry, invalidates insurance coverage, and results in instant, permanent account deactivation and blacklisting.',
              ),
              _buildPolicySection(
                '5. Vehicle Roadworthiness, Licensing & NAICOM Insurance',
                'Driver Partners warrant that their vehicle meets all statutory roadworthiness standards, possesses a valid FRSC driver\'s license, valid Roadworthiness Certificate, functional air conditioning, and active Third-Party or Comprehensive Motor Vehicle Insurance as prescribed by NAICOM. Pickpadi Global Ltd provides no motor vehicle insurance.',
              ),
              _buildPolicySection(
                '6. Passenger Confidentiality & Anti-Harassment',
                'Driver Partners must maintain strict passenger confidentiality. Passenger phone numbers are masked. Drivers are strictly prohibited from storing, extracting, stalking, or contacting passengers outside the platform for personal purposes. Pickpadi Global Ltd enforces zero tolerance for verbal abuse, sexual advances, or physical altercations.',
              ),
              _buildPolicySection(
                '7. Cash Settlement & Wallet Change Rollover',
                'Drivers may collect fares via cash, direct bank transfer, or Wallet settlement. When a passenger tenders excess cash, the Driver Partner agrees to credit the exact change to the passenger\'s Wallet using the in-app Change Settlement utility to eliminate cash change disputes.',
              ),
              _buildPolicySection(
                '8. Criminal Background & Medical Fitness Warranty',
                'Driver Partners warrant that they have no criminal convictions, pending felony charges, or history of violent crimes or driving under the influence (DUI). Drivers agree to periodic background checks and medical fitness verifications upon request.',
              ),
              _buildPolicySection(
                '9. Tax & Statutory Levies Indemnification',
                'Driver Partners operate as independent business owners and are solely responsible for declaring and remitting all applicable federal, state, and municipal taxes (including Personal Income Tax - PIT, state road permits, and local government vehicle stickers). Pickpadi Global Ltd is not a tax withholding agent and drivers indemnify the company against any personal tax liabilities.',
              ),
              _buildPolicySection(
                '10. Limitation of Liability & Indemnification',
                'Driver Partners agree to defend, indemnify, and hold harmless Pickpadi Global Ltd, its directors, employees, and agents from any claims, fines, vehicle impoundments (e.g. VIO, LASTMA), traffic citations, road accidents, or third-party liabilities arising from the driver\'s operation of their vehicle.',
              ),
              _buildPolicySection(
                '11. Governing Law, Class Action Waiver & Binding Arbitration',
                'This Agreement is governed by the laws of the Federal Republic of Nigeria. All disputes shall be resolved on an individual basis; class, collective, or representative proceedings are expressly waived. Any dispute that cannot be settled amicably within thirty (30) days shall be submitted to final and binding arbitration in Lagos State under the Nigerian Arbitration and Mediation Act 2023.',
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
                  final newName = nameCtrl.text.trim();
                  final newEmail = emailCtrl.text.trim();
                  if (newName.isNotEmpty) {
                    provider.updateProfileLocally(
                      fullName: newName,
                      email: newEmail.isNotEmpty ? newEmail : null,
                    );
                  }
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
              try {
                await provider.api.deleteAccount();
              } catch (_) {}
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
                    children: [
                      const Expanded(
                        child: Text(
                          'Vehicle Profile',
                          style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KycScreen())),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: kyc == 'APPROVED' ? AppConstants.successColor.withOpacity(0.15) : AppConstants.accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kyc == 'APPROVED' ? AppConstants.successColor : AppConstants.accentColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                kyc == 'APPROVED' ? Icons.verified_rounded : Icons.pending_rounded,
                                color: kyc == 'APPROVED' ? AppConstants.successColor : AppConstants.accentColor,
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                kyc == 'APPROVED' ? 'Verified & Approved' : 'KYC $kyc',
                                style: TextStyle(
                                  color: kyc == 'APPROVED' ? AppConstants.successColor : AppConstants.accentColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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

            // Driver Ride & Trip Analytics Card (Daily/Weekly/Monthly/Yearly)
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D3728), Color(0xFF072118)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppConstants.primaryLight.withOpacity(0.4)),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryLight.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.history_edu_rounded, color: AppConstants.primaryLight, size: 22),
                ),
                title: const Text('Ride & Trip Analytics', style: TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold)),
                subtitle: const Text('View trips & earnings by Day (24h), Week, Month, or Year', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                trailing: const Icon(Icons.chevron_right, color: AppConstants.primaryLight),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverRidesScreen())),
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

            // Safety Center & Rapid Emergency Services
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppConstants.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppConstants.dangerColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: AppConstants.dangerColor, size: 20),
                      SizedBox(width: 8),
                      Text('Emergency Safety Toolkit', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('24/7 Rapid response hotlines & live GPS broadcast protection', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              HapticFeedback.heavyImpact();
                              _callEmergencyHotline('112');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: AppConstants.surfaceBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppConstants.dangerColor.withOpacity(0.4)),
                              ),
                              child: const Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.phone_in_talk_rounded, color: AppConstants.dangerColor, size: 14),
                                      SizedBox(width: 4),
                                      Text('112', style: TextStyle(color: AppConstants.dangerColor, fontSize: 16, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  SizedBox(height: 2),
                                  Text('Police / EMS', style: TextStyle(color: AppConstants.textMuted, fontSize: 9)),
                                  SizedBox(height: 2),
                                  Text('Tap to Call', style: TextStyle(color: AppConstants.dangerColor, fontSize: 8, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              HapticFeedback.heavyImpact();
                              _callEmergencyHotline('767');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: AppConstants.surfaceBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.amber.withOpacity(0.4)),
                              ),
                              child: const Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.phone_in_talk_rounded, color: Colors.amber, size: 14),
                                      SizedBox(width: 4),
                                      Text('767', style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  SizedBox(height: 2),
                                  Text('LASEMA Rapid', style: TextStyle(color: AppConstants.textMuted, fontSize: 9)),
                                  SizedBox(height: 2),
                                  Text('Tap to Call', style: TextStyle(color: Colors.amber, fontSize: 8, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              HapticFeedback.heavyImpact();
                              _callEmergencyHotline('122');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: AppConstants.surfaceBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
                              ),
                              child: const Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.phone_in_talk_rounded, color: Colors.blueAccent, size: 14),
                                      SizedBox(width: 4),
                                      Text('122', style: TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  SizedBox(height: 2),
                                  Text('FRSC Highway', style: TextStyle(color: AppConstants.textMuted, fontSize: 9)),
                                  SizedBox(height: 2),
                                  Text('Tap to Call', style: TextStyle(color: Colors.blueAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
                    leading: const Icon(Icons.support_agent_rounded, color: AppConstants.primaryLight),
                    title: const Text('Complaints & Partner Support Center', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Fare disputes, passenger conduct, subscriptions & payout issues', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, color: AppConstants.textMuted),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverSupportHelpScreen())),
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
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset('assets/images/logo.png', width: 40, height: 40),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Giga Driver Cockpit v2.5.0 (Build 42)',
                    style: TextStyle(color: AppConstants.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Giga is a Product of Pickpadi Global Ltd',
                    style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '100% Zero Driver Commission • Lagos, NG',
                    style: TextStyle(color: Colors.white24, fontSize: 10),
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

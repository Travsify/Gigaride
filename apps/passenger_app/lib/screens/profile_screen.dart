import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../providers/passenger_provider.dart';
import 'phone_auth_screen.dart';
import 'support_help_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onOfflineBookingPressed;
  const ProfileScreen({super.key, required this.onOfflineBookingPressed});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _homeAddress = '';
  String _workAddress = '';

  @override
  void initState() {
    super.initState();
    _loadSavedPlaces();
  }

  Future<void> _loadSavedPlaces() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _homeAddress = prefs.getString('saved_home_address') ?? '';
        _workAddress = prefs.getString('saved_work_address') ?? '';
      });
    }
  }

  Future<void> _savePlace(String key, String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, address);
    _loadSavedPlaces();
  }

  void _showEditPlaceDialog(String label, String prefKey, String currentVal) {
    final ctrl = TextEditingController(text: currentVal);
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
            Text('Set $label Location', style: const TextStyle(color: AppConstants.textLight, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Save this location for one-tap destination selection on your home screen.', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
              decoration: _inputDeco('$label Address (e.g. 15 Admiralty Way, Lekki)', label == 'Home' ? Icons.home_rounded : Icons.work_rounded),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () {
                  final text = ctrl.text.trim();
                  if (text.isNotEmpty) {
                    _savePlace(prefKey, text);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✓ $label location saved!'), backgroundColor: AppConstants.successColor));
                  }
                },
                child: const Text('Save Location', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
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
                '1. Asymmetric Phone Number Masking & Real-Time VoIP',
                'Your personal mobile number is never disclosed or transmitted to drivers. All pre-trip communications, calls, and chat messages utilize end-to-end encrypted virtual proxy relays and cryptographic identifiers. Drivers never receive or store your cellular phone number.',
              ),
              _buildPolicySection(
                '2. Lawful Basis for Processing (NDPA 2023 § 25)',
                'Pickpadi Global Ltd processes personal data under the Nigeria Data Protection Act 2023 on the following lawful bases: (a) Performance of a contract (facilitating ride dispatch and payment settlement); (b) Compliance with legal obligations under Nigerian transport, tax, and anti-money laundering regulations; (c) Legitimate safety interests (fraud detection, passenger verification, and SOS telemetry); and (d) User consent.',
              ),
              _buildPolicySection(
                '3. Location Telemetry & Background Tracking Disclosure',
                'Precise GPS coordinates are collected while the app is active in the foreground and temporarily in the background during active trips. Background location telemetry is strictly utilized to compute route progress, verify arrival at pickup/dropoff points, calculate exact mileage, and power live encrypted Emergency SOS streaming.',
              ),
              _buildPolicySection(
                '4. Bank-Grade Financial Security & PCI-DSS Standards',
                'Dedicated NUBAN virtual bank accounts are provisioned via CBN-licensed commercial banking partners for direct bank transfers. Debit card tokenization and dynamic payment checkouts are powered by PCI-DSS Level 1 certified gateways. Giga never captures, processes, or stores raw payment card PANs, expiration dates, or CVV codes on platform servers.',
              ),
              _buildPolicySection(
                '5. Statutory Data Retention Schedule',
                'Financial transaction records, invoices, and payment receipts are retained for six (6) years in compliance with Central Bank of Nigeria (CBN) regulations and Nigerian tax statutes. GPS location logs and route telemetry are retained for twelve (12) months for safety auditing, route optimization, and dispute resolution, after which they are permanently anonymized or purged.',
              ),
              _buildPolicySection(
                '6. Law Enforcement Cooperation & Emergency Disclosures',
                'In strict accordance with Nigerian law, Pickpadi Global Ltd reserves the right to disclose relevant trip records, user identity, or GPS telemetry to lawful security agencies (Nigeria Police Force, FRSC, EFCC) pursuant to a valid court order, warrant, or in situations of imminent physical peril via SOS dispatch (112).',
              ),
              _buildPolicySection(
                '7. Cross-Border Data Processing & Encryption',
                'Data is encrypted in transit via TLS 1.3 and at rest via AES-256. Cloud hosting infrastructure complies with international data security standards and NDPA 2023 Section 41–43 cross-border adequacy regulations.',
              ),
              _buildPolicySection(
                '8. Data Subject Rights & Account Deletion (§ 34 NDPA)',
                'Under Section 34 of the NDPA 2023, riders retain the legal right to inspect their personal profile, rectify inaccurate records, request data portability, or permanently request complete erasure of their account, payment tokens, and trip history via the in-app Delete Account utility.',
              ),
              _buildPolicySection(
                '9. Data Protection Officer (DPO) Contact',
                'To exercise your statutory data privacy rights or submit inquiries, contact our Data Protection Officer at dpo@gigaride.ng or privacy@gigaride.ng. Corporate Office: Plot 12B Admiralty Way, Lekki Phase 1, Lagos, Nigeria.',
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
                  const Text('Terms of Service & Rider Agreement', style: TextStyle(color: AppConstants.textLight, fontSize: 17, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: AppConstants.textMuted), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 14),
              _buildPolicySection(
                '1. Corporate Entity & Technology Intermediary',
                'GigaRide is an intelligent digital dispatch platform owned and operated by Pickpadi Global Ltd. GigaRide is exclusively a software intermediary that connects independent licensed transport providers ("Driver Partners") with riders. Pickpadi Global Ltd is not a common carrier, public transportation operator, or employer of drivers. Contracts for carriage are entered into directly between the Rider and the independent Driver Partner.',
              ),
              _buildPolicySection(
                '2. Mutual Dynamic Fare Haggling & 0% Platform Cut',
                'Trip fares are negotiated and agreed upon directly between Rider and Driver Partner in real time via in-app bidding. Drivers retain 100% of the agreed fare with zero platform percentage deductions. Riders agree to pay the agreed fare upon reaching the final destination either via cash, direct bank transfer, or Giga Wallet.',
              ),
              _buildPolicySection(
                '3. Trip Status, Cancellation & Running Trips',
                'Riders may cancel a ride request prior to driver arrival without penalty. Once a trip is initiated and "IN TRANSIT" with the passenger onboard, the ride cannot be unilaterally cancelled by the passenger on-app. If an unexpected emergency occurs, the passenger must instruct the driver to conclude the ride at a safe, designated stopping point.',
              ),
              _buildPolicySection(
                '4. Fare Payment, Theft of Services & Criminal Default',
                'Willful refusal or intentional evasion of paying the agreed trip fare upon arrival at destination constitutes theft of services and fraud under the Nigerian Criminal Code and Penal Code. Pickpadi Global Ltd and Driver Partners reserve the right to report defaulters to the Nigeria Police Force, blacklist device terminals, report defaults to credit rating bureaus, and initiate automated recovery via linked cards or Wallet balances.',
              ),
              _buildPolicySection(
                '5. Vehicle Soiling, Cleanliness & Detailing Fee',
                'Riders are required to maintain vehicle cleanliness. If a passenger soils, spills liquids or food, vomits, or damages vehicle upholstery, interior fittings, or windows, a mandatory cleaning and detailing fee of between ₦10,000 and ₦30,000 (or the verified professional detailing invoice) shall be assessed and immediately debited from the rider\'s Wallet or linked debit card payable to the Driver Partner.',
              ),
              _buildPolicySection(
                '6. Third-Party Bookings ("Booking for a Friend") & Minors',
                'When creating a ride booking for a friend, associate, or family member ("Guest Rider"), the registered account holder warrants full legal authority to bind the Guest Rider. The account holder remains strictly, jointly, and severally liable for any misconduct, property damage, soiling fee, or fare default caused by the Guest Rider. Unaccompanied minors under 18 years of age are not permitted to travel without adult accompaniment or written guardian authorization.',
              ),
              _buildPolicySection(
                '7. Zero Tolerance for Harassment, Weapons & Assault',
                'Pickpadi Global Ltd enforces a strict zero-tolerance policy regarding physical violence, verbal abuse, sexual harassment, discriminatory slurs, or brandishing of weapons towards Driver Partners. Violations will result in immediate permanent terminal blacklisting, forfeiture of unencumbered wallet balances pending police investigation, and referral to law enforcement authorities.',
              ),
              _buildPolicySection(
                '8. Prohibited Cargo, Contraband & Rider Indemnity',
                'Riders are strictly prohibited from transporting illicit narcotics, unlicensed firearms, explosives, hazardous chemicals, stolen merchandise, or biological hazards. Riders unconditionally indemnify Pickpadi Global Ltd and the Driver Partner against any criminal prosecution, vehicle impoundments, customs penalties, or civil liabilities arising from contraband discovered in rider baggage.',
              ),
              _buildPolicySection(
                '9. Lost & Found Property Disclaimer',
                'Pickpadi Global Ltd accepts zero liability or responsibility for personal items, electronic devices, bags, or cash forgotten in vehicles. Returning lost property is an independent arrangement between rider and driver. The Driver Partner is entitled to a reasonable courier/inconvenience fee of between ₦3,000 and ₦5,000 to deliver recovered items to the rider.',
              ),
              _buildPolicySection(
                '10. Emergency SOS & Telemetry Disclaimer',
                'The in-app Emergency SOS tool is a supplementary telemetry conduit provided to stream live coordinates to designated contacts and emergency responder dispatch (112). Pickpadi Global Ltd does not operate armed security squads and makes no warranty regarding the response times or operational capacity of public emergency services.',
              ),
              _buildPolicySection(
                '11. Intellectual Property & Anti-Defamation',
                'All trademarks, logos, brand assets, proprietary algorithms, and software interfaces of Giga and Pickpadi Global Ltd are protected under Nigerian and international copyright and trademark laws. Users are strictly prohibited from reverse engineering, scraping, or engaging in malicious, coordinated public defamation campaigns against the platform.',
              ),
              _buildPolicySection(
                '12. Limitation of Liability & Damage Cap',
                'To the maximum extent permitted under Nigerian law, Pickpadi Global Ltd, its directors, officers, and affiliates shall not be liable for any indirect, incidental, special, exemplary, punitive, or consequential damages, including personal injury, property loss, or trip delays resulting from third-party driver partners. Total platform liability for any verified dispute shall not exceed the specific fare paid for that individual trip.',
              ),
              _buildPolicySection(
                '13. Governing Law, Class Action Waiver & Binding Arbitration',
                'This Agreement is governed by the laws of the Federal Republic of Nigeria. All disputes shall be resolved on an individual basis; class, collective, or representative actions are expressly waived. Any dispute arising from or related to platform usage that cannot be settled amicably within thirty (30) days shall be submitted to final and binding arbitration in Lagos State under the Nigerian Arbitration and Mediation Act 2023.',
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
          'In compliance with data protection laws, deleting your account will permanently scrub your profile, trip receipts, and wallet. This action is irreversible.',
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
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.amber.withOpacity(0.4), width: 1),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                  SizedBox(width: 4),
                                  Text('4.95 Rider Rating', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppConstants.successColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified_rounded, color: AppConstants.successColor, size: 12),
                                  SizedBox(width: 3),
                                  Text('Verified Rider', style: TextStyle(color: AppConstants.successColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
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

            // Saved Places (Home & Work)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppConstants.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Saved Places', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Quick destinations for faster pickup & drop-off booking', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                  const SizedBox(height: 12),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.15), shape: BoxShape.circle),
                      child: const Icon(Icons.home_rounded, color: Colors.blueAccent, size: 20),
                    ),
                    title: const Text('Home', style: TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(_homeAddress.isNotEmpty ? _homeAddress : 'Set home location', style: TextStyle(color: _homeAddress.isNotEmpty ? AppConstants.textMuted : AppConstants.primaryLight, fontSize: 11)),
                    trailing: Icon(_homeAddress.isNotEmpty ? Icons.edit_outlined : Icons.add_circle_outline, color: AppConstants.textMuted, size: 18),
                    onTap: () => _showEditPlaceDialog('Home', 'saved_home_address', _homeAddress),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.amberAccent.withOpacity(0.15), shape: BoxShape.circle),
                      child: const Icon(Icons.work_rounded, color: Colors.amberAccent, size: 20),
                    ),
                    title: const Text('Work', style: TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(_workAddress.isNotEmpty ? _workAddress : 'Set work location', style: TextStyle(color: _workAddress.isNotEmpty ? AppConstants.textMuted : AppConstants.primaryLight, fontSize: 11)),
                    trailing: Icon(_workAddress.isNotEmpty ? Icons.edit_outlined : Icons.add_circle_outline, color: AppConstants.textMuted, size: 18),
                    onTap: () => _showEditPlaceDialog('Work', 'saved_work_address', _workAddress),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Ride & Cabin Comfort Preferences', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppConstants.primaryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                        child: const Text('Auto-Applied', style: TextStyle(color: AppConstants.primaryLight, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.volume_off_rounded, color: Colors.purpleAccent, size: 20),
                    title: const Text('Quiet Ride (Silent Cabin)', style: TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Minimal driver chat & peaceful travel', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    value: provider.preferQuiet,
                    activeColor: Colors.purpleAccent,
                    onChanged: (val) => provider.setPreference('preferQuiet', val),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.ac_unit_rounded, color: Colors.cyanAccent, size: 20),
                    title: const Text('Always AC On', style: TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Cool cabin air conditioning on every trip', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    value: provider.alwaysAcOn,
                    activeColor: Colors.cyanAccent,
                    onChanged: (val) => provider.setPreference('alwaysAcOn', val),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.luggage_rounded, color: Colors.amberAccent, size: 20),
                    title: const Text('Luggage Assistance', style: TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Trunk space and help with heavy bags', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    value: provider.luggageAssistance,
                    activeColor: Colors.amberAccent,
                    onChanged: (val) => provider.setPreference('luggageAssistance', val),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.music_off_rounded, color: Colors.indigoAccent, size: 20),
                    title: const Text('No Music / Radio Off', style: TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Keep sound system and radio powered off', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    value: provider.noMusic,
                    activeColor: Colors.indigoAccent,
                    onChanged: (val) => provider.setPreference('noMusic', val),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.pets_rounded, color: Colors.greenAccent, size: 20),
                    title: const Text('Pet-Friendly Vehicle', style: TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Traveling with a domestic pet or guide animal', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    value: provider.petFriendly,
                    activeColor: Colors.greenAccent,
                    onChanged: (val) => provider.setPreference('petFriendly', val),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.accessible_forward_rounded, color: AppConstants.primaryLight, size: 20),
                    title: const Text('Accessibility Support', style: TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Space for folding wheelchair or mobility aid', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    value: provider.accessibilitySupport,
                    activeColor: AppConstants.primaryLight,
                    onChanged: (val) => provider.setPreference('accessibilitySupport', val),
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

            // Safety Center & Rapid Emergency Services
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppConstants.cardBg,
                borderRadius: BorderRadius.circular(16),
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
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(color: AppConstants.surfaceBg, borderRadius: BorderRadius.circular(10)),
                          child: const Column(
                            children: [
                              Text('112', style: TextStyle(color: AppConstants.dangerColor, fontSize: 16, fontWeight: FontWeight.bold)),
                              SizedBox(height: 2),
                              Text('National Police/EMS', style: TextStyle(color: AppConstants.textMuted, fontSize: 9)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(color: AppConstants.surfaceBg, borderRadius: BorderRadius.circular(10)),
                          child: const Column(
                            children: [
                              Text('767', style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                              SizedBox(height: 2),
                              Text('LASEMA Emergency', style: TextStyle(color: AppConstants.textMuted, fontSize: 9)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          decoration: BoxDecoration(color: AppConstants.surfaceBg, borderRadius: BorderRadius.circular(10)),
                          child: const Column(
                            children: [
                              Text('122', style: TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                              SizedBox(height: 2),
                              Text('FRSC Highway', style: TextStyle(color: AppConstants.textMuted, fontSize: 9)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Legal, Privacy, Support & Settings List
            Container(
              decoration: BoxDecoration(color: AppConstants.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.support_agent_rounded, color: AppConstants.primaryLight),
                    title: const Text('Complaints & Support Center', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Trip disputes, lost items, safety & fare refunds', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, color: AppConstants.textMuted),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportHelpScreen())),
                  ),
                  const Divider(color: Colors.white10, height: 1),
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
            const SizedBox(height: 24),

            // App Version & Platform Build Details
            Center(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset('assets/images/logo.png', width: 40, height: 40),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Giga Ride v2.5.0 (Build 42)',
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
}

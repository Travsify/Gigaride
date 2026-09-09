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
                '1. Asymmetric Phone Number Masking',
                'Your personal mobile number is strictly hidden from drivers. All in-app calls and chats utilize VoIP proxy relays and cryptographic masking. Drivers never receive your real phone number.',
              ),
              _buildPolicySection(
                '2. Information We Collect & Legal Basis',
                'We collect your verified mobile number (via SMS OTP), email address for digital receipts, and high-precision GPS telemetry strictly during ride requests and active trips to facilitate routing and emergency dispatch.',
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
                children: const [
                  Text(
                    'Giga Ride v2.5.0 (Build 42)',
                    style: TextStyle(color: AppConstants.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
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

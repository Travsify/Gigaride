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
  bool _isCorporate = false;

  void _showAddContactModal(BuildContext context, PassengerProvider provider) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
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
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_add_alt_1_rounded, color: AppConstants.primaryLight, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Add Trusted Emergency Contact',
                  style: TextStyle(color: AppConstants.textLight, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'This contact will automatically receive your live GPS link whenever you tap SOS or share ride status.',
              style: TextStyle(color: AppConstants.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Full Name (e.g. Sister, Dad, Spouse)',
                hintStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 13),
                filled: true,
                fillColor: AppConstants.surfaceBg,
                prefixIcon: const Icon(Icons.person_outline_rounded, color: AppConstants.textMuted, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Phone Number (e.g. 08012345678)',
                hintStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 13),
                filled: true,
                fillColor: AppConstants.surfaceBg,
                prefixIcon: const Icon(Icons.phone_outlined, color: AppConstants.textMuted, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
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
                  final name = nameCtrl.text.trim();
                  final phone = phoneCtrl.text.trim();
                  if (name.isEmpty || phone.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter contact name and phone number')),
                    );
                    return;
                  }
                  provider.addEmergencyContact(name, phone);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added $name as trusted emergency contact'),
                      backgroundColor: AppConstants.successColor,
                    ),
                  );
                },
                child: const Text('Save Trusted Contact', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
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
        content: const Text(
          'Are you sure you want to sign out of your Giga Passenger account on this device?',
          style: TextStyle(color: AppConstants.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppConstants.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.dangerColor),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
                  (r) => false,
                );
              }
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSafetyModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppConstants.dangerColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_rounded, color: AppConstants.dangerColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Safety & Emergency Toolkit', style: TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('NDPR-compliant rider protection suite', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSafetyFeature(
                icon: Icons.lock_outline_rounded,
                title: 'Asymmetric Number Masking',
                desc: 'Your personal phone number is never exposed or logged on the driver phone.',
              ),
              const SizedBox(height: 14),
              _buildSafetyFeature(
                icon: Icons.cell_tower_rounded,
                title: 'Lagos State Emergency Dispatch Integration',
                desc: '1-tap SOS streams live GPS and vehicle license plates to security operations.',
              ),
              const SizedBox(height: 14),
              _buildSafetyFeature(
                icon: Icons.verified_rounded,
                title: '100% Commercial Driver Vetting',
                desc: 'Every Giga driver passes physical hub vehicle inspections and LASRRA/NIN verification.',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got It', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildSafetyFeature({required IconData icon, required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppConstants.primaryLight, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(color: AppConstants.textMuted, fontSize: 11, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PassengerProvider>();
    final user = provider.user;
    final name = user?['fullName'] ?? user?['full_name'] ?? 'Giga Passenger';
    final phone = user?['phone'] ?? '+234 800 000 GIGA';
    final email = user?['email'] ?? 'passenger@gigaride.ng';

    final emergencyContacts = provider.emergencyContacts;

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('My Account', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Profile Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppConstants.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppConstants.primaryLight, AppConstants.primaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppConstants.primaryColor.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'P',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(color: AppConstants.textLight, fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(phone, style: const TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                        const SizedBox(height: 1),
                        Text(email, style: const TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppConstants.successColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_user_rounded, color: AppConstants.successColor, size: 12),
                              SizedBox(width: 4),
                              Text('NDPR Shield Active', style: TextStyle(color: AppConstants.successColor, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Profile Mode Toggle (Personal vs Corporate)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppConstants.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isCorporate ? Colors.cyan.withOpacity(0.2) : AppConstants.successColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isCorporate ? Icons.corporate_fare_rounded : Icons.person_rounded,
                      color: _isCorporate ? Colors.cyanAccent : AppConstants.successColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isCorporate ? 'Business Profile' : 'Personal Profile',
                          style: const TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _isCorporate ? 'Department expense codes & corporate invoice' : 'Standard 0% commission personal rides',
                          style: const TextStyle(color: AppConstants.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isCorporate,
                    activeColor: Colors.cyanAccent,
                    onChanged: (val) {
                      setState(() => _isCorporate = val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(val ? 'Business Profile Active' : 'Personal Profile Active'),
                          backgroundColor: val ? AppConstants.primaryColor : AppConstants.successColor,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Ride Comfort Preferences Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppConstants.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppConstants.primaryLight.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.tune_rounded, color: AppConstants.primaryLight, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ride Comfort Preferences', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.bold)),
                          Text('Drivers automatically see these preferences on dispatch', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.ac_unit_rounded, color: Colors.cyanAccent, size: 20),
                    title: const Text('Always AC On', style: TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Request air conditioning active upon entry', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
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
                    subtitle: const Text('Driver maintains quiet cabin for calls or focus', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    value: provider.preferQuiet,
                    activeColor: Colors.purpleAccent,
                    onChanged: (val) => provider.setPreference('preferQuiet', val),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.luggage_rounded, color: Colors.amberAccent, size: 20),
                    title: const Text('Luggage Assistance', style: TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Request trunk space and loading support', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    value: provider.luggageAssistance,
                    activeColor: Colors.amberAccent,
                    onChanged: (val) => provider.setPreference('luggageAssistance', val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Trusted Emergency Contacts Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppConstants.cardBg,
                borderRadius: BorderRadius.circular(16),
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
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppConstants.dangerColor.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.contact_emergency_rounded, color: AppConstants.dangerColor, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Trusted SOS Contacts', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.bold)),
                              Text('${emergencyContacts.length}/3 Contacts Saved', style: const TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                      if (emergencyContacts.length < 3)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            backgroundColor: AppConstants.primaryColor.withOpacity(0.15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _showAddContactModal(context, provider),
                          icon: const Icon(Icons.add_rounded, size: 16, color: AppConstants.primaryLight),
                          label: const Text('Add', style: TextStyle(color: AppConstants.primaryLight, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (emergencyContacts.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppConstants.surfaceBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: AppConstants.textMuted, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Add up to 3 family or friends who will receive immediate SMS/WhatsApp SOS alerts with your live tracking location in an emergency.',
                              style: TextStyle(color: AppConstants.textMuted, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...emergencyContacts.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final contact = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppConstants.surfaceBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.phone_in_talk_rounded, color: AppConstants.successColor, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      contact['name'] ?? 'Contact',
                                      style: const TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      contact['phone'] ?? '',
                                      style: const TextStyle(color: AppConstants.textMuted, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppConstants.dangerColor, size: 18),
                                onPressed: () {
                                  provider.removeEmergencyContact(idx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Contact removed')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Settings Options List
            Container(
              decoration: BoxDecoration(
                color: AppConstants.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.offline_bolt_rounded, color: Colors.amberAccent),
                    title: const Text('Low Data & Offline Booking', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Book via WhatsApp AI dispatcher or SMS', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, color: AppConstants.textMuted),
                    onTap: widget.onOfflineBookingPressed,
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  ListTile(
                    leading: const Icon(Icons.shield_outlined, color: AppConstants.primaryLight),
                    title: const Text('Safety & Emergency Toolkit', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('256-bit encryption, SOS & vehicle vetting', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, color: AppConstants.textMuted),
                    onTap: () => _showSafetyModal(context),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded, color: AppConstants.textMuted),
                    title: const Text('About Giga Ride Nigeria', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Decacorn Zero-Commission Mobility v2.0', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, color: AppConstants.textMuted),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Giga Ride',
                        applicationVersion: '2.0.0 (Decacorn Release)',
                        applicationLegalese: '© 2026 Giga Ride Nigeria Ltd. NDPR Regulated.',
                      );
                    },
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: AppConstants.dangerColor),
                    title: const Text('Sign Out', style: TextStyle(color: AppConstants.dangerColor, fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Log out of this device', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
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

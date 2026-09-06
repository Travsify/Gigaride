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

  void _showLogoutDialog(BuildContext context, DriverProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out?', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to sign out of your Giga Driver terminal on this device?',
          style: TextStyle(color: AppConstants.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppConstants.textMuted))),
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriverProvider>();
    final user = provider.user;
    final profile = provider.driverProfile;

    final name = user?['fullName'] ?? user?['full_name'] ?? 'Giga Driver';
    final phone = user?['phoneNumber'] ?? user?['phone_number'] ?? '+234 800 GIGA';
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
              decoration: BoxDecoration(
                color: AppConstants.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppConstants.primaryLight, AppConstants.primaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: AppConstants.primaryColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'D',
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
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: kyc == 'APPROVED' ? AppConstants.successColor.withOpacity(0.15) : AppConstants.accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                kyc == 'APPROVED' ? Icons.verified_rounded : Icons.pending_rounded,
                                color: kyc == 'APPROVED' ? AppConstants.successColor : AppConstants.accentColor,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                kyc == 'APPROVED' ? 'Verified Commercial Driver' : 'KYC Pending',
                                style: TextStyle(
                                  color: kyc == 'APPROVED' ? AppConstants.successColor : AppConstants.accentColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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

            // Registered Vehicle Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppConstants.cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.directions_car_rounded, color: AppConstants.primaryLight, size: 20),
                          SizedBox(width: 10),
                          Text('Commercial Vehicle', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppConstants.surfaceBg, borderRadius: BorderRadius.circular(6)),
                        child: Text(plate, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('$year $make $model', style: const TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Commercial Lagos State Hub Vehicle Vetting Active', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Driver Controls (Air Conditioning Toggle)
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
                    decoration: BoxDecoration(color: Colors.cyan.withOpacity(0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.ac_unit_rounded, color: Colors.cyanAccent, size: 20),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Icy Air Conditioning Active', style: TextStyle(color: AppConstants.textLight, fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('Qualifies you for Giga Comfort 1.25x premium fare bids.', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _acAvailable,
                    activeColor: Colors.cyanAccent,
                    onChanged: (val) {
                      setState(() => _acAvailable = val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(val ? 'Comfort AC Enabled (1.25x Multiplier)' : 'Standard AC Mode')),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Options List
            Container(
              decoration: BoxDecoration(
                color: AppConstants.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.badge_outlined, color: AppConstants.primaryLight),
                    title: const Text('Identity & KYC Documents', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('NIN & FRSC Driver License verification', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, color: AppConstants.textMuted),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const KycScreen()));
                    },
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded, color: AppConstants.textMuted),
                    title: const Text('About Giga Partner Terminal', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('0% Commission Driver Release v2.0', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, color: AppConstants.textMuted),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Giga Driver Partner',
                        applicationVersion: '2.0.0 (Decacorn Release)',
                        applicationLegalese: '© 2026 Giga Ride Nigeria Ltd. FRSC & LASRRA Regulated.',
                      );
                    },
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: AppConstants.dangerColor),
                    title: const Text('Sign Out', style: TextStyle(color: AppConstants.dangerColor, fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Log out of this terminal device', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
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

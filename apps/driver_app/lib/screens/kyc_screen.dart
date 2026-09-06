import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/driver_provider.dart';
import 'driver_shell.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _ninCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController(text: '1992-05-15');
  DateTime _selectedDob = DateTime(1992, 5, 15);

  Future<void> _selectDateOfBirth(BuildContext context) async {
    final now = DateTime.now();
    final maxDate = DateTime(now.year - 18, now.month, now.day);
    final minDate = DateTime(1940, 1, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob,
      firstDate: minDate,
      lastDate: maxDate,
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'SELECT YOUR DATE OF BIRTH',
      cancelText: 'CANCEL',
      confirmText: 'CONFIRM DATE',
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppConstants.primaryColor,
              onPrimary: Colors.white,
              surface: AppConstants.cardBg,
              onSurface: AppConstants.textLight,
            ),
            dialogBackgroundColor: AppConstants.cardBg,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }


  @override
  void initState() {
    super.initState();
    final provider = context.read<DriverProvider>();
    final fullName = provider.user?['fullName'] ?? provider.user?['full_name'] ?? '';
    if (fullName.isNotEmpty) {
      final parts = fullName.split(' ');
      _firstNameCtrl.text = parts.isNotEmpty ? parts[0] : '';
      _lastNameCtrl.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }
  }

  @override
  void dispose() {
    _ninCtrl.dispose();
    _licenseCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  void _submitNin() async {
    final nin = _ninCtrl.text.trim();
    final first = _firstNameCtrl.text.trim();
    final last = _lastNameCtrl.text.trim();
    final dob = _dobCtrl.text.trim();

    if (nin.length != 11) {
      _showError('National Identity Number must be exactly 11 digits');
      return;
    }
    if (first.isEmpty || last.isEmpty) {
      _showError('Please enter your First Name and Last Name');
      return;
    }

    final provider = context.read<DriverProvider>();
    try {
      await provider.verifyNIN(nin, first, last, dob: dob.isNotEmpty ? dob : null);
      if (!mounted) return;
      _showSuccess('NIN Verified successfully via Prembly NIMC portal!');
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _submitLicense() async {
    final license = _licenseCtrl.text.trim().toUpperCase();
    final first = _firstNameCtrl.text.trim();
    final last = _lastNameCtrl.text.trim();
    final dob = _dobCtrl.text.trim();

    if (license.length < 8) {
      _showError('Please enter a valid FRSC driver license number');
      return;
    }
    if (first.isEmpty || last.isEmpty) {
      _showError('Please enter your First Name and Last Name');
      return;
    }

    final provider = context.read<DriverProvider>();
    try {
      await provider.verifyLicense(license, first, last, dob: dob.isNotEmpty ? dob : null);
      if (!mounted) return;
      _showSuccess('Driver License verified successfully via Prembly FRSC gateway!');
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppConstants.dangerColor),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppConstants.successColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DriverProvider>();
    final kycStatus = provider.driverProfile?['kyc_status'] ?? 'PENDING';
    final isApproved = kycStatus == 'APPROVED';
    final isLoading = provider.isLoading;
    final vba = provider.virtualAccount;

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Identity & Driver KYC', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppConstants.primaryLight),
            onPressed: () async {
              await provider.checkAuth();
              if (context.mounted) _showSuccess('KYC verification status refreshed');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppConstants.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isApproved ? AppConstants.successColor.withOpacity(0.4) : AppConstants.accentColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: (isApproved ? AppConstants.successColor : AppConstants.accentColor).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isApproved ? Icons.verified_rounded : Icons.pending_actions_rounded,
                      color: isApproved ? AppConstants.successColor : AppConstants.accentColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isApproved ? 'Account Approved & Active' : 'Verification Required',
                          style: TextStyle(
                            color: isApproved ? AppConstants.successColor : AppConstants.textLight,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isApproved
                            ? 'Your profile passed Prembly identity checks. Korapay virtual account is provisioned.'
                            : 'Verify your NIN or FRSC License to activate radar dispatch and unlock your dedicated NUBAN.',
                          style: const TextStyle(color: AppConstants.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (isApproved && vba != null) ...[
              const SizedBox(height: 16),
              // Dedicated Virtual Account Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppConstants.primaryColor.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          vba['bank_name'] ?? 'Wema Bank (Giga Dedicated)',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(6)),
                          child: const Text('NIP DVA Active', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Dedicated Driver NUBAN Number', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      vba['account_number'] ?? '9988776655',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      vba['account_name'] ?? 'Driver Account',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.successColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const DriverShell()),
                    );
                  },
                  icon: const Icon(Icons.radar_rounded, color: Colors.white),
                  label: const Text('Open Radar & Start Earning', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],

            if (!isApproved) ...[
              const SizedBox(height: 24),
              const Text('Identity Holder Information', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firstNameCtrl,
                      style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                      decoration: _inputDeco(hint: 'First Name'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _lastNameCtrl,
                      style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                      decoration: _inputDeco(hint: 'Last Name / Surname'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _selectDateOfBirth(context),
                child: AbsorbPointer(
                  child: TextField(
                    controller: _dobCtrl,
                    readOnly: true,
                    style: const TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.bold),
                    decoration: _inputDeco(
                      hint: 'Date of Birth (Click to select from calendar)',
                      icon: Icons.calendar_month_rounded,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Option 1: NIN Verification
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
                    const Row(
                      children: [
                        Icon(Icons.fingerprint_rounded, color: AppConstants.primaryLight, size: 20),
                        SizedBox(width: 10),
                        Text('1. National Identification Number (NIN)', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text('Instant verification with National Identity Management Commission (NIMC) via Prembly.', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _ninCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 11,
                      style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                      decoration: _inputDeco(hint: '11-digit NIN', icon: Icons.badge_outlined),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: isLoading ? null : _submitNin,
                        child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Verify NIN With NIMC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Option 2: FRSC License Verification
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
                    const Row(
                      children: [
                        Icon(Icons.directions_car_rounded, color: AppConstants.accentColor, size: 20),
                        SizedBox(width: 10),
                        Text('2. FRSC Commercial Driver\'s License', style: TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text('Federal Road Safety Corps commercial license check via Prembly portal.', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _licenseCtrl,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                      decoration: _inputDeco(hint: 'e.g. AAA00000AA00', icon: Icons.credit_card_outlined),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppConstants.accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: isLoading ? null : _submitLicense,
                        child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Verify FRSC License', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco({required String hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 13),
      prefixIcon: icon != null ? Icon(icon, color: AppConstants.textMuted, size: 18) : null,
      filled: true,
      fillColor: AppConstants.surfaceBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }
}

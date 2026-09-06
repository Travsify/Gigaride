import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/driver_provider.dart';
import 'kyc_screen.dart';
import 'driver_shell.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  bool _isSignUp = false;
  bool _otpSent = false;
  bool _obscurePassword = true;

  // Controllers
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // Driver & Vehicle Sign-Up Controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _vehicleMakeCtrl = TextEditingController();
  final _vehicleModelCtrl = TextEditingController();
  final _vehicleYearCtrl = TextEditingController(text: '2018');
  final _licensePlateCtrl = TextEditingController();
  final _vehicleColorCtrl = TextEditingController(text: 'Silver');
  final _ninCtrl = TextEditingController();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _vehicleMakeCtrl.dispose();
    _vehicleModelCtrl.dispose();
    _vehicleYearCtrl.dispose();
    _licensePlateCtrl.dispose();
    _vehicleColorCtrl.dispose();
    _ninCtrl.dispose();
    super.dispose();
  }

  String _formatPhone(String raw) {
    String clean = raw.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (clean.startsWith('+234')) return clean;
    if (clean.startsWith('234')) return '+$clean';
    if (clean.startsWith('0')) return '+234${clean.substring(1)}';
    return '+234$clean';
  }

  void _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      _showError('Please enter your phone number');
      return;
    }
    final formatted = _formatPhone(phone);
    final provider = context.read<DriverProvider>();

    try {
      setState(() => provider.isLoading = true);
      await provider.api.sendPhoneOtp(formatted);
      setState(() {
        provider.isLoading = false;
        _otpSent = true;
      });
      _showSuccess('6-digit OTP sent via Twilio SMS to $formatted');
    } catch (e) {
      setState(() => provider.isLoading = false);
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _verifyOtpAndLogin() async {
    final phone = _formatPhone(_phoneCtrl.text.trim());
    final otp = _otpCtrl.text.trim();
    if (otp.length < 6) {
      _showError('Please enter the complete 6-digit OTP code');
      return;
    }

    final provider = context.read<DriverProvider>();
    try {
      await provider.loginWithPhoneOtp(phone, otp);
      if (!mounted) return;
      _navigateAfterAuth(provider);
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _submitPasswordLogin() async {
    final phone = _formatPhone(_phoneCtrl.text.trim());
    final pass = _passwordCtrl.text;
    if (phone.isEmpty || pass.isEmpty) {
      _showError('Please enter your phone number and password');
      return;
    }
    final provider = context.read<DriverProvider>();
    try {
      await provider.login(phone, pass);
      if (!mounted) return;
      _navigateAfterAuth(provider);
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _submitRegistration() async {
    final name = _nameCtrl.text.trim();
    final phone = _formatPhone(_phoneCtrl.text.trim());
    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text;
    final make = _vehicleMakeCtrl.text.trim();
    final model = _vehicleModelCtrl.text.trim();
    final year = int.tryParse(_vehicleYearCtrl.text.trim()) ?? 2018;
    final plate = _licensePlateCtrl.text.trim().toUpperCase();
    final color = _vehicleColorCtrl.text.trim();
    final nin = _ninCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || pass.length < 6) {
      _showError('Please fill in your name, email, and password (min 6 chars)');
      return;
    }
    if (make.isEmpty || model.isEmpty || plate.isEmpty) {
      _showError('Please enter your vehicle make, model, and license plate');
      return;
    }

    final provider = context.read<DriverProvider>();
    try {
      await provider.register({
        'fullName': name,
        'phoneNumber': phone,
        'email': email,
        'password': pass,
        'vehicleMake': make,
        'vehicleModel': model,
        'vehicleYear': year,
        'licensePlate': plate,
        'vehicleColor': color,
        'nin': nin.isNotEmpty ? nin : null,
      });
      if (!mounted) return;
      _navigateAfterAuth(provider);
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _navigateAfterAuth(DriverProvider provider) {
    final kyc = provider.driverProfile?['kyc_status'];
    if (kyc != 'APPROVED') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const KycScreen()),
        (r) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DriverShell()),
        (r) => false,
      );
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
    final isLoading = context.watch<DriverProvider>().isLoading;

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Brand
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppConstants.primaryLight.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppConstants.primaryLight.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.local_taxi_rounded, color: AppConstants.primaryLight, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GIGA DRIVER', style: TextStyle(color: AppConstants.textLight, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                      Text('Commercial Partner Portal', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Title
              Text(
                _isSignUp ? 'Partner Sign-Up' : 'Driver Sign-In',
                style: const TextStyle(color: AppConstants.textLight, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                _isSignUp
                    ? 'Register your commercial vehicle and receive 5 Free Welcome Rides.'
                    : 'Log in to access your radar and start receiving trip bids.',
                style: const TextStyle(color: AppConstants.textMuted, fontSize: 13),
              ),

              const SizedBox(height: 24),

              // Phone Number Field
              _buildLabel('Mobile Phone Number'),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                decoration: _inputDecoration(
                  hint: '08012345678',
                  prefix: const Icon(Icons.phone_outlined, color: AppConstants.textMuted, size: 20),
                ),
              ),

              if (!_isSignUp && !_otpSent) ...[
                const SizedBox(height: 16),
                _buildLabel('Password'),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                  decoration: _inputDecoration(
                    hint: '••••••••',
                    prefix: const Icon(Icons.lock_outline_rounded, color: AppConstants.textMuted, size: 20),
                    suffix: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppConstants.textMuted, size: 18),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: isLoading ? null : _submitPasswordLogin,
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : const Text('Sign In With Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: isLoading ? null : _sendOtp,
                    icon: const Icon(Icons.sms_outlined, color: AppConstants.primaryLight, size: 18),
                    label: const Text('Or Sign In via 1-Tap SMS OTP', style: TextStyle(color: AppConstants.primaryLight, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],

              if (!_isSignUp && _otpSent) ...[
                const SizedBox(height: 16),
                _buildLabel('6-Digit Verification Code (Twilio SMS)'),
                TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(color: AppConstants.successColor, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 6),
                  decoration: _inputDecoration(
                    hint: '123456',
                    prefix: const Icon(Icons.pin_outlined, color: AppConstants.textMuted, size: 20),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppConstants.successColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: isLoading ? null : _verifyOtpAndLogin,
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : const Text('Verify & Open Radar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _otpSent = false),
                    child: const Text('Use Password Instead', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                  ),
                ),
              ],

              // Sign Up Fields
              if (_isSignUp) ...[
                const SizedBox(height: 14),
                _buildLabel('Driver Full Name'),
                TextField(controller: _nameCtrl, style: const TextStyle(color: AppConstants.textLight, fontSize: 14), decoration: _inputDecoration(hint: 'e.g. Babatunde Adeyemi', prefix: const Icon(Icons.person_outline, color: AppConstants.textMuted, size: 20))),
                const SizedBox(height: 14),
                _buildLabel('Email Address'),
                TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: AppConstants.textLight, fontSize: 14), decoration: _inputDecoration(hint: 'driver@example.com', prefix: const Icon(Icons.mail_outline, color: AppConstants.textMuted, size: 20))),
                const SizedBox(height: 14),
                _buildLabel('Account Password'),
                TextField(controller: _passwordCtrl, obscureText: _obscurePassword, style: const TextStyle(color: AppConstants.textLight, fontSize: 14), decoration: _inputDecoration(hint: 'Min 6 characters', prefix: const Icon(Icons.lock_outline, color: AppConstants.textMuted, size: 20))),

                const SizedBox(height: 20),
                const Divider(color: Colors.white10),
                const SizedBox(height: 10),
                const Text('Vehicle & Identification Info', style: TextStyle(color: AppConstants.accentColor, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel('Make'), TextField(controller: _vehicleMakeCtrl, style: const TextStyle(color: AppConstants.textLight, fontSize: 14), decoration: _inputDecoration(hint: 'Toyota'))])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel('Model'), TextField(controller: _vehicleModelCtrl, style: const TextStyle(color: AppConstants.textLight, fontSize: 14), decoration: _inputDecoration(hint: 'Corolla'))])),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel('Year'), TextField(controller: _vehicleYearCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: AppConstants.textLight, fontSize: 14), decoration: _inputDecoration(hint: '2018'))])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel('Color'), TextField(controller: _vehicleColorCtrl, style: const TextStyle(color: AppConstants.textLight, fontSize: 14), decoration: _inputDecoration(hint: 'Silver'))])),
                  ],
                ),
                const SizedBox(height: 12),
                _buildLabel('License Plate Number'),
                TextField(controller: _licensePlateCtrl, textCapitalization: TextCapitalization.characters, style: const TextStyle(color: AppConstants.textLight, fontSize: 14), decoration: _inputDecoration(hint: 'EKY-492-LG', prefix: const Icon(Icons.pin, color: AppConstants.textMuted, size: 20))),
                const SizedBox(height: 12),
                _buildLabel('National Identity Number (NIN - Optional)'),
                TextField(controller: _ninCtrl, keyboardType: TextInputType.number, maxLength: 11, style: const TextStyle(color: AppConstants.textLight, fontSize: 14), decoration: _inputDecoration(hint: '11-digit NIN', prefix: const Icon(Icons.badge_outlined, color: AppConstants.textMuted, size: 20))),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: isLoading ? null : _submitRegistration,
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        : const Text('Register & Claim 5 Free Rides', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Toggle Sign In / Sign Up
              Center(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _isSignUp = !_isSignUp;
                    _otpSent = false;
                  }),
                  child: RichText(
                    text: TextSpan(
                      text: _isSignUp ? 'Already registered as a driver? ' : 'Want to drive with Giga? ',
                      style: const TextStyle(color: AppConstants.textMuted, fontSize: 13),
                      children: [
                        TextSpan(
                          text: _isSignUp ? 'Sign In' : 'Register Vehicle',
                          style: const TextStyle(color: AppConstants.primaryLight, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label, style: const TextStyle(color: AppConstants.textLight, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  InputDecoration _inputDecoration({required String hint, Widget? prefix, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 13),
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: AppConstants.cardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppConstants.primaryLight)),
    );
  }
}

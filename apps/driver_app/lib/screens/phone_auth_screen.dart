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
  bool _useOtpLogin = true; // Default to 1-Tap OTP for existing users
  bool _otpSent = false;
  bool _isPhoneVerified = false;
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
      _showSuccess('6-digit OTP dispatched via Twilio SMS to $formatted');
    } catch (e) {
      setState(() => provider.isLoading = false);
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _verifyOtpForSignUp() async {
    final phone = _formatPhone(_phoneCtrl.text.trim());
    final otp = _otpCtrl.text.trim();
    if (otp.length < 6) {
      _showError('Please enter the complete 6-digit OTP code');
      return;
    }

    final provider = context.read<DriverProvider>();
    try {
      setState(() => provider.isLoading = true);
      await provider.api.verifyPhoneOtp(phone, otp);
      setState(() {
        provider.isLoading = false;
        _isPhoneVerified = true;
      });
      _showSuccess('✓ Phone number verified! Please complete your driver profile.');
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
      final msg = e.toString().replaceAll('Exception: ', '');
      if (msg.startsWith('PHONE_UNVERIFIED:')) {
        setState(() {
          _useOtpLogin = true;
          _otpSent = true;
        });
        _showError('Phone number not verified. An SMS OTP has been sent. Please enter it to verify and log in.');
      } else {
        _showError(msg);
      }
    }
  }

  void _submitRegistration() async {
    if (!_isPhoneVerified) {
      _showError('You must verify your phone number via SMS OTP before registering.');
      return;
    }

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
      _showError('Please fill in your full name, email, and password (min 6 characters)');
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
              const SizedBox(height: 10),

              // Header Brand Row
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppConstants.primaryColor.withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.speed_rounded, color: AppConstants.primaryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GIGA RIDE', style: TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
                      Text('DRIVER PARTNER COCKPIT', style: TextStyle(color: AppConstants.primaryLight, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Sign In vs Sign Up Tabs
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppConstants.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isSignUp = false;
                          _otpSent = false;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isSignUp ? AppConstants.primaryColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text('Driver Sign In', style: TextStyle(color: !_isSignUp ? Colors.white : AppConstants.textMuted, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isSignUp = true;
                          _otpSent = false;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isSignUp ? AppConstants.primaryColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text('Register Vehicle', style: TextStyle(color: _isSignUp ? Colors.white : AppConstants.textMuted, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Text(
                _isSignUp ? 'Driver Onboarding' : 'Welcome Back, Captain',
                style: const TextStyle(color: AppConstants.textLight, fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                _isSignUp
                    ? (_isPhoneVerified ? 'Step 2 of 2: Fill vehicle and driver details' : 'Step 1 of 2: Verify your phone number with SMS OTP')
                    : 'Log in to view incoming bids and keep 100% of your earnings.',
                style: const TextStyle(color: AppConstants.textMuted, fontSize: 13),
              ),

              const SizedBox(height: 20),

              // ================= SIGN UP FLOW =================
              if (_isSignUp) ...[
                if (!_isPhoneVerified) ...[
                  // Step 1: Phone verification
                  _buildLabel('Nigerian Mobile Number (+234)'),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold),
                    decoration: _inputDecoration(
                      hint: '0801 234 5678',
                      prefix: Container(
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🇳🇬', style: TextStyle(fontSize: 16)),
                            SizedBox(width: 4),
                            Text('+234', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (!_otpSent) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        onPressed: isLoading ? null : _sendOtp,
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            : const Text('Send SMS Verification Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ] else ...[
                    _buildLabel('Enter 6-Digit SMS Code'),
                    TextField(
                      controller: _otpCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppConstants.successColor, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 8),
                      decoration: _inputDecoration(hint: '••••••', prefix: const Icon(Icons.lock_clock_outlined, color: AppConstants.textMuted)),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppConstants.successColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        onPressed: isLoading ? null : _verifyOtpForSignUp,
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            : const Text('Verify Code & Proceed to Step 2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: _sendOtp,
                        child: const Text('Resend SMS Code', style: TextStyle(color: AppConstants.accentColor, fontSize: 12)),
                      ),
                    ),
                  ],
                ] else ...[
                  // Phone Verified Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppConstants.successColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppConstants.successColor.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppConstants.successColor, size: 20),
                            const SizedBox(width: 8),
                            Text('✓ ${_formatPhone(_phoneCtrl.text.trim())}', style: const TextStyle(color: AppConstants.successColor, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => setState(() {
                            _isPhoneVerified = false;
                            _otpSent = false;
                          }),
                          child: const Text('Change', style: TextStyle(color: AppConstants.textMuted, fontSize: 12, decoration: TextDecoration.underline)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Step 2: Driver & Vehicle Info
                  _buildLabel('Driver Full Name (As on Bank Account)'),
                  TextField(controller: _nameCtrl, style: const TextStyle(color: AppConstants.textLight, fontSize: 14), decoration: _inputDecoration(hint: 'e.g. Babatunde Adeyemi', prefix: const Icon(Icons.person_outline, color: AppConstants.textMuted, size: 20))),
                  const SizedBox(height: 12),
                  _buildLabel('Email Address'),
                  TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: AppConstants.textLight, fontSize: 14), decoration: _inputDecoration(hint: 'driver@example.com', prefix: const Icon(Icons.mail_outline, color: AppConstants.textMuted, size: 20))),
                  const SizedBox(height: 12),
                  _buildLabel('Account Password'),
                  TextField(controller: _passwordCtrl, obscureText: _obscurePassword, style: const TextStyle(color: AppConstants.textLight, fontSize: 14), decoration: _inputDecoration(hint: 'Min 6 characters', prefix: const Icon(Icons.lock_outline, color: AppConstants.textMuted, size: 20))),

                  const SizedBox(height: 16),
                  const Text('Vehicle Information', style: TextStyle(color: AppConstants.accentColor, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
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
                          : const Text('Complete Registration & Claim 5 Free Rides', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ],

              // ================= SIGN IN FLOW =================
              if (!_isSignUp) ...[
                // Sign In Mode Switcher: 1-Tap OTP vs Password
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _useOtpLogin = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _useOtpLogin ? AppConstants.cardBg : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _useOtpLogin ? AppConstants.primaryLight : Colors.transparent),
                          ),
                          alignment: Alignment.center,
                          child: Text('1-Tap Phone OTP', style: TextStyle(color: _useOtpLogin ? AppConstants.primaryLight : AppConstants.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _useOtpLogin = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !_useOtpLogin ? AppConstants.cardBg : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: !_useOtpLogin ? AppConstants.primaryLight : Colors.transparent),
                          ),
                          alignment: Alignment.center,
                          child: Text('Password Login', style: TextStyle(color: !_useOtpLogin ? AppConstants.primaryLight : AppConstants.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildLabel('Registered Mobile Number'),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold),
                  decoration: _inputDecoration(
                    hint: '0801 234 5678',
                    prefix: Container(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🇳🇬', style: TextStyle(fontSize: 16)),
                          SizedBox(width: 4),
                          Text('+234', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                if (_useOtpLogin) ...[
                  if (!_otpSent) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        onPressed: isLoading ? null : _sendOtp,
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            : const Text('Send SMS Login Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ] else ...[
                    _buildLabel('Enter 6-Digit SMS Code'),
                    TextField(
                      controller: _otpCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppConstants.successColor, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 8),
                      decoration: _inputDecoration(hint: '••••••', prefix: const Icon(Icons.lock_clock_outlined, color: AppConstants.textMuted)),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppConstants.successColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        onPressed: isLoading ? null : _verifyOtpAndLogin,
                        child: isLoading
                            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            : const Text('Verify & Enter Cockpit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: _sendOtp,
                        child: const Text('Resend Code', style: TextStyle(color: AppConstants.accentColor, fontSize: 12)),
                      ),
                    ),
                  ],
                ] else ...[
                  _buildLabel('Account Password'),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                    decoration: _inputDecoration(
                      hint: '••••••••',
                      prefix: const Icon(Icons.lock_outline, color: AppConstants.textMuted),
                      suffix: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppConstants.textMuted),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      onPressed: isLoading ? null : _submitPasswordLogin,
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : const Text('Sign In to Radar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 28),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white10)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white10)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppConstants.primaryColor)),
    );
  }
}

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
  // Sign In Modes: 'OTP', 'EMAIL_PASS', 'PHONE_PASS'
  String _signInMode = 'OTP';
  bool _otpSent = false;
  bool _isPhoneVerified = false;
  bool _obscurePassword = true;

  // Controllers
  final _phoneCtrl = TextEditingController();
  final _emailLoginCtrl = TextEditingController();
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
    _emailLoginCtrl.dispose();
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
      _showSuccess('✓ Phone verified! Please complete driver profile.');
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
    String identifier = '';
    if (_signInMode == 'EMAIL_PASS') {
      identifier = _emailLoginCtrl.text.trim();
      if (identifier.isEmpty || !identifier.contains('@')) {
        _showError('Please enter a valid email address');
        return;
      }
    } else {
      final phone = _phoneCtrl.text.trim();
      if (phone.isEmpty) {
        _showError('Please enter your phone number');
        return;
      }
      identifier = _formatPhone(phone);
    }

    final pass = _passwordCtrl.text;
    if (pass.isEmpty) {
      _showError('Please enter your password');
      return;
    }

    final provider = context.read<DriverProvider>();
    try {
      await provider.login(identifier, pass);
      if (!mounted) return;
      _navigateAfterAuth(provider);
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      if (msg.startsWith('PHONE_UNVERIFIED:')) {
        setState(() {
          _signInMode = 'OTP';
          _otpSent = true;
        });
        _showError('Phone number not verified. An SMS verification code has been dispatched. Enter it below.');
      } else {
        _showError(msg);
      }
    }
  }

  void _submitRegistration() async {
    if (!_isPhoneVerified) {
      _showError('You must verify your phone number via SMS OTP first.');
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

  void _showForgotPasswordSheet() {
    final resetIdCtrl = TextEditingController(text: _phoneCtrl.text.isNotEmpty ? _phoneCtrl.text : _emailLoginCtrl.text);
    final resetOtpCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool resetOtpSent = false;
    bool obscureNewPass = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppConstants.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Reset Account Password', style: TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: AppConstants.textMuted), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                resetOtpSent
                    ? 'Enter the 6-digit SMS code dispatched to your registered phone and set your new password.'
                    : 'Enter your registered phone number or email address to receive a password reset code.',
                style: const TextStyle(color: AppConstants.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              if (!resetOtpSent) ...[
                TextField(
                  controller: resetIdCtrl,
                  style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                  decoration: _inputDecoration(hint: '08012345678 or driver@email.com', prefix: const Icon(Icons.account_circle_outlined, color: AppConstants.textMuted, size: 20)),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () async {
                      final id = resetIdCtrl.text.trim();
                      if (id.isEmpty) return;
                      try {
                        final provider = context.read<DriverProvider>();
                        await provider.api.forgotPassword(id);
                        setSheetState(() => resetOtpSent = true);
                        _showSuccess('Password reset SMS OTP dispatched.');
                      } catch (e) {
                        _showError(e.toString().replaceAll('Exception: ', ''));
                      }
                    },
                    child: const Text('Send Reset Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: resetOtpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppConstants.successColor, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 6),
                  decoration: _inputDecoration(hint: '••••••', prefix: const Icon(Icons.lock_clock_outlined, color: AppConstants.textMuted, size: 20)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newPassCtrl,
                  obscureText: obscureNewPass,
                  style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                  decoration: _inputDecoration(
                    hint: 'New Password (min 6 characters)',
                    prefix: const Icon(Icons.lock_outline, color: AppConstants.textMuted, size: 20),
                    suffix: IconButton(icon: Icon(obscureNewPass ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppConstants.textMuted, size: 20), onPressed: () => setSheetState(() => obscureNewPass = !obscureNewPass)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmPassCtrl,
                  obscureText: obscureNewPass,
                  style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                  decoration: _inputDecoration(hint: 'Confirm New Password', prefix: const Icon(Icons.lock_outline, color: AppConstants.textMuted, size: 20)),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppConstants.successColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () async {
                      final otp = resetOtpCtrl.text.trim();
                      final np = newPassCtrl.text;
                      final cp = confirmPassCtrl.text;
                      if (otp.length < 6 || np.length < 6) {
                        _showError('Please provide complete 6-digit OTP and valid new password');
                        return;
                      }
                      if (np != cp) {
                        _showError('Passwords do not match');
                        return;
                      }
                      try {
                        final provider = context.read<DriverProvider>();
                        final formatted = _formatPhone(resetIdCtrl.text.trim());
                        await provider.api.resetPassword(formatted, otp, np);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _showSuccess('✓ Password reset successfully! Please log in.');
                      } catch (e) {
                        _showError(e.toString().replaceAll('Exception: ', ''));
                      }
                    },
                    child: const Text('Update Password & Sign In', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _navigateAfterAuth(DriverProvider provider) {
    final kyc = provider.driverProfile?['kyc_status'];
    if (kyc != 'APPROVED') {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const KycScreen()), (r) => false);
    } else {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const DriverShell()), (r) => false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppConstants.dangerColor));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppConstants.successColor));
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

              // Tabs: Sign In vs Sign Up
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

              // ================= SIGN IN VIEW =================
              if (!_isSignUp) ...[
                // Sign In Method Chips: 1-Tap Phone OTP vs Email vs Phone Password
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildModeChip('1-Tap Phone OTP', 'OTP', Icons.offline_bolt_rounded),
                      const SizedBox(width: 8),
                      _buildModeChip('Email & Password', 'EMAIL_PASS', Icons.mail_outline_rounded),
                      const SizedBox(width: 8),
                      _buildModeChip('Phone & Password', 'PHONE_PASS', Icons.phone_android_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Method 1: 1-Tap Phone OTP
                if (_signInMode == 'OTP') ...[
                  _buildLabel('Registered Mobile Number'),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold),
                    decoration: _inputDecoration(
                      hint: '0801 234 5678',
                      prefix: Container(
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('🇳🇬', style: TextStyle(fontSize: 16)), SizedBox(width: 4), Text('+234', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 13))]),
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
                        child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Send SMS Login Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
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
                        child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Verify & Enter Cockpit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(child: TextButton(onPressed: _sendOtp, child: const Text('Resend Code', style: TextStyle(color: AppConstants.accentColor, fontSize: 12)))),
                  ],
                ],

                // Method 2: Email & Password
                if (_signInMode == 'EMAIL_PASS') ...[
                  _buildLabel('Driver Email Address'),
                  TextField(
                    controller: _emailLoginCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                    decoration: _inputDecoration(hint: 'driver@example.com', prefix: const Icon(Icons.email_outlined, color: AppConstants.textMuted)),
                  ),
                  const SizedBox(height: 14),
                  _buildLabel('Password'),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                    decoration: _inputDecoration(
                      hint: '••••••••',
                      prefix: const Icon(Icons.lock_outline, color: AppConstants.textMuted),
                      suffix: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppConstants.textMuted), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordSheet,
                      child: const Text('Forgot Password?', style: TextStyle(color: AppConstants.primaryLight, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      onPressed: isLoading ? null : _submitPasswordLogin,
                      child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Sign In via Email', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],

                // Method 3: Phone & Password
                if (_signInMode == 'PHONE_PASS') ...[
                  _buildLabel('Registered Mobile Number'),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold),
                    decoration: _inputDecoration(
                      hint: '0801 234 5678',
                      prefix: Container(
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('🇳🇬', style: TextStyle(fontSize: 16)), SizedBox(width: 4), Text('+234', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 13))]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildLabel('Account Password'),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                    decoration: _inputDecoration(
                      hint: '••••••••',
                      prefix: const Icon(Icons.lock_outline, color: AppConstants.textMuted),
                      suffix: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppConstants.textMuted), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordSheet,
                      child: const Text('Forgot Password?', style: TextStyle(color: AppConstants.primaryLight, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      onPressed: isLoading ? null : _submitPasswordLogin,
                      child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Sign In via Phone', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ],

              // ================= SIGN UP VIEW =================
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
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('🇳🇬', style: TextStyle(fontSize: 16)), SizedBox(width: 4), Text('+234', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 13))]),
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
                        child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Send SMS Verification Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
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
                        child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Verify Code & Proceed to Step 2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(child: TextButton(onPressed: _sendOtp, child: const Text('Resend SMS Code', style: TextStyle(color: AppConstants.accentColor, fontSize: 12)))),
                  ],
                ] else ...[
                  // Phone Verified Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: AppConstants.successColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppConstants.successColor.withOpacity(0.4))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [const Icon(Icons.check_circle_rounded, color: AppConstants.successColor, size: 20), const SizedBox(width: 8), Text('✓ ${_formatPhone(_phoneCtrl.text.trim())}', style: const TextStyle(color: AppConstants.successColor, fontWeight: FontWeight.bold, fontSize: 13))]),
                        GestureDetector(onTap: () => setState(() { _isPhoneVerified = false; _otpSent = false; }), child: const Text('Change', style: TextStyle(color: AppConstants.textMuted, fontSize: 12, decoration: TextDecoration.underline))),
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
                      child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Complete Registration & Claim 5 Free Rides', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
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

  Widget _buildModeChip(String label, String mode, IconData icon) {
    final isSelected = _signInMode == mode;
    return GestureDetector(
      onTap: () => setState(() {
        _signInMode = mode;
        _otpSent = false;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.primaryColor.withOpacity(0.2) : AppConstants.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppConstants.primaryColor : Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? AppConstants.primaryColor : AppConstants.textMuted),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isSelected ? AppConstants.textLight : AppConstants.textMuted, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
          ],
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

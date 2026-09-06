import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/passenger_provider.dart';
import 'home_screen.dart';

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
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _promoCodeCtrl = TextEditingController();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailLoginCtrl.dispose();
    _otpCtrl.dispose();
    _passwordCtrl.dispose();
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _promoCodeCtrl.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String raw) {
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
    final formatted = _formatPhoneNumber(phone);
    final provider = context.read<PassengerProvider>();

    try {
      await provider.sendPhoneOtp(formatted);
      setState(() => _otpSent = true);
      _showSuccess('6-digit verification code sent via Twilio SMS to $formatted');
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _verifyOtpForSignUp() async {
    final phone = _formatPhoneNumber(_phoneCtrl.text.trim());
    final otp = _otpCtrl.text.trim();
    if (otp.length < 6) {
      _showError('Please enter the complete 6-digit OTP code');
      return;
    }

    final provider = context.read<PassengerProvider>();
    try {
      await provider.verifyPhoneOtp(phone, otp);
      setState(() => _isPhoneVerified = true);
      _showSuccess('✓ Phone number verified! Please complete your passenger profile.');
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _verifyOtpAndLogin() async {
    final phone = _formatPhoneNumber(_phoneCtrl.text.trim());
    final otp = _otpCtrl.text.trim();
    if (otp.length < 6) {
      _showError('Please enter the complete 6-digit OTP code');
      return;
    }

    final provider = context.read<PassengerProvider>();
    try {
      await provider.verifyPhoneOtp(phone, otp);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
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
      identifier = _formatPhoneNumber(phone);
    }

    final pass = _passwordCtrl.text;
    if (pass.isEmpty) {
      _showError('Please enter your password');
      return;
    }

    final provider = context.read<PassengerProvider>();
    try {
      await provider.login(identifier, pass);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
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

    final name = _fullNameCtrl.text.trim();
    final phone = _formatPhoneNumber(_phoneCtrl.text.trim());
    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text;

    if (name.isEmpty || email.isEmpty || pass.length < 6) {
      _showError('Please fill in your full name, email, and password (min 6 characters)');
      return;
    }
    if (!email.contains('@')) {
      _showError('Please enter a valid email address');
      return;
    }

    final provider = context.read<PassengerProvider>();
    try {
      await provider.register(name, phone, email, pass);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
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
                  decoration: _buildInputDecoration(hint: '08012345678 or user@email.com', icon: Icons.account_circle_outlined),
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
                        final provider = context.read<PassengerProvider>();
                        await provider.api.forgotPassword(id);
                        setSheetState(() => resetOtpSent = true);
                        _showSuccess('Password reset SMS code dispatched.');
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
                  decoration: _buildInputDecoration(hint: '••••••', icon: Icons.lock_clock_outlined),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newPassCtrl,
                  obscureText: obscureNewPass,
                  style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                  decoration: _buildInputDecoration(
                    hint: 'New Password (min 6 characters)',
                    icon: Icons.lock_outline,
                    suffixWidget: IconButton(icon: Icon(obscureNewPass ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppConstants.textMuted, size: 20), onPressed: () => setSheetState(() => obscureNewPass = !obscureNewPass)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmPassCtrl,
                  obscureText: obscureNewPass,
                  style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                  decoration: _buildInputDecoration(hint: 'Confirm New Password', icon: Icons.lock_outline),
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
                        final provider = context.read<PassengerProvider>();
                        final formatted = _formatPhoneNumber(resetIdCtrl.text.trim());
                        await provider.api.resetPassword(formatted, otp, np);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _showSuccess('✓ Password reset successfully! Please sign in.');
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppConstants.dangerColor));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: AppConstants.successColor));
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<PassengerProvider>().isLoading;

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
                      Text('GIGA RIDE', style: TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
                      Text('PASSENGER PORTAL', style: TextStyle(color: AppConstants.primaryLight, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Tabs: Sign In vs Create Account
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: AppConstants.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppConstants.surfaceBg)),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() { _isSignUp = false; _otpSent = false; }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(color: !_isSignUp ? AppConstants.primaryColor : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                          alignment: Alignment.center,
                          child: Text('Sign In', style: TextStyle(color: !_isSignUp ? Colors.white : AppConstants.textMuted, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() { _isSignUp = true; _otpSent = false; }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(color: _isSignUp ? AppConstants.primaryColor : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                          alignment: Alignment.center,
                          child: Text('Create Account', style: TextStyle(color: _isSignUp ? Colors.white : AppConstants.textMuted, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(_isSignUp ? 'Join Giga Ride' : 'Welcome Back', style: const TextStyle(color: AppConstants.textLight, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                _isSignUp
                    ? (_isPhoneVerified ? 'Step 2 of 2: Enter your name and password' : 'Step 1 of 2: Verify your phone number via SMS OTP')
                    : 'Sign in to access your living wallet, book rides, and view live driver bids.',
                style: const TextStyle(color: AppConstants.textMuted, fontSize: 13),
              ),

              const SizedBox(height: 24),

              // ================= SIGN IN VIEW =================
              if (!_isSignUp) ...[
                // Sign In Method Chips
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

                if (_signInMode == 'OTP') ...[
                  _buildFieldLabel('Phone Number'),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold),
                    decoration: _buildInputDecoration(
                      hint: '0801 234 5678',
                      icon: Icons.phone_iphone_rounded,
                      prefixWidget: Container(
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('🇳🇬', style: TextStyle(fontSize: 16)), SizedBox(width: 4), Text('+234', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 13))]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (!_otpSent) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: isLoading ? null : _sendOtp,
                        child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Send SMS Login Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ] else ...[
                    _buildFieldLabel('Enter 6-Digit SMS Code'),
                    TextField(
                      controller: _otpCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppConstants.successColor, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 8),
                      decoration: _buildInputDecoration(hint: '••••••', icon: Icons.lock_clock_outlined),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppConstants.successColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: isLoading ? null : _verifyOtpAndLogin,
                        child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Verify & Enter Passenger Portal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(child: TextButton(onPressed: _sendOtp, child: const Text('Resend Code', style: TextStyle(color: AppConstants.accentColor, fontSize: 12)))),
                  ],
                ],

                if (_signInMode == 'EMAIL_PASS') ...[
                  _buildFieldLabel('Email Address'),
                  TextField(
                    controller: _emailLoginCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                    decoration: _buildInputDecoration(hint: 'user@example.com', icon: Icons.alternate_email_rounded),
                  ),
                  const SizedBox(height: 14),
                  _buildFieldLabel('Password'),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                    decoration: _buildInputDecoration(
                      hint: '••••••••••••',
                      icon: Icons.lock_outline_rounded,
                      suffixWidget: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppConstants.textMuted, size: 20), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: _showForgotPasswordSheet, child: const Text('Forgot Password?', style: TextStyle(color: AppConstants.primaryLight, fontSize: 12, fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: isLoading ? null : _submitPasswordLogin,
                      child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Sign In via Email', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],

                if (_signInMode == 'PHONE_PASS') ...[
                  _buildFieldLabel('Phone Number'),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold),
                    decoration: _buildInputDecoration(
                      hint: '0801 234 5678',
                      icon: Icons.phone_iphone_rounded,
                      prefixWidget: Container(
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('🇳🇬', style: TextStyle(fontSize: 16)), SizedBox(width: 4), Text('+234', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 13))]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildFieldLabel('Password'),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                    decoration: _buildInputDecoration(
                      hint: '••••••••••••',
                      icon: Icons.lock_outline_rounded,
                      suffixWidget: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppConstants.textMuted, size: 20), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: _showForgotPasswordSheet, child: const Text('Forgot Password?', style: TextStyle(color: AppConstants.primaryLight, fontSize: 12, fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: isLoading ? null : _submitPasswordLogin,
                      child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Sign In via Phone', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ],

              // ================= SIGN UP VIEW =================
              if (_isSignUp) ...[
                if (!_isPhoneVerified) ...[
                  _buildFieldLabel('Nigerian Phone Number (+234)'),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: AppConstants.textLight, fontSize: 15, fontWeight: FontWeight.bold),
                    decoration: _buildInputDecoration(
                      hint: '0801 234 5678',
                      icon: Icons.phone_iphone_rounded,
                      prefixWidget: Container(
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('🇳🇬', style: TextStyle(fontSize: 16)), SizedBox(width: 4), Text('+234', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 13))]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (!_otpSent) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: isLoading ? null : _sendOtp,
                        child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Send SMS Verification Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ] else ...[
                    _buildFieldLabel('Enter 6-Digit SMS Verification Code'),
                    TextField(
                      controller: _otpCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppConstants.successColor, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 8),
                      decoration: _buildInputDecoration(hint: '••••••', icon: Icons.lock_clock_outlined),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppConstants.successColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: isLoading ? null : _verifyOtpForSignUp,
                        child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Verify Code & Continue to Step 2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(child: TextButton(onPressed: _sendOtp, child: const Text('Resend Verification Code', style: TextStyle(color: AppConstants.accentColor, fontSize: 12)))),
                  ],
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: AppConstants.successColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppConstants.successColor.withOpacity(0.4))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [const Icon(Icons.check_circle_rounded, color: AppConstants.successColor, size: 20), const SizedBox(width: 8), Text('✓ ${_formatPhoneNumber(_phoneCtrl.text.trim())}', style: const TextStyle(color: AppConstants.successColor, fontWeight: FontWeight.bold, fontSize: 13))]),
                        GestureDetector(onTap: () => setState(() { _isPhoneVerified = false; _otpSent = false; }), child: const Text('Change', style: TextStyle(color: AppConstants.textMuted, fontSize: 12, decoration: TextDecoration.underline))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildFieldLabel('Full Name'),
                  TextField(controller: _fullNameCtrl, style: const TextStyle(color: AppConstants.textLight, fontSize: 14), decoration: _buildInputDecoration(hint: 'e.g. Adebayo Adeleke', icon: Icons.person_outline_rounded)),
                  const SizedBox(height: 14),

                  _buildFieldLabel('Email Address (for receipts)'),
                  TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: AppConstants.textLight, fontSize: 14), decoration: _buildInputDecoration(hint: 'name@example.ng', icon: Icons.alternate_email_rounded)),
                  const SizedBox(height: 14),

                  _buildFieldLabel('Password (min 6 characters)'),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                    decoration: _buildInputDecoration(
                      hint: '••••••••••••',
                      icon: Icons.lock_outline_rounded,
                      suffixWidget: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppConstants.textMuted, size: 20), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildFieldLabel('Promo Voucher (Optional)'),
                  TextField(controller: _promoCodeCtrl, style: const TextStyle(color: AppConstants.primaryLight, fontSize: 14, fontWeight: FontWeight.bold), decoration: _buildInputDecoration(hint: 'e.g. GIGAWELCOME', icon: Icons.confirmation_number_outlined)),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: isLoading ? null : _submitRegistration,
                      child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Create Account & Start Riding', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
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
          border: Border.all(color: isSelected ? AppConstants.primaryColor : AppConstants.surfaceBg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? AppConstants.primaryLight : AppConstants.textMuted),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isSelected ? AppConstants.textLight : AppConstants.textMuted, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(label, style: const TextStyle(color: AppConstants.textLight, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  InputDecoration _buildInputDecoration({required String hint, IconData? icon, Widget? prefixWidget, Widget? suffixWidget}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 13),
      prefixIcon: prefixWidget ?? (icon != null ? Icon(icon, color: AppConstants.textMuted, size: 20) : null),
      suffixIcon: suffixWidget,
      filled: true,
      fillColor: AppConstants.cardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppConstants.surfaceBg)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppConstants.surfaceBg)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppConstants.primaryColor)),
    );
  }
}

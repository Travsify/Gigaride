import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/driver_provider.dart';
import '../services/biometric_service.dart';
import 'kyc_screen.dart';
import 'driver_shell.dart';

class PhoneAuthScreen extends StatefulWidget {
  final bool initialIsSignUp;
  const PhoneAuthScreen({super.key, this.initialIsSignUp = false});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  late bool _isSignUp;
  // Sign In Modes: 'PHONE', 'EMAIL', 'PHONE_OTP'
  String _signInMode = 'PHONE';
  bool _obscurePassword = true;

  // Biometrics
  bool _isBiometricEnabled = false;

  // Sign Up Multi-Step Flow:
  // Step 1: Phone Number & SMS Verification
  // Step 2: Driver Details, Vehicle Specs, Email & Email Verification
  int _signUpStep = 1;
  bool _phoneOtpSent = false;
  bool _emailOtpSent = false;

  // Sign In OTP state
  bool _loginOtpSent = false;

  // Sign Up Controllers
  final _phoneCtrl = TextEditingController();
  final _phoneOtpCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _emailOtpCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _vehicleMakeCtrl = TextEditingController();
  final _vehicleModelCtrl = TextEditingController();
  final _vehicleYearCtrl = TextEditingController(text: '2018');
  final _licensePlateCtrl = TextEditingController();
  final _vehicleColorCtrl = TextEditingController(text: 'Silver');
  final _ninCtrl = TextEditingController();

  // Login Controllers
  final _loginPhoneCtrl = TextEditingController();
  final _loginEmailCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();
  final _loginOtpCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialIsSignUp;
    _checkBiometrics();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _phoneOtpCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _emailOtpCtrl.dispose();
    _passwordCtrl.dispose();
    _vehicleMakeCtrl.dispose();
    _vehicleModelCtrl.dispose();
    _vehicleYearCtrl.dispose();
    _licensePlateCtrl.dispose();
    _vehicleColorCtrl.dispose();
    _ninCtrl.dispose();
    _loginPhoneCtrl.dispose();
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _loginOtpCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final enabled = await BiometricService.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _isBiometricEnabled = enabled;
      });
    }
  }

  String _formatPhone(String raw) {
    String clean = raw.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (clean.startsWith('+234')) return clean;
    if (clean.startsWith('234')) return '+$clean';
    if (clean.startsWith('0')) return '+234${clean.substring(1)}';
    return '+234$clean';
  }

  // ==========================================
  // SIGN UP: STEP 1 - PHONE VERIFICATION
  // ==========================================
  void _sendPhoneOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      _showError('Please enter your phone number');
      return;
    }
    final formatted = _formatPhone(phone);
    final provider = context.read<DriverProvider>();

    try {
      await provider.api.sendPhoneOtp(formatted);
      setState(() => _phoneOtpSent = true);
      _showSuccess('Verification code sent to your phone via SMS.');
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _verifyPhoneOtp() async {
    final phone = _formatPhone(_phoneCtrl.text.trim());
    final otp = _phoneOtpCtrl.text.trim();
    if (otp.length < 6) {
      _showError('Please enter the complete 6-digit SMS code');
      return;
    }

    final provider = context.read<DriverProvider>();
    try {
      await provider.api.verifyPhoneOtp(phone, otp);
      setState(() {
        _signUpStep = 2;
      });
      _showSuccess('✓ Phone verified. Complete driver details & email verification.');
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ==========================================
  // SIGN UP: STEP 2 - EMAIL VERIFICATION & SUBMIT
  // ==========================================
  void _sendEmailOtp() async {
    final email = _emailCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final pass = _passwordCtrl.text;
    final make = _vehicleMakeCtrl.text.trim();
    final model = _vehicleModelCtrl.text.trim();
    final plate = _licensePlateCtrl.text.trim();

    if (name.isEmpty) {
      _showError('Please enter your full name');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _showError('Please enter a valid email address');
      return;
    }
    if (pass.length < 6) {
      _showError('Password must be at least 6 characters long');
      return;
    }
    if (make.isEmpty || model.isEmpty || plate.isEmpty) {
      _showError('Please enter vehicle make, model, and license plate');
      return;
    }

    final provider = context.read<DriverProvider>();
    try {
      await provider.sendEmailOtp(email);
      setState(() => _emailOtpSent = true);
      _showSuccess('Verification code sent to your email address.');
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _completeRegistration() async {
    final email = _emailCtrl.text.trim();
    final otp = _emailOtpCtrl.text.trim();
    final phone = _formatPhone(_phoneCtrl.text.trim());
    final name = _nameCtrl.text.trim();
    final pass = _passwordCtrl.text;
    final make = _vehicleMakeCtrl.text.trim();
    final model = _vehicleModelCtrl.text.trim();
    final year = int.tryParse(_vehicleYearCtrl.text.trim()) ?? 2018;
    final plate = _licensePlateCtrl.text.trim().toUpperCase();
    final color = _vehicleColorCtrl.text.trim();
    final nin = _ninCtrl.text.trim();

    if (otp.length < 6) {
      _showError('Please enter the 6-digit verification code sent to your email');
      return;
    }

    final provider = context.read<DriverProvider>();
    try {
      // 1. Verify Email OTP
      await provider.verifyEmailOtp(email, otp);

      // 2. Register Driver
      await provider.register({
        'role': 'DRIVER',
        'fullName': name,
        'phoneNumber': phone,
        'email': email,
        'password': pass,
        'vehicleMake': make,
        'vehicleModel': model,
        'vehicleYear': year,
        'licensePlate': plate,
        'vehicleColor': color.isNotEmpty ? color : 'Silver',
        'nin': nin.isNotEmpty ? nin : null,
      });

      if (!mounted) return;

      // 3. Prompt Biometrics Opt-In
      _showBiometricOptIn(identifier: phone, password: pass);
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showBiometricOptIn({required String identifier, required String password}) {
    final provider = context.read<DriverProvider>();
    final token = provider.token ?? '';
    final userJson = jsonEncode(provider.user ?? {});

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppConstants.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppConstants.primaryLight.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppConstants.primaryLight.withOpacity(0.4)),
              ),
              child: const Icon(Icons.fingerprint_rounded, size: 36, color: AppConstants.primaryLight),
            ),
            const SizedBox(height: 18),
            const Text(
              'Enable Biometric Sign In',
              style: TextStyle(color: AppConstants.textLight, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Log in faster next time using your fingerprint or Face ID to quickly accept ride requests.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppConstants.textMuted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final authed = await BiometricService.authenticate(
                    reason: 'Authenticate to enable biometric login for Giga Driver',
                  );
                  if (authed) {
                    await BiometricService.enableBiometrics(
                      token: token,
                      userJson: userJson,
                      identifier: identifier,
                      password: password,
                    );
                  }
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  _navigateAfterAuth(provider);
                },
                child: const Text('Enable Biometrics', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _navigateAfterAuth(provider);
              },
              child: const Text('Maybe Later', style: TextStyle(color: AppConstants.textMuted, fontSize: 13)),
            ),
          ],
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

  // ==========================================
  // SIGN IN LOGIC (PHONE / EMAIL / BIOMETRIC)
  // ==========================================
  void _loginWithBiometrics() async {
    final credentials = await BiometricService.getSavedCredentials();
    if (credentials == null) {
      _showError('No saved biometric credentials found. Please sign in with password.');
      return;
    }

    final authenticated = await BiometricService.authenticate(
      reason: 'Scan fingerprint or face to sign in to Giga Driver',
    );
    if (!authenticated || !mounted) return;

    final id = credentials['identifier'];
    final pass = credentials['password'];
    final provider = context.read<DriverProvider>();

    try {
      if (id != null && pass != null) {
        await provider.login(id, pass);
      } else if (credentials['token'] != null && credentials['user'] != null) {
        provider.user = jsonDecode(credentials['user']!);
        provider.token = credentials['token'];
        await provider.refreshSubscription();
        await provider.loadVirtualAccount();
        await provider.loadNotifications();
        provider.connectSocket(credentials['token']!);
      } else {
        throw Exception('Saved biometric credentials incomplete.');
      }
      if (!mounted) return;
      _navigateAfterAuth(provider);
    } catch (e) {
      _showError('Biometric session expired. Please sign in with your password.');
    }
  }

  void _submitLogin() async {
    String identifier = '';
    if (_signInMode == 'EMAIL') {
      final email = _loginEmailCtrl.text.trim();
      if (email.isEmpty || !email.contains('@')) {
        _showError('Please enter a valid email address');
        return;
      }
      identifier = email;
    } else {
      final phone = _loginPhoneCtrl.text.trim();
      if (phone.isEmpty) {
        _showError('Please enter your phone number');
        return;
      }
      identifier = _formatPhone(phone);
    }

    final pass = _loginPasswordCtrl.text;
    if (pass.isEmpty) {
      _showError('Please enter your password');
      return;
    }

    final provider = context.read<DriverProvider>();
    try {
      await provider.login(identifier, pass);
      if (!mounted) return;

      if (_isBiometricEnabled) {
        await BiometricService.enableBiometrics(
          token: provider.token ?? '',
          userJson: jsonEncode(provider.user ?? {}),
          identifier: identifier,
          password: pass,
        );
      }

      _navigateAfterAuth(provider);
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      if (msg.startsWith('PHONE_UNVERIFIED:')) {
        setState(() {
          _signInMode = 'PHONE_OTP';
          _loginOtpSent = true;
        });
        _showError('Phone number not verified. An SMS verification code has been dispatched.');
      } else {
        _showError(msg);
      }
    }
  }

  void _sendLoginPhoneOtp() async {
    final phone = _loginPhoneCtrl.text.trim();
    if (phone.isEmpty) {
      _showError('Please enter your phone number');
      return;
    }
    final formatted = _formatPhone(phone);
    final provider = context.read<DriverProvider>();

    try {
      await provider.api.sendPhoneOtp(formatted);
      setState(() => _loginOtpSent = true);
      _showSuccess('Verification code sent to your phone via SMS.');
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _verifyLoginPhoneOtp() async {
    final phone = _formatPhone(_loginPhoneCtrl.text.trim());
    final otp = _loginOtpCtrl.text.trim();
    if (otp.length < 6) {
      _showError('Please enter the 6-digit SMS code');
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

  void _showForgotPasswordSheet() {
    final resetIdCtrl = TextEditingController(text: _loginPhoneCtrl.text.isNotEmpty ? _loginPhoneCtrl.text : _loginEmailCtrl.text);
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
                        final provider = context.read<DriverProvider>();
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
                    suffixWidget: IconButton(
                      icon: Icon(obscureNewPass ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppConstants.textMuted, size: 20),
                      onPressed: () => setSheetState(() => obscureNewPass = !obscureNewPass),
                    ),
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
                        _showError('Please provide complete 6-digit code and valid new password');
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
                      color: AppConstants.accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppConstants.accentColor.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.directions_car_filled_rounded, color: AppConstants.accentColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GIGA RIDE', style: TextStyle(color: AppConstants.textLight, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
                      Text('DRIVER COCKPIT', style: TextStyle(color: AppConstants.accentColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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
                        onTap: () => setState(() {
                          _isSignUp = false;
                        }),
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
                        onTap: () => setState(() {
                          _isSignUp = true;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(color: _isSignUp ? AppConstants.primaryColor : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                          alignment: Alignment.center,
                          child: Text('Register Driver', style: TextStyle(color: _isSignUp ? Colors.white : AppConstants.textMuted, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                _isSignUp ? 'Register as Driver' : 'Welcome Back Driver',
                style: const TextStyle(color: AppConstants.textLight, fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                _isSignUp
                    ? (_signUpStep == 1 ? 'Step 1 of 2: Verify your phone number via SMS' : 'Step 2 of 2: Vehicle details, credentials & email verification')
                    : 'Sign in to access your cockpit radar, submit bids, and manage your earnings.',
                style: const TextStyle(color: AppConstants.textMuted, fontSize: 13),
              ),

              const SizedBox(height: 24),

              // ==========================================
              // SIGN IN TAB
              // ==========================================
              if (!_isSignUp) ...[
                // Biometric 1-Tap Login Button (if enabled)
                if (_isBiometricEnabled) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppConstants.primaryColor.withOpacity(0.2), AppConstants.surfaceBg],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppConstants.primaryLight.withOpacity(0.3)),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _loginWithBiometrics,
                        borderRadius: BorderRadius.circular(16),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          child: Row(
                            children: [
                              Icon(Icons.fingerprint_rounded, color: AppConstants.primaryLight, size: 28),
                              SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Quick Biometric Sign In', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 14)),
                                    SizedBox(height: 2),
                                    Text('Scan fingerprint or face to open cockpit', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: AppConstants.textMuted),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                // Selector: Phone Number vs Email Address
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppConstants.surfaceBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _signInMode = 'PHONE';
                            _loginOtpSent = false;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: (_signInMode == 'PHONE' || _signInMode == 'PHONE_OTP') ? AppConstants.cardBg : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.phone_iphone_rounded, size: 16, color: (_signInMode == 'PHONE' || _signInMode == 'PHONE_OTP') ? AppConstants.primaryLight : AppConstants.textMuted),
                                const SizedBox(width: 6),
                                Text('Phone Number', style: TextStyle(color: (_signInMode == 'PHONE' || _signInMode == 'PHONE_OTP') ? AppConstants.textLight : AppConstants.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _signInMode = 'EMAIL';
                            _loginOtpSent = false;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _signInMode == 'EMAIL' ? AppConstants.cardBg : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.alternate_email_rounded, size: 16, color: _signInMode == 'EMAIL' ? AppConstants.primaryLight : AppConstants.textMuted),
                                const SizedBox(width: 6),
                                Text('Email Address', style: TextStyle(color: _signInMode == 'EMAIL' ? AppConstants.textLight : AppConstants.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Phone Login View
                if (_signInMode == 'PHONE') ...[
                  _buildFieldLabel('Phone Number'),
                  TextField(
                    controller: _loginPhoneCtrl,
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
                    controller: _loginPasswordCtrl,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                    decoration: _buildInputDecoration(
                      hint: '••••••••••••',
                      icon: Icons.lock_outline_rounded,
                      suffixWidget: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppConstants.textMuted, size: 20),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _signInMode = 'PHONE_OTP'),
                        child: const Text('Sign in with SMS Code instead', style: TextStyle(color: AppConstants.accentColor, fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: _showForgotPasswordSheet,
                        child: const Text('Forgot Password?', style: TextStyle(color: AppConstants.primaryLight, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: isLoading ? null : _submitLogin,
                      child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Sign In to Driver Cockpit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],

                // Phone OTP Login View
                if (_signInMode == 'PHONE_OTP') ...[
                  _buildFieldLabel('Phone Number'),
                  TextField(
                    controller: _loginPhoneCtrl,
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

                  if (!_loginOtpSent) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: isLoading ? null : _sendLoginPhoneOtp,
                        child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Send SMS Verification Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ] else ...[
                    _buildFieldLabel('Enter 6-Digit SMS Verification Code'),
                    TextField(
                      controller: _loginOtpCtrl,
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
                        onPressed: isLoading ? null : _verifyLoginPhoneOtp,
                        child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Verify & Enter Cockpit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(child: TextButton(onPressed: _sendLoginPhoneOtp, child: const Text('Resend SMS Code', style: TextStyle(color: AppConstants.accentColor, fontSize: 12)))),
                  ],
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _signInMode = 'PHONE'),
                      child: const Text('← Back to Password Login', style: TextStyle(color: AppConstants.textMuted, fontSize: 12)),
                    ),
                  ),
                ],

                // Email Login View
                if (_signInMode == 'EMAIL') ...[
                  _buildFieldLabel('Email Address'),
                  TextField(
                    controller: _loginEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                    decoration: _buildInputDecoration(hint: 'name@example.ng', icon: Icons.alternate_email_rounded),
                  ),
                  const SizedBox(height: 14),
                  _buildFieldLabel('Password'),
                  TextField(
                    controller: _loginPasswordCtrl,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                    decoration: _buildInputDecoration(
                      hint: '••••••••••••',
                      icon: Icons.lock_outline_rounded,
                      suffixWidget: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppConstants.textMuted, size: 20),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
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
                      onPressed: isLoading ? null : _submitLogin,
                      child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Sign In with Email', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ],

              // ==========================================
              // SIGN UP TAB (DUAL PHONE & EMAIL VERIFICATION)
              // ==========================================
              if (_isSignUp) ...[
                // STEP 1: Phone Verification
                if (_signUpStep == 1) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: AppConstants.surfaceBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.phone_locked_rounded, color: AppConstants.primaryLight, size: 22),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Step 1: Phone Verification', style: TextStyle(color: AppConstants.textLight, fontWeight: FontWeight.bold, fontSize: 13)),
                              SizedBox(height: 2),
                              Text('We will dispatch a 6-digit SMS verification code to verify your mobile identity.', style: TextStyle(color: AppConstants.textMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

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

                  if (!_phoneOtpSent) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: isLoading ? null : _sendPhoneOtp,
                        child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Send SMS Verification Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ] else ...[
                    _buildFieldLabel('Enter 6-Digit SMS Verification Code'),
                    TextField(
                      controller: _phoneOtpCtrl,
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
                        onPressed: isLoading ? null : _verifyPhoneOtp,
                        child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Verify Phone & Continue to Step 2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(child: TextButton(onPressed: _sendPhoneOtp, child: const Text('Resend Verification Code', style: TextStyle(color: AppConstants.accentColor, fontSize: 12)))),
                  ],
                ],

                // STEP 2: Driver & Vehicle Details + Email Verification
                if (_signUpStep == 2) ...[
                  // Verified Phone Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(color: AppConstants.successColor.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppConstants.successColor.withOpacity(0.4))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [const Icon(Icons.check_circle_rounded, color: AppConstants.successColor, size: 20), const SizedBox(width: 8), Text('✓ ${_formatPhone(_phoneCtrl.text.trim())}', style: const TextStyle(color: AppConstants.successColor, fontWeight: FontWeight.bold, fontSize: 13))]),
                        GestureDetector(onTap: () => setState(() { _signUpStep = 1; _phoneOtpSent = false; }), child: const Text('Edit Phone', style: TextStyle(color: AppConstants.textMuted, fontSize: 12, decoration: TextDecoration.underline))),
                      ],
                    ),
                  ),

                  _buildFieldLabel('Full Name (as on Government ID)'),
                  TextField(controller: _nameCtrl, style: const TextStyle(color: AppConstants.textLight, fontSize: 14), decoration: _buildInputDecoration(hint: 'e.g. Chukwuemeka Okonkwo', icon: Icons.person_outline_rounded)),
                  const SizedBox(height: 14),

                  _buildFieldLabel('Email Address (Verification Required)'),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_emailOtpSent,
                    style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                    decoration: _buildInputDecoration(
                      hint: 'driver@example.ng',
                      icon: Icons.alternate_email_rounded,
                      suffixWidget: _emailOtpSent
                          ? IconButton(
                              icon: const Icon(Icons.edit, color: AppConstants.accentColor, size: 18),
                              onPressed: () => setState(() => _emailOtpSent = false),
                            )
                          : null,
                    ),
                  ),
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
                  const SizedBox(height: 18),

                  const Divider(color: Colors.white10),
                  const SizedBox(height: 10),
                  const Text('COMMERCIAL VEHICLE DETAILS', style: TextStyle(color: AppConstants.accentColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Vehicle Make'),
                            TextField(controller: _vehicleMakeCtrl, style: const TextStyle(color: AppConstants.textLight, fontSize: 14), decoration: _buildInputDecoration(hint: 'e.g. Toyota', icon: Icons.car_repair_rounded)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Vehicle Model'),
                            TextField(controller: _vehicleModelCtrl, style: const TextStyle(color: AppConstants.textLight, fontSize: 14), decoration: _buildInputDecoration(hint: 'e.g. Corolla', icon: Icons.drive_eta_rounded)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Year'),
                            TextField(controller: _vehicleYearCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: AppConstants.textLight, fontSize: 14), decoration: _buildInputDecoration(hint: '2018', icon: Icons.calendar_today_rounded)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('License Plate'),
                            TextField(controller: _licensePlateCtrl, textCapitalization: TextCapitalization.characters, style: const TextStyle(color: AppConstants.textLight, fontSize: 14, fontWeight: FontWeight.bold), decoration: _buildInputDecoration(hint: 'LAG-123-AA', icon: Icons.credit_card_rounded)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Color'),
                            TextField(controller: _vehicleColorCtrl, style: const TextStyle(color: AppConstants.textLight, fontSize: 14), decoration: _buildInputDecoration(hint: 'e.g. Silver', icon: Icons.palette_outlined)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('NIN (Optional)'),
                            TextField(controller: _ninCtrl, keyboardType: TextInputType.number, maxLength: 11, style: const TextStyle(color: AppConstants.textLight, fontSize: 14), decoration: _buildInputDecoration(hint: '11 digits', icon: Icons.badge_outlined)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  if (!_emailOtpSent) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: isLoading ? null : _sendEmailOtp,
                        child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Send Email Verification Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ] else ...[
                    _buildFieldLabel('Enter 6-Digit Email Verification Code'),
                    TextField(
                      controller: _emailOtpCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppConstants.successColor, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 8),
                      decoration: _buildInputDecoration(hint: '••••••', icon: Icons.mark_email_read_outlined),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppConstants.successColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: isLoading ? null : _completeRegistration,
                        child: isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Verify Email & Register Cockpit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(child: TextButton(onPressed: _sendEmailOtp, child: const Text('Resend Email Code', style: TextStyle(color: AppConstants.accentColor, fontSize: 12)))),
                  ],
                ],
              ],

              const SizedBox(height: 28),
            ],
          ),
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

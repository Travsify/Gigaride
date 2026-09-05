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
  bool _obscurePassword = true;

  // Controllers (clean, ZERO dummy data!)
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _promoCodeCtrl = TextEditingController();

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _promoCodeCtrl.dispose();
    super.dispose();
  }

  // Normalizes Nigerian phone number format (+234 standard)
  String _formatPhoneNumber(String raw) {
    String clean = raw.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (clean.startsWith('+234')) {
      return clean;
    }
    if (clean.startsWith('234')) {
      return '+$clean';
    }
    if (clean.startsWith('0')) {
      clean = clean.substring(1);
    }
    return '+234$clean';
  }

  void _submit() async {
    final phoneText = _phoneCtrl.text.trim();
    final passwordText = _passwordCtrl.text;

    if (phoneText.isEmpty || passwordText.isEmpty) {
      _showError('Please provide your phone number and password.');
      return;
    }

    if (_isSignUp) {
      final nameText = _fullNameCtrl.text.trim();
      final emailText = _emailCtrl.text.trim();

      if (nameText.isEmpty || emailText.isEmpty) {
        _showError('Please fill in your full name and email address.');
        return;
      }
      if (!emailText.contains('@') || !emailText.contains('.')) {
        _showError('Please enter a valid email address.');
        return;
      }
      if (passwordText.length < 6) {
        _showError('Password must be at least 6 characters long.');
        return;
      }

      final normalizedPhone = _formatPhoneNumber(phoneText);
      final provider = context.read<PassengerProvider>();

      try {
        await provider.register(nameText, normalizedPhone, emailText, passwordText);
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (r) => false,
        );
      } catch (e) {
        _showError(e.toString().replaceAll('Exception: ', ''));
      }
    } else {
      // Sign In
      final identifier = phoneText.contains('@') ? phoneText : _formatPhoneNumber(phoneText);
      final provider = context.read<PassengerProvider>();

      try {
        await provider.login(identifier, passwordText);
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (r) => false,
        );
      } catch (e) {
        _showError(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppConstants.dangerColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
              const SizedBox(height: 12),

              // Header Brand Row
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppConstants.primaryLight.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppConstants.primaryLight.withOpacity(0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.local_taxi_rounded,
                      color: AppConstants.primaryLight,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GIGA RIDE',
                        style: TextStyle(
                          color: AppConstants.textLight,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        'PASSENGER PORTAL',
                        style: TextStyle(
                          color: AppConstants.primaryLight,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Tab Switcher (Sign In vs Create Account)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppConstants.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppConstants.surfaceBg),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isSignUp = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isSignUp
                                ? AppConstants.primaryColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: !_isSignUp
                                ? [
                                    BoxShadow(
                                      color: AppConstants.primaryColor.withOpacity(0.4),
                                      blurRadius: 10,
                                    ),
                                  ]
                                : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Sign In',
                            style: TextStyle(
                              color: !_isSignUp
                                  ? Colors.white
                                  : AppConstants.textMuted,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isSignUp = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isSignUp
                                ? AppConstants.primaryColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _isSignUp
                                ? [
                                    BoxShadow(
                                      color: AppConstants.primaryColor.withOpacity(0.4),
                                      blurRadius: 10,
                                    ),
                                  ]
                                : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Create Account',
                            style: TextStyle(
                              color: _isSignUp
                                  ? Colors.white
                                  : AppConstants.textMuted,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Title & Subtitle
              Text(
                _isSignUp ? 'Join Giga Ride' : 'Welcome Back',
                style: const TextStyle(
                  color: AppConstants.textLight,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isSignUp
                    ? 'Create your free passenger wallet and start bidding your own ride fares.'
                    : 'Sign in to access your living wallet, active trips, and commute passes.',
                style: const TextStyle(
                  color: AppConstants.textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 24),

              // Sign Up: Full Name
              if (_isSignUp) ...[
                _buildFieldLabel('Full Name'),
                TextField(
                  controller: _fullNameCtrl,
                  style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                  textCapitalization: TextCapitalization.words,
                  decoration: _buildInputDecoration(
                    hint: 'e.g. Adebayo Adeleke',
                    icon: Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Phone Number
              _buildFieldLabel(_isSignUp ? 'Phone Number' : 'Phone Number or Email'),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.text,
                style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                decoration: _buildInputDecoration(
                  hint: _isSignUp ? '0801 234 5678' : '08012345678 or user@email.com',
                  icon: Icons.phone_iphone_rounded,
                  prefixWidget: _isSignUp
                      ? Container(
                          padding: const EdgeInsets.only(left: 12, right: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text('🇳🇬', style: TextStyle(fontSize: 16)),
                              SizedBox(width: 4),
                              Text(
                                '+234',
                                style: TextStyle(
                                  color: AppConstants.textLight,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(width: 8),
                              VerticalDivider(
                                color: AppConstants.surfaceBg,
                                width: 1,
                                thickness: 1,
                                indent: 10,
                                endIndent: 10,
                              ),
                            ],
                          ),
                        )
                      : null,
                ),
              ),

              const SizedBox(height: 16),

              // Sign Up: Email
              if (_isSignUp) ...[
                _buildFieldLabel('Email Address (for e-Receipts)'),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                  decoration: _buildInputDecoration(
                    hint: 'name@example.ng',
                    icon: Icons.alternate_email_rounded,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Password
              _buildFieldLabel('Passphrase'),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                style: const TextStyle(color: AppConstants.textLight, fontSize: 14),
                decoration: _buildInputDecoration(
                  hint: '••••••••••••',
                  icon: Icons.lock_outline_rounded,
                  suffixWidget: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppConstants.textMuted,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),

              // Sign Up: Promo Code
              if (_isSignUp) ...[
                const SizedBox(height: 16),
                _buildFieldLabel('Promo Voucher (Optional)'),
                TextField(
                  controller: _promoCodeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: AppConstants.primaryLight, fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: _buildInputDecoration(
                    hint: 'e.g. GIGAWELCOME',
                    icon: Icons.confirmation_number_outlined,
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shadowColor: AppConstants.primaryColor.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _isSignUp ? 'Create My Account' : 'Sign In to Giga Ride',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // Trust Signals Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppConstants.cardBg.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppConstants.surfaceBg),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: AppConstants.primaryLight,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '256-bit bank-grade encryption. Your personal data and NUBAN deposits are 100% safeguarded.',
                        style: TextStyle(
                          color: AppConstants.textMuted.withOpacity(0.85),
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          color: AppConstants.textLight,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
    Widget? prefixWidget,
    Widget? suffixWidget,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 13),
      filled: true,
      fillColor: AppConstants.cardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      prefixIcon: prefixWidget ??
          Icon(
            icon,
            color: AppConstants.primaryLight,
            size: 20,
          ),
      suffixIcon: suffixWidget,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppConstants.surfaceBg),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppConstants.surfaceBg),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppConstants.primaryLight, width: 1.5),
      ),
    );
  }
}

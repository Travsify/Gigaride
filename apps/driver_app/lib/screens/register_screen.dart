import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/driver_provider.dart';
import 'radar_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _vehicleMakeCtrl = TextEditingController(text: 'Toyota');
  final _vehicleModelCtrl = TextEditingController(text: 'Corolla');
  final _yearCtrl = TextEditingController(text: '2016');
  final _plateCtrl = TextEditingController();
  final _colorCtrl = TextEditingController(text: 'Silver');
  final _ninCtrl = TextEditingController();

  void _submit() async {
    if (_fullNameCtrl.text.isEmpty ||
        _phoneCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty ||
        _passwordCtrl.text.isEmpty ||
        _plateCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: AppConstants.dangerColor,
        ),
      );
      return;
    }

    final provider = context.read<DriverProvider>();
    try {
      await provider.register({
        'fullName': _fullNameCtrl.text.trim(),
        'phoneNumber': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text,
        'vehicleMake': _vehicleMakeCtrl.text.trim(),
        'vehicleModel': _vehicleModelCtrl.text.trim(),
        'vehicleYear': int.tryParse(_yearCtrl.text.trim()) ?? 2016,
        'licensePlate': _plateCtrl.text.trim().toUpperCase(),
        'vehicleColor': _colorCtrl.text.trim(),
        'nin': _ninCtrl.text.trim(),
      });
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RadarScreen()),
          (r) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppConstants.dangerColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<DriverProvider>().isLoading;

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Driver Onboarding', style: TextStyle(color: AppConstants.textLight)),
        iconTheme: const IconThemeData(color: AppConstants.textLight),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppConstants.accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppConstants.accentColor.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.stars, color: AppConstants.accentColor, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Bonus: Register today and get 5 Free Welcome Rides immediately!',
                        style: TextStyle(color: AppConstants.accentColor, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildField(_fullNameCtrl, 'Full Name (As on Bank Account)', Icons.person),
              _buildField(_phoneCtrl, 'Phone Number (e.g. 08012345678)', Icons.phone),
              _buildField(_emailCtrl, 'Email Address', Icons.email),
              _buildField(_passwordCtrl, 'Password (min 6 chars)', Icons.lock, obscure: true),
              const SizedBox(height: 12),
              const Text('Vehicle Information', style: TextStyle(color: AppConstants.textLight, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildField(_vehicleMakeCtrl, 'Make', Icons.directions_car)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildField(_vehicleModelCtrl, 'Model', Icons.model_training)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildField(_yearCtrl, 'Year', Icons.calendar_today)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildField(_colorCtrl, 'Color', Icons.palette)),
                ],
              ),
              _buildField(_plateCtrl, 'License Plate (e.g. LAG-420-AA)', Icons.credit_card),
              _buildField(_ninCtrl, 'NIN / National ID (Verification)', Icons.badge),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Complete Registration & Start', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon, {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        style: const TextStyle(color: AppConstants.textLight),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppConstants.textMuted, fontSize: 13),
          prefixIcon: Icon(icon, color: AppConstants.textMuted, size: 20),
          filled: true,
          fillColor: AppConstants.cardBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'phone_auth_screen.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PhoneAuthScreen(initialIsSignUp: true);
  }
}

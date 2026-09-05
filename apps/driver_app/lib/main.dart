import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants.dart';
import 'providers/driver_provider.dart';
import 'screens/login_screen.dart';
import 'screens/radar_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GigaDriverApp());
}

class GigaDriverApp extends StatelessWidget {
  const GigaDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DriverProvider()),
      ],
      child: MaterialApp(
        title: 'Giga Driver',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: AppConstants.primaryColor,
          scaffoldBackgroundColor: AppConstants.darkBg,
          fontFamily: 'Roboto',
        ),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAuth());
  }

  void _checkAuth() async {
    final provider = context.read<DriverProvider>();
    final authed = await provider.checkAuth();
    if (mounted) {
      setState(() {
        _isAuthenticated = authed;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppConstants.darkBg,
        body: Center(child: CircularProgressIndicator(color: AppConstants.primaryColor)),
      );
    }
    return _isAuthenticated ? const RadarScreen() : const LoginScreen();
  }
}

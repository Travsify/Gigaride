import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants.dart';
import 'providers/passenger_provider.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GigaPassengerApp());
}

class GigaPassengerApp extends StatelessWidget {
  const GigaPassengerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PassengerProvider()),
      ],
      child: MaterialApp(
        title: 'Giga Ride',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: AppConstants.primaryColor,
          scaffoldBackgroundColor: AppConstants.darkBg,
          fontFamily: 'Roboto',
          colorScheme: const ColorScheme.dark(
            primary: AppConstants.primaryColor,
            secondary: AppConstants.accentColor,
            surface: AppConstants.cardBg,
            background: AppConstants.darkBg,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: AppConstants.cardBg,
            elevation: 0,
            centerTitle: false,
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

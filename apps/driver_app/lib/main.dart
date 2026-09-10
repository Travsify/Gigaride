import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants.dart';
import 'providers/driver_provider.dart';
import 'screens/splash_screen.dart';

import 'package:onesignal_flutter/onesignal_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize OneSignal Push Notification Engine safely
  try {
    OneSignal.Debug.setLogLevel(OSLogLevel.none);
    OneSignal.initialize(AppConstants.oneSignalAppId);
    OneSignal.Notifications.requestPermission(true);

    // Handle notification tap → navigate to RadarScreen
    OneSignal.Notifications.addClickListener((event) {
      // App is already initialized, navigation happens through the app's state
      debugPrint('[Push] Notification tapped: ${event.notification.title}');
    });

    // Handle foreground notifications
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      event.preventDefault();
      event.notification.display();
    });
  } catch (e) {
    debugPrint('[Push Notification] OneSignal init deferred: $e');
  }

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
        title: 'Giga Driver Partner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: AppConstants.primaryColor,
          scaffoldBackgroundColor: AppConstants.darkBg,
          fontFamily: 'Roboto',
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

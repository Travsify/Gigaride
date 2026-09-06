import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static const String keyBiometricEnabled = 'giga_biometric_enabled';
  static const String keyBiometricUserToken = 'giga_biometric_token';
  static const String keyBiometricUserData = 'giga_biometric_user';
  static const String keyBiometricIdentifier = 'giga_biometric_identifier';
  static const String keyBiometricPassword = 'giga_biometric_password';

  /// Check if the physical device has biometric sensors and if biometrics are enrolled
  static Future<bool> isBiometricAvailable() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isSupported = await _auth.isDeviceSupported();
      if (!canCheck && !isSupported) return false;

      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty || canCheck;
    } catch (_) {
      return false;
    }
  }

  /// Check if the user has opted in to biometric login on this device
  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyBiometricEnabled) ?? false;
  }

  /// Perform biometric authentication prompt (Fingerprint / Face ID)
  static Future<bool> authenticate({
    String reason = 'Scan fingerprint or face to log in to Giga Ride',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  /// Save credentials after sign up or successful login to enable fast biometric login next time
  static Future<void> enableBiometrics({
    required String token,
    required String userJson,
    String? identifier,
    String? password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyBiometricEnabled, true);
    await prefs.setString(keyBiometricUserToken, token);
    await prefs.setString(keyBiometricUserData, userJson);
    if (identifier != null && identifier.isNotEmpty) {
      await prefs.setString(keyBiometricIdentifier, identifier);
    }
    if (password != null && password.isNotEmpty) {
      await prefs.setString(keyBiometricPassword, password);
    }
  }

  /// Clear stored biometric credentials on logout or user preference toggle
  static Future<void> disableBiometrics() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyBiometricEnabled, false);
    await prefs.remove(keyBiometricUserToken);
    await prefs.remove(keyBiometricUserData);
    await prefs.remove(keyBiometricIdentifier);
    await prefs.remove(keyBiometricPassword);
  }

  /// Retrieve saved biometric login credentials
  static Future<Map<String, String?>?> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool(keyBiometricEnabled) ?? false;
    if (!isEnabled) return null;

    final token = prefs.getString(keyBiometricUserToken);
    final user = prefs.getString(keyBiometricUserData);
    final identifier = prefs.getString(keyBiometricIdentifier);
    final password = prefs.getString(keyBiometricPassword);

    if (token == null && (identifier == null || password == null)) {
      return null;
    }

    return {
      'token': token,
      'user': user,
      'identifier': identifier,
      'password': password,
    };
  }
}

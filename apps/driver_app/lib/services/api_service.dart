import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class ApiService {
  String baseUrl = AppConstants.defaultApiUrl;

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
  }

  // --- Resilient HTTP Execution with Timeout & Clean Error Mapping ---
  Future<http.Response> _safePost(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        return await http.post(uri, headers: headers, body: body).timeout(timeout);
      } on SocketException catch (_) {
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 600));
          continue;
        }
        throw Exception('Network connection timed out. Please check your internet connection and try again.');
      } on http.ClientException catch (_) {
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 600));
          continue;
        }
        throw Exception('Unable to reach Giga Ride servers. Please check your internet connection.');
      } on TimeoutException catch (_) {
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 600));
          continue;
        }
        throw Exception('Connection timed out. The server took too long to respond. Please try again.');
      } catch (e) {
        final str = e.toString();
        if (str.contains('SocketException') || str.contains('timed out') || str.contains('ClientException')) {
          throw Exception('Network connection timed out. Please check your internet connection and try again.');
        }
        rethrow;
      }
    }
    throw Exception('Network connection timed out. Please try again.');
  }

  Future<http.Response> _safeGet(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        return await http.get(uri, headers: headers).timeout(timeout);
      } on SocketException catch (_) {
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 600));
          continue;
        }
        throw Exception('Network connection timed out. Please check your internet connection and try again.');
      } on http.ClientException catch (_) {
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 600));
          continue;
        }
        throw Exception('Unable to reach Giga Ride servers. Please check your internet connection.');
      } on TimeoutException catch (_) {
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 600));
          continue;
        }
        throw Exception('Connection timed out. The server took too long to respond. Please try again.');
      } catch (e) {
        final str = e.toString();
        if (str.contains('SocketException') || str.contains('timed out') || str.contains('ClientException')) {
          throw Exception('Network connection timed out. Please check your internet connection and try again.');
        }
        rethrow;
      }
    }
    throw Exception('Network connection timed out. Please try again.');
  }

  Future<http.Response> _safePatch(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        return await http.patch(uri, headers: headers, body: body).timeout(timeout);
      } on SocketException catch (_) {
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 600));
          continue;
        }
        throw Exception('Network connection timed out. Please check your internet connection and try again.');
      } on http.ClientException catch (_) {
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 600));
          continue;
        }
        throw Exception('Unable to reach Giga Ride servers. Please check your internet connection.');
      } on TimeoutException catch (_) {
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 600));
          continue;
        }
        throw Exception('Connection timed out. The server took too long to respond. Please try again.');
      } catch (e) {
        final str = e.toString();
        if (str.contains('SocketException') || str.contains('timed out') || str.contains('ClientException')) {
          throw Exception('Network connection timed out. Please check your internet connection and try again.');
        }
        rethrow;
      }
    }
    throw Exception('Network connection timed out. Please try again.');
  }


  // --- Authentication Suite ---
  Future<Map<String, dynamic>> sendPhoneOtp(String phoneNumber, {bool isSignUp = false, bool isLogin = false}) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/auth/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phoneNumber': phoneNumber, if (isSignUp) 'isSignUp': true, if (isLogin) 'isLogin': true}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to dispatch verification SMS');
  }

  Future<Map<String, dynamic>> checkAvailability({String? phoneNumber, String? email}) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/auth/check-availability'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phoneNumber': ?phoneNumber, 'email': ?email}),
    );
    final data = jsonDecode(response.body);
    // 200 = available, 409 = taken
    return data;
  }

  Future<Map<String, dynamic>> sendEmailLoginOtp(String email) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/auth/send-email-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'isLogin': true}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to dispatch email verification code');
  }

  Future<Map<String, dynamic>> loginWithEmailOtp(String email, String otpCode) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/auth/login-email-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otpCode': otpCode}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final Map<String, dynamic> payload = (data['data'] is Map<String, dynamic>)
          ? (data['data'] as Map<String, dynamic>)
          : (data as Map<String, dynamic>);
      if (payload['token'] != null) {
        await saveToken(payload['token']);
      }
      return payload;
    }
    throw Exception(data['message'] ?? 'Invalid or expired email verification code');
  }


  Future<Map<String, dynamic>> forgotPassword(String identifier) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to send password reset code');
  }

  Future<Map<String, dynamic>> resetPassword(String phoneNumber, String otpCode, String newPassword) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phoneNumber': phoneNumber, 'otpCode': otpCode, 'newPassword': newPassword}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to reset password');
  }

  Future<Map<String, dynamic>> sendEmailOtp(String email) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/auth/send-email-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to dispatch email verification code');
  }

  Future<Map<String, dynamic>> verifyEmailOtp(String email, String otpCode) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/auth/verify-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otpCode': otpCode}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw Exception(data['message'] ?? 'Invalid or expired email verification code');
  }

  Future<Map<String, dynamic>> verifyPhoneOtp(String phoneNumber, String otpCode) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phoneNumber': phoneNumber, 'otpCode': otpCode}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      if (data['token'] != null) {
        await saveToken(data['token']);
      }
      return data;
    }
    throw Exception(data['message'] ?? 'Invalid or expired OTP code');
  }

  Future<Map<String, dynamic>> registerDriver({
    required String fullName,
    required String phoneNumber,
    required String email,
    required String password,
    required String vehicleMake,
    required String vehicleModel,
    required int vehicleYear,
    required String licensePlate,
    required String vehicleColor,
    String? nin,
  }) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'role': 'DRIVER',
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'email': email,
        'password': password,
        'vehicleMake': vehicleMake,
        'vehicleModel': vehicleModel,
        'vehicleYear': vehicleYear,
        'licensePlate': licensePlate,
        'vehicleColor': vehicleColor,
        'nin': nin,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201 && data['success'] == true) {
      await saveToken(data['data']['token']);
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Registration failed');
  }

  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final response = await _safePost(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier, 'password': password}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final Map<String, dynamic> payload = (data['data'] is Map<String, dynamic>)
          ? (data['data'] as Map<String, dynamic>)
          : (data as Map<String, dynamic>);
      if (payload['token'] != null) {
        await saveToken(payload['token']);
      }
      return payload;
    }
    if (data['requiresPhoneVerification'] == true) {
      final p = data['phoneNumber'] ?? identifier;
      throw Exception('PHONE_UNVERIFIED:$p');
    }
    throw Exception(data['message'] ?? 'Login failed');
  }

  Future<Map<String, dynamic>> getMe() async {
    final token = await getToken();
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Failed to load profile');
  }

  Future<Map<String, dynamic>?> getActiveRideState() async {
    final token = await getToken();
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/rides/active-state'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    return null;
  }

  /// Fetches complete ride and earnings history for the driver
  Future<List<dynamic>> getDriverRideHistory() async {
    final token = await getToken();
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/rides/history/driver'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'] ?? [];
    }
    return [];
  }


  // --- KYC & RegTech Identitypass Suite ---
  Future<Map<String, dynamic>> verifyNIN(String nin, String firstName, String lastName, {String? dob}) async {
    final token = await getToken();
    final response = await _safePost(
      Uri.parse('$baseUrl/api/kyc/verify-nin'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'nin': nin,
        'firstName': firstName,
        'lastName': lastName,
        'dob': dob,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'NIN verification failed');
  }

  Future<Map<String, dynamic>> verifyDriversLicense(String licenseNumber, String firstName, String lastName, {String? dob}) async {
    final token = await getToken();
    final response = await _safePost(
      Uri.parse('$baseUrl/api/kyc/verify-license'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'licenseNumber': licenseNumber,
        'firstName': firstName,
        'lastName': lastName,
        'dob': dob,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'License verification failed');
  }

  // --- Dedicated Virtual Account & Wallet Suite ---
  Future<Map<String, dynamic>> getDedicatedVirtualAccount() async {
    final token = await getToken();
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/payments/virtual-account'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Failed to load dedicated virtual account');
  }

  // --- Subscriptions Suite ---
  Future<List<dynamic>> getSubscriptionPlans() async {
    final response = await _safeGet(Uri.parse('$baseUrl/api/subscriptions/plans'));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception('Failed to load subscription plans');
  }

  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    final token = await getToken();
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/subscriptions/status'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Failed to get subscription status');
  }

  Future<Map<String, dynamic>> purchaseSubscription(String planId) async {
    final token = await getToken();
    final response = await _safePost(
      Uri.parse('$baseUrl/api/subscriptions/purchase'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'planId': planId}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Purchase failed');
  }

  Future<Map<String, dynamic>> initializeCardPayment(String planId) async {
    final token = await getToken();
    final response = await _safePost(
      Uri.parse('$baseUrl/api/payments/initialize'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'planId': planId}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Payment initialization failed');
  }

  Future<List<dynamic>> getSavedCards() async {
    final token = await getToken();
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/payments/cards'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'] as List<dynamic>;
    }
    return [];
  }

  Future<List<dynamic>> getCardTransactions() async {
    final token = await getToken();
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/payments/cards/transactions'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'] as List<dynamic>;
    }
    return [];
  }

  Future<List<dynamic>> getStatement() async {
    final token = await getToken();
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/payments/wallet/statement'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'] as List<dynamic>;
    }
    return [];
  }

  Future<Map<String, dynamic>> chargeSavedCard({
    required String cardId,
    required int amountNgn,
    required String planId,
  }) async {
    final token = await getToken();
    final response = await _safePost(
      Uri.parse('$baseUrl/api/payments/cards/charge-saved'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'cardId': cardId,
        'amountNgn': amountNgn,
        'purpose': 'SUBSCRIPTION_PURCHASE',
        'planId': planId,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to charge card');
  }

  Future<Map<String, dynamic>> verifyCardTransaction(String reference) async {
    final token = await getToken();
    final response = await _safePost(
      Uri.parse('$baseUrl/api/payments/cards/verify'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'reference': reference}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to verify transaction');
  }

  // --- In-App Notifications Suite ---
  Future<Map<String, dynamic>> getNotifications() async {
    final token = await getToken();
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/notifications'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Failed to fetch notifications');
  }

  Future<void> markNotificationRead(String id) async {
    final token = await getToken();
    await _safePatch(
      Uri.parse('$baseUrl/api/notifications/$id/read'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<void> markAllNotificationsRead() async {
    final token = await getToken();
    await _safePatch(
      Uri.parse('$baseUrl/api/notifications/read-all'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<Map<String, dynamic>> withdrawToBank({
    required int amountNgn,
    required String bankName,
    required String accountNumber,
    required String accountName,
    String bankCode = '000',
  }) async {
    final token = await getToken();
    final response = await _safePost(
      Uri.parse('$baseUrl/api/payments/wallet/withdraw'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'amountNgn': amountNgn,
        'bankName': bankName,
        'accountNumber': accountNumber,
        'accountName': accountName,
        'bankCode': bankCode,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'] ?? data;
    }
    throw Exception(data['message'] ?? 'Failed to execute bank withdrawal');
  }

  Future<Map<String, dynamic>> getCryptoRate() async {
    final response = await _safeGet(Uri.parse('$baseUrl/api/payments/crypto/rate'));
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    return {'rateNgn': 1550, 'supportedNetworks': ['TRC20', 'BEP20', 'POLYGON', 'ERC20']};
  }

  Future<Map<String, dynamic>> withdrawCryptoUsdt({
    required int amountNgn,
    required String targetAddress,
    String network = 'TRC20',
  }) async {
    final token = await getToken();
    final response = await _safePost(
      Uri.parse('$baseUrl/api/payments/crypto/usdt/withdraw'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'amountNgn': amountNgn,
        'targetAddress': targetAddress,
        'network': network,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'] ?? data;
    }
    throw Exception(data['message'] ?? 'Failed to execute USDT crypto withdrawal');
  }

  Future<List<dynamic>> fetchAvailableBroadcastedRides() async {
    final token = await getToken();
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/rides/feed/available'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'] as List<dynamic>;
    }
    return [];
  }

  Future<Map<String, dynamic>> updateRideStatus(String rideId, String status) async {
    final token = await getToken();
    final response = await _safePatch(
      Uri.parse('$baseUrl/api/rides/$rideId/status'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'status': status}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'] ?? data;
    }
    throw Exception(data['message'] ?? 'Failed to update ride status');
  }

  Future<List<Map<String, dynamic>>> getChatMessages(String rideId) async {
    final token = await getToken();
    final response = await _safeGet(
      Uri.parse('$baseUrl/api/rides/$rideId/messages'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final list = data['data'] as List<dynamic>? ?? [];
      return list.map((item) => Map<String, dynamic>.from(item)).toList();
    }
    return [];
  }

  Future<void> deleteAccount() async {
    final token = await getToken();
    await _safePost(
      Uri.parse('$baseUrl/api/auth/delete-account'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
  }
}

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
  }

  Future<Map<String, dynamic>> sendPhoneOtp(String phoneNumber) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/send-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phoneNumber': phoneNumber}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to dispatch verification code');
  }

  Future<Map<String, dynamic>> forgotPassword(String identifier) async {
    final response = await http.post(
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
    final response = await http.post(
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
    final response = await http.post(
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
    final response = await http.post(
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
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phoneNumber': phoneNumber, 'otpCode': otpCode}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && (data['success'] == true || data['token'] != null)) {
      if (data['token'] != null) {
        await saveToken(data['token']);
      }
      return data;
    }
    throw Exception(data['message'] ?? 'Invalid or expired verification code');
  }

  Future<Map<String, dynamic>> registerPassenger({
    required String fullName,
    required String phoneNumber,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'role': 'PASSENGER',
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'email': email,
        'password': password,
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
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier, 'password': password}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      await saveToken(data['data']['token']);
      return data['data'];
    }
    if (data['requiresPhoneVerification'] == true) {
      final p = data['phoneNumber'] ?? identifier;
      throw Exception('PHONE_UNVERIFIED:$p');
    }
    throw Exception(data['message'] ?? 'Login failed');
  }

  Future<Map<String, dynamic>> getMe() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/api/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Failed to load profile');
  }

  Future<Map<String, dynamic>> getEstimate({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/rides/estimate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'dropoffLat': dropoffLat,
        'dropoffLng': dropoffLng,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Failed to get fare estimate');
  }

  Future<Map<String, dynamic>> createRideRequest({
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffAddress,
    required int riderOfferNgn,
    String? notes,
    bool isBusiness = false,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/api/rides/request'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'pickupAddress': pickupAddress,
        'dropoffLat': dropoffLat,
        'dropoffLng': dropoffLng,
        'dropoffAddress': dropoffAddress,
        'riderOfferNgn': riderOfferNgn,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (isBusiness) 'isBusiness': true,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 201 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Failed to create ride request');
  }

  // --- Living Wallet API Suite ---
  Future<Map<String, dynamic>> getLivingWallet() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/api/payments/wallet'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Failed to load living wallet');
  }

  Future<Map<String, dynamic>> addMoney(int amountNgn, {String method = 'BANK_TRANSFER'}) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/api/payments/wallet/add-money'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'amountNgn': amountNgn, 'method': method}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Failed to fund wallet');
  }

  Future<Map<String, dynamic>> swapWalletVault(String direction, int amountNgn) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/api/payments/wallet/swap'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'direction': direction, 'amountNgn': amountNgn}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to swap funds');
  }

  Future<Map<String, dynamic>> withdrawFromWallet({
    required int amountNgn,
    required String bankName,
    required String accountNumber,
    required String accountName,
    String bankCode = '000',
  }) async {
    final token = await getToken();
    final response = await http.post(
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
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to withdraw funds');
  }

  Future<List<dynamic>> getBeneficiaries({String? search, int days = 90}) async {
    final token = await getToken();
    String url = '$baseUrl/api/payments/wallet/beneficiaries?days=$days';
    if (search != null && search.isNotEmpty) {
      url += '&search=${Uri.encodeComponent(search)}';
    }
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'] as List<dynamic>;
    }
    return [];
  }

  Future<List<dynamic>> getSavedCards() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/api/payments/cards'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'] as List<dynamic>;
    }
    return [];
  }

  Future<bool> deleteSavedCard(String cardId) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/api/payments/cards/$cardId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    return data['success'] == true;
  }

  Future<List<dynamic>> getCardTransactions() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/api/payments/cards/transactions'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'] as List<dynamic>;
    }
    return [];
  }

  Future<Map<String, dynamic>> initializeCardFunding(int amountNgn) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/api/payments/cards/initialize-funding'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'amountNgn': amountNgn}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Failed to initialize card funding');
  }

  Future<Map<String, dynamic>> chargeSavedCard({
    required String cardId,
    required int amountNgn,
    String purpose = 'WALLET_FUNDING',
    String? planId,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/api/payments/cards/charge-saved'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'cardId': cardId,
        'amountNgn': amountNgn,
        'purpose': purpose,
        if (planId != null) ...{'planId': planId},
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to charge saved card');
  }

  Future<Map<String, dynamic>> verifyCardTransaction(String reference) async {
    final token = await getToken();
    final response = await http.post(
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

  Future<Map<String, dynamic>> transferP2P({
    required String recipientSearch,
    required int amountNgn,
    bool saveAsBeneficiary = true,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/api/payments/wallet/transfer-p2p'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'recipientSearch': recipientSearch,
        'amountNgn': amountNgn,
        'saveAsBeneficiary': saveAsBeneficiary,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw Exception(data['message'] ?? 'P2P transfer failed');
  }

  Future<List<dynamic>> getStatement() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/api/payments/wallet/statement'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'] as List<dynamic>;
    }
    return [];
  }

  // Pay for completed ride using Giga Living Wallet
  Future<Map<String, dynamic>> payRideWithWallet(String rideId) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/api/rides/$rideId/pay-wallet'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw Exception(data['message'] ?? 'Wallet payment failed');
  }

  // Pre-schedule Advance Airport or Interstate Ride
  Future<Map<String, dynamic>> scheduleRide({
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    required String dropoffAddress,
    required String scheduledFor,
    required int riderOfferNgn,
    String? flightNumber,
    bool isAirport = false,
    bool isInterstate = false,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/api/rides/schedule'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'pickupAddress': pickupAddress,
        'dropoffLat': dropoffLat,
        'dropoffLng': dropoffLng,
        'dropoffAddress': dropoffAddress,
        'scheduledFor': scheduledFor,
        'riderOfferNgn': riderOfferNgn,
        'flightNumber': flightNumber,
        'isAirport': isAirport,
        'isInterstate': isInterstate,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201 && data['success'] == true) {
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Failed to schedule ride');
  }

  // Fetch Passenger Ride History
  Future<List<dynamic>> getRiderHistory() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/api/rides/history/passenger'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['data'] as List<dynamic>;
    }
    return [];
  }
}
